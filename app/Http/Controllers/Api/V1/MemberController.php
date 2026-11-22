<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Http\Resources\MemberResource;
use App\Http\Resources\UserResource;
use App\Services\MemberService;
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

    /** GET /directory?search= : annuaire des membres actifs (pour démarrer une conversation). */
    public function directory(Request $request): AnonymousResourceCollection
    {
        $data = $request->validate(['search' => ['nullable', 'string', 'max:100']]);

        return UserResource::collection($this->members->directory($request->user(), $data['search'] ?? null));
    }
}
