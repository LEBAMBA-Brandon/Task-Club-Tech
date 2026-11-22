<?php

namespace Tests\Feature;

use App\Models\Department;
use App\Models\User;
use App\Services\FirebaseTokenVerifier;
use Database\Seeders\DepartmentSeeder;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

/** Connexion Google / GitHub (le vérificateur Firebase est simulé). */
class SocialAuthTest extends TestCase
{
    use RefreshDatabase;

    protected function setUp(): void
    {
        parent::setUp();
        $this->seed(DepartmentSeeder::class);

        // Faux vérificateur : accepte n'importe quel jeton comme « Jean Mba via Google ».
        $this->app->instance(FirebaseTokenVerifier::class, new class extends FirebaseTokenVerifier
        {
            public function __construct() {}

            public function verify(string $idToken): array
            {
                return ['uid' => 'abc', 'email' => 'jean@gmail.com', 'name' => 'Jean Mba',
                    'provider' => 'google.com', 'email_verified' => true];
            }
        });
    }

    public function test_new_social_user_must_complete_profile_then_waits_for_approval(): void
    {
        $this->postJson('/api/v1/auth/social', ['id_token' => 'x'])
            ->assertStatus(409)
            ->assertJson(['code' => 'PROFILE_REQUIRED', 'data' => ['first_name' => 'Jean', 'last_name' => 'Mba']]);

        $this->postJson('/api/v1/auth/social', [
            'id_token' => 'x',
            'department_id' => Department::where('slug', 'communication')->value('id'),
            'position' => 'membre',
            'accept_terms' => true,
        ])->assertForbidden()->assertJson(['code' => 'ACCOUNT_PENDING']);

        $this->assertNotNull(User::where('email', 'jean@gmail.com')->value('email_verified_at'));

        $this->artisan('ctech:approve', ['email' => 'jean@gmail.com'])->assertSuccessful();
        $this->postJson('/api/v1/auth/social', ['id_token' => 'x'])->assertOk()->assertJsonStructure(['token']);
    }
}
