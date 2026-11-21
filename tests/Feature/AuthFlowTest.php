<?php

namespace Tests\Feature;

use App\Enums\UserStatus;
use App\Models\Department;
use App\Models\User;
use Database\Seeders\DepartmentSeeder;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

/** Parcours complet : inscription -> code e-mail -> validation -> connexion. */
class AuthFlowTest extends TestCase
{
    use RefreshDatabase;

    protected function setUp(): void
    {
        parent::setUp();
        $this->seed(DepartmentSeeder::class);
    }

    private function payload(array $overrides = []): array
    {
        return array_merge([
            'first_name' => 'Axel',
            'last_name' => 'Assoume',
            'email' => 'axel@example.com',
            'department_id' => Department::where('slug', 'communication')->value('id'),
            'position' => 'membre',
            'password' => 'Password123',
            'password_confirmation' => 'Password123',
            'accept_terms' => true,
        ], $overrides);
    }

    public function test_full_registration_flow(): void
    {
        $this->postJson('/api/v1/auth/register', $this->payload())->assertCreated();

        // Connexion refusée tant que l'e-mail n'est pas confirmé.
        $this->postJson('/api/v1/auth/login', ['email' => 'axel@example.com', 'password' => 'Password123'])
            ->assertForbidden()->assertJson(['code' => 'EMAIL_NOT_VERIFIED']);

        // On force un code connu pour le test.
        $user = User::first();
        $code = app(\App\Services\VerificationCodeService::class)->issue($user, \App\Enums\CodePurpose::EmailVerification);
        $this->postJson('/api/v1/auth/verify-email', ['email' => 'axel@example.com', 'code' => $code])->assertOk();
        $this->assertSame(UserStatus::PendingApproval, $user->fresh()->status);

        $this->postJson('/api/v1/auth/login', ['email' => 'axel@example.com', 'password' => 'Password123'])
            ->assertForbidden()->assertJson(['code' => 'ACCOUNT_PENDING']);

        $this->artisan('ctech:approve', ['email' => 'axel@example.com'])->assertSuccessful();

        $this->postJson('/api/v1/auth/login', ['email' => 'axel@example.com', 'password' => 'Password123'])
            ->assertOk()->assertJsonStructure(['token', 'expires_at', 'user' => ['id', 'department']]);
    }

    public function test_position_must_match_department(): void
    {
        $this->postJson('/api/v1/auth/register', $this->payload(['position' => 'president']))
            ->assertUnprocessable()->assertJsonValidationErrors('position');
    }

    public function test_only_one_responsable_per_department(): void
    {
        User::factory()->create(['position' => 'responsable']);

        $this->postJson('/api/v1/auth/register', $this->payload(['position' => 'responsable']))
            ->assertUnprocessable()->assertJsonValidationErrors('position');
    }
}
