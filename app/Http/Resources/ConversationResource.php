<?php

namespace App\Http\Resources;

use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

/**
 * Conversation vue par l'utilisateur connecté :
 * titre = nom de l'autre membre (privée) ou du département (groupe).
 */
class ConversationResource extends JsonResource
{
    public function toArray(Request $request): array
    {
        $me = $request->user();
        $other = $this->isDepartment() ? null : $this->participants->firstWhere('id', '!=', $me->id);

        return [
            'id' => $this->id,
            'type' => $this->type,
            'title' => $this->isDepartment()
                ? 'Groupe '.$this->department?->name
                : ($other?->fullName() ?? 'Ancien membre'),
            'subtitle' => $this->isDepartment()
                ? $this->participants->count().' membres'
                : ($other ? $other->position->label().' · '.$other->department?->name : null),
            'other_user' => $other ? new UserResource($other) : null,
            'last_message' => $this->lastMessage ? new MessageResource($this->lastMessage) : null,
            'unread_count' => (int) ($this->unread_count ?? 0),
            'updated_at' => ($this->last_message_at ?? $this->created_at)->toIso8601String(),
        ];
    }
}
