<?php

namespace App\Models;

use App\Enums\Position;
use App\Enums\UserStatus;
use Database\Factories\UserFactory;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\BelongsToMany;
use Illuminate\Database\Eloquent\Relations\HasMany;
use Illuminate\Foundation\Auth\User as Authenticatable;
use Illuminate\Notifications\Notifiable;
use Laravel\Sanctum\HasApiTokens;

/**
 * Membre du club.
 *
 * @property Position   $position
 * @property UserStatus $status
 */
class User extends Authenticatable
{
    /** @use HasFactory<UserFactory> */
    use HasApiTokens, HasFactory, Notifiable;

    protected $fillable = [
        'first_name', 'last_name', 'email', 'password',
        'department_id', 'position', 'status', 'terms_accepted_at',
    ];

    /** Jamais renvoyés dans le JSON. */
    protected $hidden = ['password', 'remember_token', 'fcm_token'];

    protected function casts(): array
    {
        return [
            'email_verified_at' => 'datetime',
            'approved_at' => 'datetime',
            'terms_accepted_at' => 'datetime',
            'password' => 'hashed',
            'position' => Position::class,
            'status' => UserStatus::class,
        ];
    }

    // ---------------------------------------------------------------- Relations

    public function department(): BelongsTo
    {
        return $this->belongsTo(Department::class);
    }

    public function createdTasks(): HasMany
    {
        return $this->hasMany(Task::class, 'creator_id');
    }

    public function receivedTasks(): HasMany
    {
        return $this->hasMany(TaskRecipient::class);
    }

    public function conversations(): BelongsToMany
    {
        return $this->belongsToMany(Conversation::class, 'conversation_participants')
            ->withPivot('last_read_at')
            ->withTimestamps();
    }

    public function verificationCodes(): HasMany
    {
        return $this->hasMany(VerificationCode::class);
    }

    // ---------------------------------------------------------------- Helpers

    public function fullName(): string
    {
        return trim($this->first_name.' '.$this->last_name);
    }

    public function isActive(): bool
    {
        return $this->status === UserStatus::Active;
    }

    public function isPresidency(): bool
    {
        return $this->position->isPresidency();
    }

    /**
     * Peut-il valider l'inscription de $candidate ?
     *  - président / vice-président : tout le monde
     *  - responsable : seulement les membres de son département
     */
    public function canApprove(User $candidate): bool
    {
        if (! $this->isActive() || $candidate->id === $this->id) {
            return false;
        }
        if ($this->isPresidency()) {
            return true;
        }

        return $this->position === Position::Responsable
            && $candidate->position === Position::Membre
            && $candidate->department_id === $this->department_id;
    }
}
