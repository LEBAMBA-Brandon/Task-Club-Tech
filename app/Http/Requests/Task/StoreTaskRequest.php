<?php

namespace App\Http\Requests\Task;

use App\Enums\Urgency;
use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Validation\Rule;

/** Création d'une tâche : n'importe quel membre actif peut en rédiger une. */
class StoreTaskRequest extends FormRequest
{
    public function authorize(): bool
    {
        return true;
    }

    public function rules(): array
    {
        return [
            'title' => ['required', 'string', 'max:150'],
            'description' => ['nullable', 'string', 'max:5000'],
            'department_id' => ['required', 'integer', 'exists:departments,id'],
            'urgency' => ['required', Rule::enum(Urgency::class)],
            'due_at' => ['nullable', 'date', 'after:now'],
        ];
    }
}
