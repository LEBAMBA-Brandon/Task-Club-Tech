<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Http\Resources\MemberResource;
use App\Http\Resources\UserResource;
use App\Http\Resources\DepartmentResource;
use App\Models\Department;
use App\Models\User;
use App\Services\AdminService;
use App\Services\MemberService;
use Illuminate\Http\JsonResponse;
use Illuminate\Validation\Rule;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\AnonymousResourceCollection;

class MemberController extends Controller
{
    public function __construct(private readonly MemberService $members) {}

    /** GET /members?department_id=&status=&search= : suivi (présidence : tous ; responsable : son département). */
    public function index(Request $request): AnonymousResourceCollection
    {
        $filters = $request->validate([
            'department_id' => ['nullable', 'integer'],
            'status' => ['nullable', 'in:pending_verification,pending_approval,active,suspended'],
            'search' => ['nullable', 'string', 'max:100'],
        ]);

        return MemberResource::collection($this->members->list($request->user(), $filters));
    }

    /** GET /admin/departments : tableau de bord des départements (président / vice-président). */
    public function departments(Request $request, AdminService $admin): JsonResponse
    {
        return response()->json(['data' => $admin->departmentsOverview($request->user())]);
    }

    /** PATCH /members/{user} {department_id?, position?, status?} : gestion d'un membre (président / vice-président). */
    public function update(Request $request, User $user, AdminService $admin): MemberResource
    {
        $data = $request->validate([
            'department_id' => ['sometimes', 'integer', 'exists:departments,id'],
            'position' => ['sometimes', Rule::in(['president', 'vice_president', 'responsable', 'membre'])],
            'status' => ['sometimes', Rule::in(['active', 'suspended'])],
        ]);

        $updated = $admin->updateMember($request->user(), $user, $data);
        // Recharge le membre avec ses statistiques (même format que la liste).
        $fresh = $this->members->list($request->user(), [])->firstWhere('id', $updated->id) ?? $updated;

        return new MemberResource($fresh);
    }

    /** DELETE /members/{user} : suppression définitive d'un compte (président / vice-président). */
    public function destroy(Request $request, User $user, AdminService $admin): JsonResponse
    {
        $admin->deleteMember($request->user(), $user);

        return response()->json(['message' => 'Compte supprimé.']);
    }

    /** POST /admin/departments {name} */
    public function storeDepartment(Request $request, AdminService $admin): JsonResponse
    {
        $data = $request->validate(['name' => ['required', 'string', 'min:2', 'max:80']]);

        return (new DepartmentResource($admin->createDepartment($request->user(), $data['name'])))
            ->response()->setStatusCode(201);
    }

    /** PATCH /admin/departments/{department} {name} */
    public function updateDepartment(Request $request, Department $department, AdminService $admin): DepartmentResource
    {
        $data = $request->validate(['name' => ['required', 'string', 'min:2', 'max:80']]);

        return new DepartmentResource($admin->renameDepartment($request->user(), $department, $data['name']));
    }

    /** DELETE /admin/departments/{department} */
    public function destroyDepartment(Request $request, Department $department, AdminService $admin): JsonResponse
    {
        $admin->deleteDepartment($request->user(), $department);

        return response()->json(['message' => 'Département supprimé.']);
    }

    /** GET /directory?search= : annuaire des membres actifs (pour démarrer une conversation). */
    public function directory(Request $request): AnonymousResourceCollection
    {
        $data = $request->validate(['search' => ['nullable', 'string', 'max:100']]);

        return UserResource::collection($this->members->directory($request->user(), $data['search'] ?? null));
    }
}
