<?php

namespace Database\Factories;

use App\Enums\Position;
use App\Enums\UserStatus;
use App\Models\Department;
use App\Models\User;
use Illuminate\Database\Eloquent\Factories\Factory;

/** @extends Factory<User> */
class UserFactory extends Factory
{
    public function definition(): array
    {
        return [
            'first_name' => fake()->firstName(),
            'last_name' => fake()->lastName(),
            'email' => fake()->unique()->safeEmail(),
            'email_verified_at' => now(),
            'password' => 'Password123',
            'department_id' => Department::firstOrCreate(['slug' => 'communication'], ['name' => 'Communication'])->id,
            'position' => Position::Membre,
            'status' => UserStatus::Active,
            'terms_accepted_at' => now(),
        ];
    }
}
