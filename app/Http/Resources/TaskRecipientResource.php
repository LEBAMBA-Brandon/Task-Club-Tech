<?php

namespace App\Http\Resources;

use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

/** Accusés d'un destinataire : sent | delivered | seen | done. */
class TaskRecipientResource extends JsonResource
{
    public function toArray(Request $request): array
    {
        return [
            'user' => new UserResource($this->whenLoaded('user')),
            'state' => $this->state(),
            'delivered_at' => $this->delivered_at?->toIso8601String(),
            'seen_at' => $this->seen_at?->toIso8601String(),
            'done_at' => $this->done_at?->toIso8601String(),
        ];
    }
}
