<?php

namespace App\Services;

use App\Models\Conversation;
use App\Models\Department;
use App\Models\Message;
use App\Models\User;
use Illuminate\Auth\Access\AuthorizationException;
use Illuminate\Database\Eloquent\Builder;
use Illuminate\Database\Eloquent\Collection;
use Illuminate\Support\Facades\DB;

/**
 * Messagerie entre membres.
 *  - Chaque membre fait automatiquement partie du groupe de son département.
 *  - Il peut écrire en privé à n'importe quel membre actif (conversation « directe »).
 *  - Le président et le vice-président (administrateurs) font partie de TOUS les groupes de département.
 *  - « Non lu » = messages des autres postés après sa dernière lecture (last_read_at).
 */
class ChatService
{
    /** Ajoute le membre au groupe de son département (créé au besoin). */
    public function ensureDepartmentGroup(User $user): Conversation
    {
        $group = Conversation::firstOrCreate(
            ['type' => Conversation::DEPARTMENT, 'department_id' => $user->department_id],
        );
        $group->participants()->syncWithoutDetaching([$user->id]);

        return $group;
    }

    /** Administrateurs : membres de tous les groupes de département. */
    private function joinAllDepartmentGroups(User $user): void
    {
        foreach (Department::pluck('id') as $departmentId) {
            Conversation::firstOrCreate(['type' => Conversation::DEPARTMENT, 'department_id' => $departmentId])
                ->participants()->syncWithoutDetaching([$user->id]);
        }
    }

    /** Conversations du membre, la plus récente en premier, avec le nombre de messages non lus. */
    public function listFor(User $user): Collection
    {
        $this->ensureDepartmentGroup($user);
        if ($user->isPresidency()) {
            $this->joinAllDepartmentGroups($user);
        }

        return $this->visibleConversations($user)
            ->with(['department', 'lastMessage.user', 'participants.department'])
            ->withCount(['messages as unread_count' => fn (Builder $q) => $this->unreadConstraint($q, $user)])
            ->orderByRaw('COALESCE(conversations.last_message_at, conversations.created_at) DESC')
            ->get();
    }

    /** Total des messages non lus (badge de l'onglet Messages). */
    public function unreadTotal(User $user): int
    {
        return (int) $this->visibleConversations($user)
            ->withCount(['messages as unread_count' => fn (Builder $q) => $this->unreadConstraint($q, $user)])
            ->get()
            ->sum('unread_count');
    }

    /** Retrouve (ou crée) la conversation privée entre deux membres. */
    public function direct(User $me, User $other): Conversation
    {
        if ($me->id === $other->id || ! $other->isActive()) {
            throw new AuthorizationException('Impossible d\'écrire à ce membre.');
        }

        $existing = Conversation::where('type', Conversation::DIRECT)
            ->whereHas('participants', fn ($q) => $q->where('users.id', $me->id))
            ->whereHas('participants', fn ($q) => $q->where('users.id', $other->id))
            ->first();

        return $existing ?? DB::transaction(function () use ($me, $other) {
            $conversation = Conversation::create(['type' => Conversation::DIRECT]);
            $conversation->participants()->attach([$me->id, $other->id]);

            return $conversation;
        });
    }

    /**
     * Messages d'une conversation (50 au plus), du plus ancien au plus récent.
     *  - $afterId  : seulement les nouveaux (rafraîchissement automatique) ;
     *  - $beforeId : les plus anciens (remonter l'historique).
     * Consulter les derniers messages les marque comme lus.
     */
    public function messages(User $user, Conversation $conversation, ?int $afterId, ?int $beforeId): Collection
    {
        $this->authorize($user, $conversation);

        $query = $conversation->messages()->with('user.department');
        if ($afterId) {
            $messages = $query->where('id', '>', $afterId)->orderBy('id')->limit(100)->get();
        } else {
            $messages = $query->when($beforeId, fn ($q) => $q->where('id', '<', $beforeId))
                ->orderByDesc('id')->limit(50)->get()->reverse()->values();
        }

        if (! $beforeId) {
            $this->markRead($user, $conversation);
        }

        return $messages;
    }

    /** Envoie un message et prévient les autres participants. */
    public function send(User $user, Conversation $conversation, string $body): Message
    {
        $this->authorize($user, $conversation);

        $message = DB::transaction(function () use ($user, $conversation, $body) {
            $message = $conversation->messages()->create(['user_id' => $user->id, 'body' => $body]);
            $conversation->forceFill(['last_message_at' => $message->created_at])->save();

            return $message;
        });
        $this->markRead($user, $conversation);

        dispatch(fn () => app(NotificationService::class)->chatMessage($conversation, $message))->afterResponse();

        return $message->load('user.department');
    }

    public function markRead(User $user, Conversation $conversation): void
    {
        $conversation->participants()->updateExistingPivot($user->id, ['last_read_at' => now()]);
    }

    /** Seuls les participants accèdent à une conversation. */
    public function authorize(User $user, Conversation $conversation): void
    {
        $isParticipant = $conversation->participants()->where('users.id', $user->id)->exists();
        // Un membre qui a changé de département ne voit plus l'ancien groupe (sauf administrateurs).
        $stillInDepartment = ! $conversation->isDepartment()
            || $user->isPresidency()
            || $conversation->department_id === $user->department_id;

        if (! $isParticipant || ! $stillInDepartment) {
            throw new AuthorizationException('Vous ne participez pas à cette conversation.');
        }
    }

    /** Conversations privées + groupe de SON département actuel. */
    private function visibleConversations(User $user)
    {
        if ($user->isPresidency()) {
            return $user->conversations();
        }

        return $user->conversations()->where(fn ($q) => $q->where('conversations.type', Conversation::DIRECT)
            ->orWhere('conversations.department_id', $user->department_id));
    }

    /** Condition SQL « message non lu par $user » (utilisée dans un withCount). */
    private function unreadConstraint(Builder $query, User $user): void
    {
        $query->where('messages.user_id', '!=', $user->id)
            ->where(fn (Builder $w) => $w->whereNull('conversation_participants.last_read_at')
                ->orWhereColumn('messages.created_at', '>', 'conversation_participants.last_read_at'));
    }
}
