<?php

namespace App\Services;

use App\Enums\Position;
use App\Enums\UserStatus;
use App\Models\User;

/**
 * Règles d'unicité des postes :
 *  - un seul président et un seul vice-président dans le club ;
 *  - un seul responsable par département.
 * Un compte refusé ne bloque pas le poste.
 */
class PositionRules
{
    public static function isTaken(Position $position, int $departmentId, ?int $ignoreUserId = null): bool
    {
        if (! $position->isUnique()) {
            return false;
        }

        $query = User::where('position', $position->value)
            ->whereNotIn('status', [UserStatus::Rejected->value]);

        // Le responsable est unique par département ; président et VP uniques dans le club.
        if ($position === Position::Responsable) {
            $query->where('department_id', $departmentId);
        }

        if ($ignoreUserId) {
            $query->where('id', '!=', $ignoreUserId);
        }

        return $query->exists();
    }
}
