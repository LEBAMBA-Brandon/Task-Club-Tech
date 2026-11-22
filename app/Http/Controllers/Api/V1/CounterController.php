<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Services\ApprovalService;
use App\Services\ChatService;
use App\Services\TaskService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

/**
 * GET /counters : les pastilles de l'application en un seul appel
 * (interrogé régulièrement par l'application pour se mettre à jour toute seule).
 */
class CounterController extends Controller
{
    public function __invoke(Request $request, TaskService $tasks, ApprovalService $approvals, ChatService $chat): JsonResponse
    {
        $user = $request->user();

        return response()->json([
            'tasks_unread' => $tasks->unreadCount($user),
            'approvals_pending' => $user->isPresidency() || $user->position->value === 'responsable'
                ? $approvals->pendingFor($user)->count()
                : 0,
            'messages_unread' => $chat->unreadTotal($user),
        ]);
    }
}
