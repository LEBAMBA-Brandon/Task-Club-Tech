<?php

namespace App\Http\Controllers\Api\V1;

use App\Enums\UserStatus;
use App\Http\Controllers\Controller;
use App\Http\Resources\UserResource;
use App\Models\Department;
use Illuminate\Http\Resources\Json\AnonymousResourceCollection;

class DepartmentController extends Controller
{
    /** GET /departments/{department}/members : membres actifs d'un département. */
    public function members(Department $department): AnonymousResourceCollection
    {
        return UserResource::collection(
            $department->users()->with('department')
                ->where('status', UserStatus::Active->value)
                ->orderBy('last_name')->get()
        );
    }
}
