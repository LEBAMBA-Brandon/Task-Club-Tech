<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Http\Resources\UserResource;
use App\Models\User;
use App\Services\ApprovalService;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\AnonymousResourceCollection;

/** Validation des inscriptions (président, vice-président, responsables). */
class ApprovalController extends Controller
{
    public function __construct(private readonly ApprovalService $approvals) {}

    /** GET /approvals */
    public function index(Request $request): AnonymousResourceCollection
    {
        return UserResource::collection($this->approvals->pendingFor($request->user()));
    }

    /** POST /approvals/{user}/approve */
    public function approve(Request $request, User $user): UserResource
    {
        return new UserResource($this->approvals->approve($request->user(), $user)->load('department'));
    }

    /** POST /approvals/{user}/reject */
    public function reject(Request $request, User $user): UserResource
    {
        return new UserResource($this->approvals->reject($request->user(), $user)->load('department'));
    }
}
