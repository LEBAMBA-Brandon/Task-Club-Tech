<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Http\Requests\Task\StoreTaskRequest;
use App\Http\Resources\TaskResource;
use App\Models\Task;
use App\Services\TaskService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\AnonymousResourceCollection;
use Illuminate\Support\Facades\Gate;

class TaskController extends Controller
{
    public function __construct(private readonly TaskService $tasks) {}

    /** GET /tasks?box=received|sent|all&urgency=&state=todo|done&search= */
    public function index(Request $request): AnonymousResourceCollection
    {
        $filters = $request->validate([
            'box' => ['nullable', 'in:received,sent,all'],
            'urgency' => ['nullable', 'in:green,blue,yellow,red'],
            'state' => ['nullable', 'in:todo,done'],
            'search' => ['nullable', 'string', 'max:100'],
            'per_page' => ['nullable', 'integer', 'min:1', 'max:50'],
        ]);

        return TaskResource::collection(
            $this->tasks->list($request->user(), $filters['box'] ?? 'received', $filters)
        );
    }

    /** POST /tasks */
    public function store(StoreTaskRequest $request): JsonResponse
    {
        $task = $this->tasks->create($request->user(), $request->validated());

        return (new TaskResource($task))->response()->setStatusCode(201);
    }

    /** GET /tasks/{task} : marque la tâche « vue ». */
    public function show(Request $request, Task $task): TaskResource
    {
        Gate::authorize('view', $task);

        return new TaskResource($this->tasks->show($request->user(), $task));
    }

    /** POST /tasks/{task}/done : « effectué » coché par le membre. */
    public function markDone(Request $request, Task $task): TaskResource
    {
        Gate::authorize('view', $task);

        return new TaskResource($this->tasks->setDone($request->user(), $task, true));
    }

    /** DELETE /tasks/{task}/done : décoche « effectué ». */
    public function unmarkDone(Request $request, Task $task): TaskResource
    {
        Gate::authorize('view', $task);

        return new TaskResource($this->tasks->setDone($request->user(), $task, false));
    }

    /** POST /tasks/delivered {task_ids: []} : accusé « reçu » (ex. à la réception d'une notification). */
    public function delivered(Request $request): JsonResponse
    {
        $data = $request->validate(['task_ids' => ['required', 'array', 'max:100'], 'task_ids.*' => ['integer']]);
        $this->tasks->markDelivered($request->user(), $data['task_ids']);

        return response()->json(['message' => 'ok']);
    }

    /** DELETE /tasks/{task} */
    public function destroy(Task $task): JsonResponse
    {
        Gate::authorize('delete', $task);
        $task->delete();

        return response()->json(['message' => 'Tâche supprimée.']);
    }
}
