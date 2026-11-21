<?php

namespace App\Jobs;

use App\Models\Task;
use App\Services\FirebaseMessagingService;
use Illuminate\Bus\Queueable;
use Illuminate\Foundation\Bus\Dispatchable;

/**
 * Notifie uniquement les membres concernés (destinataires) d'une nouvelle tâche.
 */
class SendTaskNotification
{
    use Dispatchable, Queueable;

    public function __construct(public int $taskId) {}

    public function handle(FirebaseMessagingService $firebase): void
    {
        $task = Task::with(['creator', 'recipients.user'])->find($this->taskId);
        if (! $task) {
            return;
        }

        $title = 'Nouvelle tâche ('.$task->urgency->label().')';
        $body = $task->creator->fullName().' : '.$task->title;

        foreach ($task->recipients as $recipient) {
            $firebase->sendToUser($recipient->user, $title, $body, [
                'type' => 'task_created',
                'task_id' => (string) $task->id,
                'urgency' => $task->urgency->value,
            ]);
        }
    }
}
