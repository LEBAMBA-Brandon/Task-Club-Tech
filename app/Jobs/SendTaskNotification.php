<?php

namespace App\Jobs;

use App\Models\Task;
use App\Services\NotificationService;
use Illuminate\Bus\Queueable;
use Illuminate\Foundation\Bus\Dispatchable;

/**
 * Notifie uniquement les membres concernés (destinataires) d'une nouvelle tâche.
 */
class SendTaskNotification
{
    use Dispatchable, Queueable;

    public function __construct(public int $taskId) {}

    public function handle(NotificationService $notifications): void
    {
        $task = Task::find($this->taskId);
        if ($task) {
            $notifications->taskCreated($task);
        }
    }
}
