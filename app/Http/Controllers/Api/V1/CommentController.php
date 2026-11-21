<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Http\Requests\Task\StoreCommentRequest;
use App\Http\Resources\CommentResource;
use App\Models\Task;
use App\Services\TaskService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Resources\Json\AnonymousResourceCollection;
use Illuminate\Support\Facades\Gate;

class CommentController extends Controller
{
    public function __construct(private readonly TaskService $tasks) {}

    /** GET /tasks/{task}/comments */
    public function index(Task $task): AnonymousResourceCollection
    {
        Gate::authorize('view', $task);

        return CommentResource::collection($task->comments()->with('user.department')->oldest()->get());
    }

    /** POST /tasks/{task}/comments */
    public function store(StoreCommentRequest $request, Task $task): JsonResponse
    {
        Gate::authorize('view', $task);
        $comment = $this->tasks->addComment($request->user(), $task, $request->input('body'));

        return (new CommentResource($comment))->response()->setStatusCode(201);
    }
}
