<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

/**
 * Accusés d'une tâche pour un membre :
 *  envoyé (ligne créée) -> reçu (delivered_at) -> vu (seen_at) -> effectué (done_at)
 */
class TaskRecipient extends Model
{
    protected $fillable = ['task_id', 'user_id', 'delivered_at', 'seen_at', 'done_at'];

    protected function casts(): array
    {
        return [
            'delivered_at' => 'datetime',
            'seen_at' => 'datetime',
            'done_at' => 'datetime',
        ];
    }

    public function task(): BelongsTo
    {
        return $this->belongsTo(Task::class);
    }

    public function user(): BelongsTo
    {
        return $this->belongsTo(User::class);
    }

    /** Statut lisible : sent | delivered | seen | done */
    public function state(): string
    {
        return match (true) {
            $this->done_at !== null => 'done',
            $this->seen_at !== null => 'seen',
            $this->delivered_at !== null => 'delivered',
            default => 'sent',
        };
    }
}
