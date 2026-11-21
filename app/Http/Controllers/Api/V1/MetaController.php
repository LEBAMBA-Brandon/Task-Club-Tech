<?php

namespace App\Http\Controllers\Api\V1;

use App\Enums\Position;
use App\Enums\Urgency;
use App\Http\Controllers\Controller;
use App\Http\Resources\DepartmentResource;
use App\Models\Department;
use Illuminate\Http\JsonResponse;

/**
 * Données de référence pour les listes déroulantes de l'application :
 * départements, postes autorisés par département, niveaux d'urgence.
 */
class MetaController extends Controller
{
    public function __invoke(): JsonResponse
    {
        $departments = Department::orderBy('name')->get();

        return response()->json([
            'club' => 'Club-Tech (C-Tech)',
            'departments' => DepartmentResource::collection($departments),
            'positions' => $departments->mapWithKeys(fn (Department $d) => [
                $d->id => array_map(fn (Position $p) => ['value' => $p->value, 'label' => $p->label()], Position::allowedFor($d->slug)),
            ]),
            'urgencies' => array_map(fn (Urgency $u) => ['value' => $u->value, 'label' => $u->label()], Urgency::cases()),
        ]);
    }
}
