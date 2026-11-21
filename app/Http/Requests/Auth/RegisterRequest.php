<?php

namespace App\Http\Requests\Auth;

use App\Enums\Position;
use App\Models\Department;
use App\Services\PositionRules;
use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Validation\Rule;
use Illuminate\Validation\Rules\Password;
use Illuminate\Validation\Validator;

/** Validation de la page d'inscription. */
class RegisterRequest extends FormRequest
{
    public function authorize(): bool
    {
        return true;
    }

    public function rules(): array
    {
        return [
            'first_name' => ['required', 'string', 'max:80'],
            'last_name' => ['required', 'string', 'max:80'],
            'email' => ['required', 'email:rfc', 'max:255', 'unique:users,email'],
            'department_id' => ['required', 'integer', 'exists:departments,id'],
            'position' => ['required', Rule::enum(Position::class)],
            'password' => ['required', 'confirmed', Password::min(8)->letters()->mixedCase()->numbers()],
            'accept_terms' => ['accepted'],
        ];
    }

    /** Règles qui dépendent de plusieurs champs : poste compatible avec le département + unicité. */
    public function after(): array
    {
        return [function (Validator $validator) {
            if ($validator->errors()->isNotEmpty()) {
                return;
            }
            $department = Department::find($this->integer('department_id'));
            $position = Position::from($this->input('position'));

            if (! in_array($position, Position::allowedFor($department->slug), true)) {
                $validator->errors()->add('position', 'Ce poste n\'existe pas dans ce département.');

                return;
            }
            if (PositionRules::isTaken($position, $department->id)) {
                $validator->errors()->add('position', 'Le poste « '.$position->label().' » est déjà occupé.');
            }
        }];
    }

    public function messages(): array
    {
        return [
            'email.unique' => 'Cette adresse e-mail est déjà utilisée.',
            'accept_terms.accepted' => 'Vous devez accepter les conditions d\'utilisation.',
            'password.confirmed' => 'Les mots de passe ne correspondent pas.',
        ];
    }
}
