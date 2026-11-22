<?php

namespace App\Http\Resources;

use Illuminate\Http\Request;
use Illuminate\Support\Carbon;

/** Membre + statistiques de suivi (page « Membres »). */
class MemberResource extends UserResource
{
    public function toArray(Request $request): array
    {
        $lastActive = $this->last_active_at ? Carbon::parse($this->last_active_at) : null;

        return parent::toArray($request) + [
            'stats' => [
                'tasks_total' => (int) ($this->tasks_total ?? 0),
                'tasks_done' => (int) ($this->tasks_done ?? 0),
                'tasks_unseen' => (int) ($this->tasks_unseen ?? 0),
            ],
            'last_active_at' => $lastActive?->toIso8601String(),
        ];
    }
}
