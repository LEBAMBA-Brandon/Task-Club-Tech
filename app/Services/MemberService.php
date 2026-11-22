<?php

namespace App\Services;

use App\Enums\UserStatus;
use App\Models\User;
use Illuminate\Auth\Access\AuthorizationException;
use Illuminate\Database\Eloquent\Collection;

/**
 * Suivi des membres :
 *  - président et vice-président voient TOUS les membres du club ;
 *  - un responsable ne voit QUE les membres de son département ;
 *  - un simple membre n'a pas accès au suivi (mais a l'annuaire pour écrire à quelqu'un).
 */
class MemberService
{
    /** Le membre a-t-il accès à la page de suivi ? */
    public function canFollow(User $user): bool
    {
        return $user->isPresidency() || $user->position->value === 'responsable';
    }

    /**
     * Membres visibles avec leurs statistiques de tâches.
     *
     * @param  array{department_id?:int, status?:string, search?:string}  $filters
     */
    public function list(User $viewer, array $filters): Collection
    {
        if (! $this->canFollow($viewer)) {
            throw new AuthorizationException('Réservé à la présidence et aux responsables.');
        }

        $query = User::query()->with('department')
            ->where('status', '!=', UserStatus::Rejected->value)
            // Statistiques : tâches reçues, effectuées, pas encore ouvertes.
            ->withCount([
                'receivedTasks as tasks_total' => fn ($q) => $q->whereHas('task'),
                'receivedTasks as tasks_done' => fn ($q) => $q->whereHas('task')->whereNotNull('done_at'),
                'receivedTasks as tasks_unseen' => fn ($q) => $q->whereHas('task')->whereNull('seen_at'),
            ])
            // Dernière activité = dernière utilisation d'un jeton de connexion.
            ->withMax('tokens as last_active_at', 'last_used_at');

        if (! $viewer->isPresidency()) {
            $query->where('department_id', $viewer->department_id);
        } elseif (! empty($filters['department_id'])) {
            $query->where('department_id', $filters['department_id']);
        }

        if (! empty($filters['status'])) {
            $query->where('status', $filters['status']);
        }
        if (! empty($filters['search'])) {
            $term = '%'.mb_strtolower($filters['search']).'%';
            $query->where(fn ($q) => $q->whereRaw('LOWER(first_name) LIKE ?', [$term])
                ->orWhereRaw('LOWER(last_name) LIKE ?', [$term])
                ->orWhereRaw('LOWER(email) LIKE ?', [$term]));
        }

        return $query->orderBy('department_id')->orderBy('last_name')->get();
    }

    /** Annuaire pour la messagerie : tous les membres actifs (sauf soi). */
    public function directory(User $viewer, ?string $search): Collection
    {
        return User::with('department')
            ->where('status', UserStatus::Active->value)
            ->where('id', '!=', $viewer->id)
            ->when($search, function ($q) use ($search) {
                $term = '%'.mb_strtolower($search).'%';
                $q->where(fn ($w) => $w->whereRaw('LOWER(first_name) LIKE ?', [$term])
                    ->orWhereRaw('LOWER(last_name) LIKE ?', [$term]));
            })
            ->orderBy('last_name')->limit(200)->get();
    }
}
