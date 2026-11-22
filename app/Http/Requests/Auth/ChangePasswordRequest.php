<?php

namespace App\Http\Requests\Auth;

use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Validation\Rules\Password;

/** Changement de mot de passe depuis le profil (utilisateur connecté). */
class ChangePasswordRequest extends FormRequest
{
    public function authorize(): bool
    {
        return true;
    }

    public function rules(): array
    {
        return [
            'current_password' => ['required', 'string', 'max:255'],
            'password' => ['required', 'confirmed', 'different:current_password', Password::min(8)->letters()->mixedCase()->numbers()],
        ];
    }

    public function messages(): array
    {
        return [
            'password.different' => 'Le nouveau mot de passe doit être différent de l\'ancien.',
            'password.confirmed' => 'Les mots de passe ne correspondent pas.',
        ];
    }
}
