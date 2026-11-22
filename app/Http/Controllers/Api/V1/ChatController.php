<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Http\Resources\ConversationResource;
use App\Http\Resources\MessageResource;
use App\Models\Conversation;
use App\Models\User;
use App\Services\ChatService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\AnonymousResourceCollection;

/** Messagerie entre membres (conversations privées et groupe de département). */
class ChatController extends Controller
{
    public function __construct(private readonly ChatService $chat) {}

    /** GET /conversations */
    public function index(Request $request): AnonymousResourceCollection
    {
        return ConversationResource::collection($this->chat->listFor($request->user()));
    }

    /** POST /conversations {user_id} : ouvre (ou crée) la conversation privée avec un membre. */
    public function store(Request $request): ConversationResource
    {
        $data = $request->validate(['user_id' => ['required', 'integer', 'exists:users,id']]);
        $conversation = $this->chat->direct($request->user(), User::findOrFail($data['user_id']));

        return new ConversationResource($conversation->load(['department', 'lastMessage.user', 'participants.department']));
    }

    /** GET /conversations/{conversation}/messages?after_id=&before_id= */
    public function messages(Request $request, Conversation $conversation): AnonymousResourceCollection
    {
        $data = $request->validate([
            'after_id' => ['nullable', 'integer'],
            'before_id' => ['nullable', 'integer'],
        ]);

        return MessageResource::collection($this->chat->messages(
            $request->user(), $conversation, $data['after_id'] ?? null, $data['before_id'] ?? null,
        ));
    }

    /** POST /conversations/{conversation}/messages {body} */
    public function send(Request $request, Conversation $conversation): JsonResponse
    {
        $data = $request->validate(['body' => ['required', 'string', 'max:2000']]);
        $message = $this->chat->send($request->user(), $conversation, trim($data['body']));

        return (new MessageResource($message))->response()->setStatusCode(201);
    }

    /** POST /conversations/{conversation}/read : tout marquer comme lu. */
    public function read(Request $request, Conversation $conversation): JsonResponse
    {
        $this->chat->authorize($request->user(), $conversation);
        $this->chat->markRead($request->user(), $conversation);

        return response()->json(['message' => 'ok']);
    }
}
