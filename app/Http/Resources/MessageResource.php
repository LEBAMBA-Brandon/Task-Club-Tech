<?php

namespace App\Http\Resources;

use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

class MessageResource extends JsonResource
{
    public function toArray(Request $request): array
    {
        return [
            'id' => $this->id,
            'conversation_id' => $this->conversation_id,
            'body' => $this->body,
            'author' => new UserResource($this->whenLoaded('user')),
            'is_mine' => $this->user_id === $request->user()->id,
            'created_at' => $this->created_at->toIso8601String(),
        ];
    }
}
