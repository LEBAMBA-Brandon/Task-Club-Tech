<?php

namespace App\Services;

use App\Enums\Position;
use App\Enums\UserStatus;
use App\Models\Department;
use App\Models\Task;
use App\Models\TaskRecipient;
use App\Models\User;
use Illuminate\Auth\Access\AuthorizationException;
use Illuminate\Support\Collection;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Str;
use Illuminate\Validation\ValidationException;

/**
 * Administration du système, réservée au PRÉSIDENT et au VICE-PRÉSIDENT :
 *  - vue d'ensemble de tous les départements (membres, demandes, avancement des tâches) ;
 *  - gestion de n'importe quel membre : changer de département ou de poste,
 *    suspendre, réactiver ou supprimer un compte ;
 *  - gestion des départements : créer, renommer, supprimer.
 * Les responsables, eux, ne voient que leur département (voir MemberService).
 */
class AdminService
{
    public function assertAdmin(User $user): void
    {
        if (! $user->isActive() || ! $user->isPresidency()) {
            throw new AuthorizationException('Réservé au président et au vice-président.');
        }
    }

    /**
     * Tableau de bord des départements.
     *
     * @return Collection<int, array<string,mixed>>
     */
    public function departmentsOverview(User $admin): Collection
    {
        $this->assertAdmin($admin);

        // Lecture directe de la table (sans le « cast » enum du modèle) pour compter par statut.
        $members = DB::table('users')->select('department_id', 'status', DB::raw('COUNT(*) as total'))
            ->groupBy('department_id', 'status')->get()->groupBy('department_id');

        // Accusés des tâches adressées à chaque département (tâches non supprimées).
        $receipts = TaskRecipient::query()
            ->join('tasks', 'tasks.id', '=', 'task_recipients.task_id')
            ->whereNull('tasks.deleted_at')
            ->select('tasks.department_id',
                DB::raw('COUNT(*) as total'),
                DB::raw('SUM(CASE WHEN task_recipients.done_at IS NOT NULL THEN 1 ELSE 0 END) as done'),
                DB::raw('SUM(CASE WHEN task_recipients.seen_at IS NULL THEN 1 ELSE 0 END) as unseen'))
            ->groupBy('tasks.department_id')->get()->keyBy('department_id');

        $responsables = User::where('position', Position::Responsable->value)
            ->where('status', UserStatus::Active->value)->get()->keyBy('department_id');

        return Department::withCount(['tasks' => fn ($q) => $q->whereNull('deleted_at')])->orderBy('name')->get()
            ->map(function (Department $d) use ($members, $receipts, $responsables) {
                $byStatus = ($members[$d->id] ?? collect())->pluck('total', 'status');
                $r = $receipts[$d->id] ?? null;

                return [
                    'id' => $d->id,
                    'name' => $d->name,
                    'slug' => $d->slug,
                    'members_active' => (int) ($byStatus[UserStatus::Active->value] ?? 0),
                    'members_pending' => (int) ($byStatus[UserStatus::PendingApproval->value] ?? 0),
                    'members_suspended' => (int) ($byStatus[UserStatus::Suspended->value] ?? 0),
                    'responsable' => isset($responsables[$d->id]) ? $responsables[$d->id]->fullName() : null,
                    'tasks_count' => (int) $d->tasks_count,
                    'receipts_total' => (int) ($r->total ?? 0),
                    'receipts_done' => (int) ($r->done ?? 0),
                    'receipts_unseen' => (int) ($r->unseen ?? 0),
                ];
            });
    }

