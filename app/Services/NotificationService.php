<?php

namespace App\Services;

use App\Enums\Position;
use App\Enums\UserStatus;
use App\Models\Conversation;
use App\Models\Message;
use App\Models\Task;
use App\Models\User;

/**
 * Point unique pour prévenir les membres (notifications push + e-mails).
 * Chaque notification porte un « type » que l'application utilise pour
 * ouvrir le bon écran quand on la touche :
 *   task_created      -> détail de la tâche (task_id)
 *   approval_request  -> page des demandes d'inscription
 *   chat_message      -> conversation (conversation_id)
 *   sync              -> pas de bannière : l'application rafraîchit en silence
 *                        l'écran concerné (scope : tasks, comments, approvals, chat).
 *                        C'est le mécanisme « temps réel » de l'application.
 *
 * Les méthodes sont appelées APRÈS la réponse HTTP (dispatch afterResponse)
 * pour ne pas ralentir l'utilisateur.
 */
class NotificationService
{
    public function __construct(
        private readonly FirebaseMessagingService $push,
        private readonly MailService $mail,
    ) {}

    /** Nouvelle tâche : seulement les destinataires (membres du département visé). */
    public function taskCreated(Task $task): void
    {
        $task->loadMissing(['creator', 'recipients.user']);

        $this->push->sendToUsers(
            $task->recipients->pluck('user'),
            'Nouvelle tâche ('.$task->urgency->label().')',
            $task->creator->fullName().' : '.$task->title,
            ['type' => 'task_created', 'task_id' => (string) $task->id, 'urgency' => $task->urgency->value],
        );
    }

    /**
     * Nouvelle demande d'inscription (e-mail confirmé) : on prévient ceux qui peuvent la valider
     * — président, vice-président et, pour un membre, le responsable de son département.
     */
    public function approvalRequested(User $candidate): void
    {
        $approvers = User::where('status', UserStatus::Active->value)
            ->where(fn ($q) => $q->whereIn('position', [Position::President->value, Position::VicePresident->value])
                ->orWhere(fn ($r) => $r->where('position', Position::Responsable->value)
                    ->where('department_id', $candidate->department_id)))
            ->get()
            ->filter(fn (User $approver) => $approver->canApprove($candidate));

        $candidate->loadMissing('department');
        $this->push->sendToUsers(
            $approvers,
            'Nouvelle demande d\'inscription',
            $candidate->fullName().' · '.$candidate->position->label().' · '.$candidate->department->name,
            ['type' => 'approval_request', 'user_id' => (string) $candidate->id],
        );
    }

    /** Une tâche a changé (reçue, vue, effectuée, commentée) : l'auteur voit les coches bouger en direct. */
    public function taskUpdated(Task $task, int $actorId, string $scope = 'tasks'): void
    {
        $task->loadMissing(['creator', 'recipients.user']);
        $users = collect([$task->creator])
            ->merge($scope === 'comments' ? $task->recipients->pluck('user') : [])
            ->filter(fn ($u) => $u && $u->id !== $actorId)
            ->unique('id');

        $this->push->sync($users, $scope, ['task_id' => (string) $task->id]);
    }

    /** Demande validée ou refusée : les autres validateurs voient la liste se mettre à jour. */
    public function approvalDecided(User $candidate, int $deciderId): void
    {
        $others = User::where('status', UserStatus::Active->value)
            ->where('id', '!=', $deciderId)
            ->whereIn('position', [Position::President->value, Position::VicePresident->value, Position::Responsable->value])
            ->get();

        $this->push->sync($others, 'approvals', ['user_id' => (string) $candidate->id]);
    }

    /** Compte validé : e-mail au nouveau membre (il n'a pas encore l'application connectée). */
    public function accountApproved(User $user): void
    {
        $this->mail->sendView($user->email, $user->fullName(), 'C-Tech Tasks : votre compte est validé',
            'mail.account-approved', ['user' => $user]);
    }

    /** Nouveau message : tous les participants sauf l'auteur. */
    public function chatMessage(Conversation $conversation, Message $message): void
    {
        $message->loadMissing('user');
        $recipients = $conversation->participants()
            ->where('users.id', '!=', $message->user_id)
            ->get();

        $title = $conversation->isDepartment()
            ? $conversation->department->name
            : $message->user->fullName();
        $body = $conversation->isDepartment()
            ? $message->user->first_name.' : '.$message->body
            : $message->body;

        $this->push->sendToUsers($recipients, $title, $body, [
            'type' => 'chat_message',
            'conversation_id' => (string) $conversation->id,
        ]);
    }
}
