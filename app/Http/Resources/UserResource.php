<?php

namespace App\Http\Resources;

use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

/** Profil public d'un membre (aucune donnée sensible). */
class UserResource extends JsonResource
{
    public function toArray(Request $request): array
    {
        return [
            'id' => $this->id,
            'first_name' => $this->first_name,
            'last_name' => $this->last_name,
            'email' => $this->email,
            'position' => $this->position->value,
            'position_label' => $this->position->label(),
            'status' => $this->status->value,
            'department' => new DepartmentResource($this->whenLoaded('department')),
            'created_at' => $this->created_at?->toIso8601String(),
        ];
    }

    /**
     * Auteur éventuellement supprimé : renvoie un « Ancien membre » au même format,
     * pour que l'application n'ait jamais d'auteur vide à gérer.
     */
    public static function orDeleted(mixed $user): UserResource|array
    {
        if ($user) {
            return new self($user);
        }

        return [
            'id' => 0,
            'first_name' => 'Ancien',
            'last_name' => 'membre',
            'email' => '',
            'position' => 'membre',
            'position_label' => 'Compte supprimé',
            'status' => 'deleted',
            'department' => null,
            'created_at' => null,
        ];
    }
}
