<?php

namespace App\Models;

use App\Enums\Urgency;
use Illuminate\Database\Eloquent\Builder;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;
use Illuminate\Database\Eloquent\SoftDeletes;

/** Tâche rédigée par un membre et adressée à un département. */
class Task extends Model
{
    use SoftDeletes;

    protected $fillable = ['creator_id', 'department_id', 'title', 'description', 'urgency', 'due_at'];

    protected function casts(): array
    {
        return [
            'urgency' => Urgency::class,
            'due_at' => 'datetime',
        ];
    }

    public function creator(): BelongsTo
    {
        return $this->belongsTo(User::class, 'creator_id');
    }

    public function department(): BelongsTo
    {
        return $this->belongsTo(Department::class);
    }

    public function recipients(): HasMany
    {
        return $this->hasMany(TaskRecipient::class);
    }

    public function comments(): HasMany
    {
        return $this->hasMany(TaskComment::class);
    }

    /** Tâches visibles par $user : créées par lui, reçues, ou toutes s'il est de la présidence. */
    public function scopeVisibleTo(Builder $query, User $user): Builder
    {
        if ($user->isPresidency()) {
            return $query;
        }

        return $query->where(function (Builder $q) use ($user) {
            $q->where('creator_id', $user->id)
                ->orWhereHas('recipients', fn (Builder $r) => $r->where('user_id', $user->id));
        });
    }

    /** Ligne destinataire de $user pour cette tâche (null s'il n'est pas destinataire). */
    public function recipientFor(User $user): ?TaskRecipient
    {
        return $this->relationLoaded('recipients')
            ? $this->recipients->firstWhere('user_id', $user->id)
            : $this->recipients()->where('user_id', $user->id)->first();
    }
}
