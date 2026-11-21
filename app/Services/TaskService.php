<?php

namespace App\Services;

use App\Enums\UserStatus;
use App\Jobs\SendTaskNotification;
use App\Models\Task;
use App\Models\TaskComment;
use App\Models\TaskRecipient;
use App\Models\User;
use Illuminate\Contracts\Pagination\LengthAwarePaginator;
use Illuminate\Support\Facades\DB;

/**
 * Logique métier des tâches : création, listes, accusés reçu / vu / effectué, commentaires.
 */
class TaskService
{
    /**
     * Crée une tâche pour un département : chaque membre actif du département
     * (sauf l'auteur) devient destinataire, puis reçoit une notification push.
     */
    public function create(User $author, array $data): Task
    {
        $task = DB::transaction(function () use ($author, $data) {
            $task = Task::create([
                'creator_id' => $author->id,
                'department_id' => $data['department_id'],
                'title' => $data['title'],
                'description' => $data['description'] ?? null,
                'urgency' => $data['urgency'],
                'due_at' => $data['due_at'] ?? null,
            ]);

            $recipientIds = User::where('department_id', $task->department_id)
                ->where('status', UserStatus::Active->value)
                ->where('id', '!=', $author->id)
                ->pluck('id');

            $now = now();
            TaskRecipient::insert($recipientIds->map(fn (int $id) => [
                'task_id' => $task->id,
                'user_id' => $id,
                'created_at' => $now,
                'updated_at' => $now,
            ])->all());

            return $task;
        });

        // Envoi après la réponse HTTP : l'auteur n'attend pas Firebase.
        SendTaskNotification::dispatchAfterResponse($task->id);

        return $this->load($task);
    }

    /**
     * Liste paginée.
     * $box : received (reçues) | sent (envoyées) | all (présidence : tout le club)
     * Les tâches reçues listées sont automatiquement marquées « reçues ».
     */
    public function list(User $user, string $box, array $filters): LengthAwarePaginator
    {
        $query = Task::query()->with(['creator.department', 'department', 'recipients.user'])
            ->withCount('comments');

        match ($box) {
            'sent' => $query->where('creator_id', $user->id),
            'all' => $query->visibleTo($user),
            default => $query->whereHas('recipients', fn ($q) => $q->where('user_id', $user->id)),
        };

        if (! empty($filters['urgency'])) {
            $query->where('urgency', $filters['urgency']);
        }
        if (($filters['state'] ?? null) === 'done') {
            $query->whereHas('recipients', fn ($q) => $q->where('user_id', $user->id)->whereNotNull('done_at'));
        } elseif (($filters['state'] ?? null) === 'todo') {
            $query->whereHas('recipients', fn ($q) => $q->where('user_id', $user->id)->whereNull('done_at'));
        }
        if (! empty($filters['search'])) {
            $term = '%'.mb_strtolower($filters['search']).'%';
            $query->where(fn ($q) => $q->whereRaw('LOWER(title) LIKE ?', [$term])
                ->orWhereRaw('LOWER(description) LIKE ?', [$term]));
        }

        $page = $query->latest()->paginate(min((int) ($filters['per_page'] ?? 20), 50));

        if ($box === 'received') {
            $this->markDelivered($user, collect($page->items())->pluck('id')->all());
        }

        return $page;
    }

    /** Accusé « reçu » (✓✓ gris) pour une liste de tâches. */
    public function markDelivered(User $user, array $taskIds): void
    {
        if ($taskIds === []) {
            return;
        }

        TaskRecipient::where('user_id', $user->id)
            ->whereIn('task_id', $taskIds)
            ->whereNull('delivered_at')
            ->update(['delivered_at' => now()]);
    }

    /** Ouverture du détail : accusé « vu » (✓✓ bleu) si l'utilisateur est destinataire. */
    public function show(User $user, Task $task): Task
    {
        $recipient = $task->recipientFor($user);
        if ($recipient && ! $recipient->seen_at) {
            $recipient->forceFill([
                'delivered_at' => $recipient->delivered_at ?? now(),
                'seen_at' => now(),
            ])->save();
        }

        return $this->load($task);
    }

    /** Le membre coche (ou décoche) « effectué » : la validation ne concerne que lui. */
    public function setDone(User $user, Task $task, bool $done): Task
    {
        $recipient = $task->recipientFor($user);
        abort_unless($recipient, 403, 'Cette tâche ne vous est pas adressée.');

        $recipient->forceFill([
            'delivered_at' => $recipient->delivered_at ?? now(),
            'seen_at' => $recipient->seen_at ?? now(),
            'done_at' => $done ? now() : null,
        ])->save();

        return $this->load($task);
    }

    public function addComment(User $user, Task $task, string $body): TaskComment
    {
        return $task->comments()->create(['user_id' => $user->id, 'body' => $body])->load('user.department');
    }

    private function load(Task $task): Task
    {
        return $task->fresh(['creator.department', 'department', 'recipients.user.department'])
            ->loadCount('comments');
    }
}
