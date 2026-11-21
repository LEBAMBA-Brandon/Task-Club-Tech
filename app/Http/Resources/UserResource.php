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
}
