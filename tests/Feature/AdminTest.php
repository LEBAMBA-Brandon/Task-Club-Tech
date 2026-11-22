<?php

namespace Tests\Feature;

use App\Models\Department;
use App\Models\User;
use Database\Seeders\DepartmentSeeder;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

/** Le président et le vice-président administrent le système. */
class AdminTest extends TestCase
{
    use RefreshDatabase;

    public function test_presidency_manages_members_and_sees_all_departments(): void
    {
        $this->seed(DepartmentSeeder::class);
        $presidence = Department::where('slug', 'presidence')->first();
        $com = Department::where('slug', 'communication')->first();
        $logistique = Department::where('slug', 'logistique')->first();

        $vp = User::factory()->create(['department_id' => $presidence->id, 'position' => 'vice_president']);
        $member = User::factory()->create(['department_id' => $com->id]);
        $responsable = User::factory()->create(['department_id' => $com->id, 'position' => 'responsable']);

        Sanctum::actingAs($vp);

        // Tableau de bord : les 8 départements.
        $this->getJson('/api/v1/admin/departments')->assertOk()->assertJsonCount(8, 'data');

        // Changer un membre de département.
        $this->patchJson("/api/v1/members/{$member->id}", ['department_id' => $logistique->id])
            ->assertOk()->assertJsonPath('data.department.slug', 'logistique');

        // Poste incompatible avec le département -> refusé.
        $this->patchJson("/api/v1/members/{$member->id}", ['position' => 'president'])->assertUnprocessable();

        // Suspendre un compte.
        $this->patchJson("/api/v1/members/{$member->id}", ['status' => 'suspended'])
            ->assertOk()->assertJsonPath('data.status', 'suspended');

        // Il ne peut pas se retirer ses propres droits.
        $this->patchJson("/api/v1/members/{$vp->id}", ['status' => 'suspended'])->assertUnprocessable();

        // Le VP fait partie de tous les groupes de département.
        $this->getJson('/api/v1/conversations')->assertOk()->assertJsonCount(8, 'data');

        // Départements : créer, renommer, supprimer (vide), protéger la Présidence.
        $newId = $this->postJson('/api/v1/admin/departments', ['name' => 'Événementiel'])
            ->assertCreated()->json('data.id');
        $this->postJson('/api/v1/admin/departments', ['name' => 'événementiel'])->assertUnprocessable();
        $this->patchJson("/api/v1/admin/departments/{$newId}", ['name' => 'Événements'])
            ->assertOk()->assertJsonPath('data.name', 'Événements');
        $this->deleteJson("/api/v1/admin/departments/{$com->id}")->assertUnprocessable(); // a encore des membres
        $this->deleteJson("/api/v1/admin/departments/{$presidence->id}")->assertUnprocessable();
        $this->deleteJson("/api/v1/admin/departments/{$newId}")->assertOk();

        // Supprimer un membre : ses tâches restent, signées « Ancien membre ».
        Sanctum::actingAs($member->fresh());
        $this->patchJson("/api/v1/members/{$member->id}", ['status' => 'active'])->assertForbidden();
        Sanctum::actingAs($vp);
        $this->patchJson("/api/v1/members/{$member->id}", ['status' => 'active'])->assertOk();
        Sanctum::actingAs($member->fresh());
        $taskId = $this->postJson('/api/v1/tasks', ['title' => 'Test', 'department_id' => $com->id, 'urgency' => 'green'])
            ->assertCreated()->json('data.id');
        Sanctum::actingAs($vp);
        $this->deleteJson("/api/v1/members/{$member->id}")->assertOk();
        $this->assertDatabaseMissing('users', ['id' => $member->id]);
        $this->getJson("/api/v1/tasks/{$taskId}")->assertOk()->assertJsonPath('data.creator.first_name', 'Ancien');
        $this->deleteJson("/api/v1/members/{$vp->id}")->assertUnprocessable(); // pas soi-même

        // Un responsable n'a pas accès à l'administration.
        Sanctum::actingAs($responsable);
        $this->getJson('/api/v1/admin/departments')->assertForbidden();
        $this->postJson('/api/v1/admin/departments', ['name' => 'Pirate'])->assertForbidden();
    }
}
