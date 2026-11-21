<?php

namespace App\Policies;

use App\Models\Task;
use App\Models\User;

/** Droits sur une tâche. */
class TaskPolicy
{
    /** Voir / commenter : auteur, destinataires, présidence. */
    public function view(User $user, Task $task): bool
    {
        return $user->isPresidency()
            || $task->creator_id === $user->id
            || $task->recipients()->where('user_id', $user->id)->exists();
    }

    /** Supprimer : l'auteur ou la présidence. */
    public function delete(User $user, Task $task): bool
    {
        return $task->creator_id === $user->id || $user->isPresidency();
    }
}
