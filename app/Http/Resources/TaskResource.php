<?php

namespace App\Http\Resources;

use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

/**
 * Une tâche telle que vue par l'utilisateur connecté :
 *  - « my_state » : son propre accusé s'il est destinataire ;
 *  - « recipients » : la liste complète des accusés, visible par l'auteur et la présidence ;
 *  - « stats » : compteurs reçu / vu / effectué.
 */
class TaskResource extends JsonResource
{
    public function toArray(Request $request): array
    {
        $user = $request->user();
        $mine = $this->recipients->firstWhere('user_id', $user->id);
        $canSeeReceipts = $this->creator_id === $user->id || $user->isPresidency();

        return [
            'id' => $this->id,
            'title' => $this->title,
            'description' => $this->description,
            'urgency' => $this->urgency->value,
            'urgency_label' => $this->urgency->label(),
            'due_at' => $this->due_at?->toIso8601String(),
            'created_at' => $this->created_at->toIso8601String(),
            'creator' => UserResource::orDeleted($this->creator),
            'department' => new DepartmentResource($this->department),
            'is_mine' => $this->creator_id === $user->id,
            'my_state' => $mine ? new TaskRecipientResource($mine) : null,
            'stats' => [
                'total' => $this->recipients->count(),
                'delivered' => $this->recipients->whereNotNull('delivered_at')->count(),
                'seen' => $this->recipients->whereNotNull('seen_at')->count(),
                'done' => $this->recipients->whereNotNull('done_at')->count(),
            ],
            'recipients' => $canSeeReceipts ? TaskRecipientResource::collection($this->recipients) : [],
            'comments_count' => $this->comments_count ?? 0,
        ];
    }
}
