<?php

namespace App\Services;

use App\Enums\Position;
use App\Enums\UserStatus;
use App\Models\User;
use Illuminate\Auth\Access\AuthorizationException;
use Illuminate\Database\Eloquent\Collection;
use Illuminate\Validation\ValidationException;

/**
 * Validation des nouveaux comptes par la présidence ou le responsable du département.
 */
class ApprovalService
{
    /** Comptes en attente que $approver a le droit de valider. */
    public function pendingFor(User $approver): Collection
    {
        return User::with('department')
            ->where('status', UserStatus::PendingApproval)
            ->orderBy('created_at')
            ->get()
            ->filter(fn (User $candidate) => $approver->canApprove($candidate))
            ->values();
    }

    public function approve(User $approver, User $candidate): User
    {
        $this->authorize($approver, $candidate);

        // Re-vérifie l'unicité du poste au moment de la validation.
        if ($candidate->position->isUnique() && PositionRules::isTaken($candidate->position, $candidate->department_id, $candidate->id)) {
            throw ValidationException::withMessages([
                'position' => 'Ce poste est déjà occupé par un membre actif.',
            ]);
        }

        $candidate->forceFill([
            'status' => UserStatus::Active,
            'approved_by' => $approver->id,
            'approved_at' => now(),
        ])->save();

        return $candidate;
    }

    public function reject(User $approver, User $candidate): User
    {
        $this->authorize($approver, $candidate);

        $candidate->forceFill([
            'status' => UserStatus::Rejected,
            'approved_by' => $approver->id,
            'approved_at' => now(),
        ])->save();

        return $candidate;
    }

    private function authorize(User $approver, User $candidate): void
    {
        if ($candidate->status !== UserStatus::PendingApproval || ! $approver->canApprove($candidate)) {
            throw new AuthorizationException('Vous ne pouvez pas valider ce compte.');
        }
    }
}