    /**
     * Modifie un membre (département, poste, statut).
     *
     * @param  array{department_id?:int, position?:string, status?:string}  $data
     */
    public function updateMember(User $admin, User $member, array $data): User
    {
        $this->assertAdmin($admin);

        $departmentId = (int) ($data['department_id'] ?? $member->department_id);
        $position = isset($data['position']) ? Position::from($data['position']) : $member->position;
        $status = isset($data['status']) ? UserStatus::from($data['status']) : $member->status;

        // Garde-fou : un administrateur ne peut ni se suspendre ni retirer sa propre présidence.
        if ($admin->id === $member->id && ($status !== UserStatus::Active || ! $position->isPresidency())) {
            throw ValidationException::withMessages(['status' => 'Vous ne pouvez pas retirer vos propres droits d\'administrateur.']);
        }

        $department = Department::findOrFail($departmentId);
        if (! in_array($position, Position::allowedFor($department->slug), true)) {
            throw ValidationException::withMessages(['position' => 'Ce poste n\'existe pas dans le département « '.$department->name.' ».']);
        }
        if ($position->isUnique() && PositionRules::isTaken($position, $department->id, $member->id)) {
            throw ValidationException::withMessages(['position' => 'Le poste « '.$position->label().' » est déjà occupé dans ce département.']);
        }

        DB::transaction(function () use ($member, $departmentId, $position, $status) {
            $member->forceFill([
                'department_id' => $departmentId,
                'position' => $position,
                'status' => $status,
            ])->save();

            // Compte suspendu : déconnecté de tous ses appareils, plus de notifications.
            if ($status === UserStatus::Suspended) {
                $member->tokens()->delete();
                $member->forceFill(['fcm_token' => null])->save();
            }
        });

        return $member->fresh('department');
    }

    /**
     * Supprime définitivement un compte.
     * L'historique reste : ses tâches, commentaires et messages sont signés « Ancien membre ».
     * Garde-fous : on ne se supprime pas soi-même ; le vice-président ne peut pas supprimer le président.
     */
    public function deleteMember(User $admin, User $member): void
    {
        $this->assertAdmin($admin);

        if ($admin->id === $member->id) {
            throw ValidationException::withMessages(['user' => 'Vous ne pouvez pas supprimer votre propre compte.']);
        }
        if ($member->position === Position::President && $admin->position !== Position::President) {
            throw ValidationException::withMessages(['user' => 'Seul le président peut supprimer le compte du président.']);
        }

        DB::transaction(function () use ($member) {
            $member->tokens()->delete(); // jetons de connexion (non liés par clé étrangère)
            $member->delete();           // le reste suit automatiquement (accusés, codes, participations...)
        });
    }

    /** Crée un département (postes : responsable et membres). */
    public function createDepartment(User $admin, string $name): Department
    {
        $this->assertAdmin($admin);
        $this->assertUniqueName($name);

        return Department::create(['name' => trim($name), 'slug' => $this->uniqueSlug($name)]);
    }

    /** Renomme un département (son identifiant interne ne change pas). */
    public function renameDepartment(User $admin, Department $department, string $name): Department
    {
        $this->assertAdmin($admin);
        $this->assertUniqueName($name, $department->id);
        $department->update(['name' => trim($name)]);

        return $department;
    }

    /**
     * Supprime un département.
     *  - La Présidence ne peut pas être supprimée.
     *  - Le département doit être vide : ses membres doivent d'abord être déplacés ou supprimés.
     *  - Ses tâches (et leurs accusés / commentaires) et son groupe de discussion sont supprimés avec lui.
     */
    public function deleteDepartment(User $admin, Department $department): void
    {
        $this->assertAdmin($admin);

        if ($department->slug === Department::PRESIDENCY_SLUG) {
            throw ValidationException::withMessages(['department' => 'La Présidence ne peut pas être supprimée.']);
        }
        $members = $department->users()->count();
        if ($members > 0) {
            throw ValidationException::withMessages([
                'department' => "Ce département compte encore {$members} membre(s) : déplacez-les ou supprimez-les d'abord.",
            ]);
        }

        DB::transaction(function () use ($department) {
            Task::withTrashed()->where('department_id', $department->id)->get()->each->forceDelete();
            $department->delete();
        });
    }

    private function assertUniqueName(string $name, ?int $ignoreId = null): void
    {
        $exists = Department::whereRaw('LOWER(name) = ?', [mb_strtolower(trim($name))])
            ->when($ignoreId, fn ($q) => $q->where('id', '!=', $ignoreId))
            ->exists();
        if ($exists) {
            throw ValidationException::withMessages(['name' => 'Un département porte déjà ce nom.']);
        }
    }

    private function uniqueSlug(string $name): string
    {
        $base = Str::slug($name) ?: 'departement';
        $slug = $base;
        for ($i = 2; Department::where('slug', $slug)->exists(); $i++) {
            $slug = "{$base}-{$i}";
        }

        return $slug;
    }
}
