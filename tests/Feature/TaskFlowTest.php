<?php

namespace Tests\Feature;

use App\Models\Department;
use App\Models\User;
use Database\Seeders\DepartmentSeeder;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

/** Création d'une tâche, accusés reçu / vu / effectué, commentaires. */
class TaskFlowTest extends TestCase
{
    use RefreshDatabase;

    public function test_task_lifecycle(): void
    {
        $this->seed(DepartmentSeeder::class);
        $com = Department::where('slug', 'communication')->first();
        $logistique = Department::where('slug', 'logistique')->first();

        $author = User::factory()->create(['department_id' => $logistique->id]);
        $member = User::factory()->create(['department_id' => $com->id]);
        $outsider = User::factory()->create(['department_id' => $logistique->id]);

        Sanctum::actingAs($author);
        $taskId = $this->postJson('/api/v1/tasks', [
            'title' => 'Préparer l\'affiche',
            'department_id' => $com->id,
            'urgency' => 'red',
        ])->assertCreated()->assertJsonPath('data.stats.total', 1)->json('data.id');

        // Le membre a 1 tâche non lue.
        Sanctum::actingAs($member);
        $this->getJson('/api/v1/tasks/unread-count')->assertJson(['count' => 1]);
        // Il liste ses tâches : accusé « reçu ».
        $this->getJson('/api/v1/tasks?box=received')->assertOk()->assertJsonCount(1, 'data');
        // Il ouvre la tâche : accusé « vu ».
        $this->getJson("/api/v1/tasks/{$taskId}")->assertOk()->assertJsonPath('data.my_state.state', 'seen');
        $this->getJson('/api/v1/tasks/unread-count')->assertJson(['count' => 0]);
        // Il coche « effectué ».
        $this->postJson("/api/v1/tasks/{$taskId}/done")->assertOk()->assertJsonPath('data.my_state.state', 'done');
        $this->postJson("/api/v1/tasks/{$taskId}/comments", ['body' => 'Fait !'])->assertCreated();

        // L'auteur voit les accusés.
        Sanctum::actingAs($author);
        $this->getJson("/api/v1/tasks/{$taskId}")->assertJsonPath('data.stats.done', 1)
            ->assertJsonPath('data.recipients.0.state', 'done');

        // Un membre non concerné ne peut pas voir la tâche.
        Sanctum::actingAs($outsider);
        $this->getJson("/api/v1/tasks/{$taskId}")->assertForbidden();
    }
}
