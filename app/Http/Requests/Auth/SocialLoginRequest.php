<?php

namespace App\Http\Requests\Auth;

use App\Enums\Position;
use App\Models\Department;
use App\Services\PositionRules;
use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Validation\Rule;
use Illuminate\Validation\Validator;

/**
 * Connexion Google. Les champs du profil ne sont demandés
 * que pour un nouveau compte (2e appel, après la réponse PROFILE_REQUIRED).
 */
class SocialLoginRequest extends FormRequest
{
    public function authorize(): bool
    {
        return true;
    }

    public function rules(): array
    {
        return [
            'id_token' => ['required', 'string', 'max:4096'],
            'device_name' => ['nullable', 'string', 'max:100'],
            'first_name' => ['nullable', 'string', 'max:80'],
            'last_name' => ['nullable', 'string', 'max:80'],
            'department_id' => ['nullable', 'integer', 'exists:departments,id'],
            'position' => ['nullable', Rule::enum(Position::class)],
            'accept_terms' => ['nullable', 'boolean'],
        ];
    }

    /** Même contrôle qu'à l'inscription classique : poste cohérent avec le département et libre. */
    public function after(): array
    {
        return [function (Validator $validator) {
            if ($validator->errors()->isNotEmpty() || ! $this->filled(['department_id', 'position'])) {
                return;
            }
            $department = Department::find($this->integer('department_id'));
            $position = Position::from($this->input('position'));

            if (! in_array($position, Position::allowedFor($department->slug), true)) {
                $validator->errors()->add('position', 'Ce poste n\'existe pas dans ce département.');
            } elseif (PositionRules::isTaken($position, $department->id, null)) {
                $validator->errors()->add('position', 'Le poste « '.$position->label().' » est déjà occupé.');
            }
        }];
    }
}
