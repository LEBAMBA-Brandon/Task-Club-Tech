<?php

namespace Tests\Feature;

use App\Models\Department;
use App\Models\User;
use Database\Seeders\DepartmentSeeder;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

/** Messagerie, compteurs et suivi des membres selon le rôle. */
class ChatAndMembersTest extends TestCase
{
    use RefreshDatabase;

    private Department $com;
    private Department $logistique;

    protected function setUp(): void
    {
        parent::setUp();
        $this->seed(DepartmentSeeder::class);
        $this->com = Department::where('slug', 'communication')->first();
        $this->logistique = Department::where('slug', 'logistique')->first();
    }

    public function test_direct_chat_and_unread_counter(): void
    {
        $alice = User::factory()->create(['department_id' => $this->com->id]);
        $bob = User::factory()->create(['department_id' => $this->logistique->id]);

        // Alice ouvre une conversation avec Bob et lui écrit.
        Sanctum::actingAs($alice);
        $conversationId = $this->postJson('/api/v1/conversations', ['user_id' => $bob->id])
            ->assertSuccessful()->json('data.id');
        $this->postJson("/api/v1/conversations/{$conversationId}/messages", ['body' => 'Salut Bob'])->assertCreated();

        // Bob a 1 message non lu, puis 0 après lecture.
        Sanctum::actingAs($bob);
        $this->getJson('/api/v1/counters')->assertJson(['messages_unread' => 1]);
        $this->getJson("/api/v1/conversations/{$conversationId}/messages")
            ->assertOk()->assertJsonPath('data.0.body', 'Salut Bob');
        $this->getJson('/api/v1/counters')->assertJson(['messages_unread' => 0]);

        // Un troisième membre ne peut pas lire cette conversation.
        Sanctum::actingAs(User::factory()->create(['department_id' => $this->com->id]));
        $this->getJson("/api/v1/conversations/{$conversationId}/messages")->assertForbidden();
    }

    public function test_department_group_is_created_automatically(): void
    {
        $member = User::factory()->create(['department_id' => $this->com->id]);
        Sanctum::actingAs($member);

        $this->getJson('/api/v1/conversations')
            ->assertOk()
            ->assertJsonPath('data.0.type', 'department')
            ->assertJsonPath('data.0.title', 'Groupe Communication');
    }

    public function test_members_visibility_depends_on_role(): void
    {
        $presidence = Department::where('slug', 'presidence')->first();
        $president = User::factory()->create(['department_id' => $presidence->id, 'position' => 'president']);
        $responsable = User::factory()->create(['department_id' => $this->com->id, 'position' => 'responsable']);
        User::factory()->create(['department_id' => $this->com->id]);
        User::factory()->create(['department_id' => $this->logistique->id]);
        $simpleMember = User::factory()->create(['department_id' => $this->logistique->id]);

        // Président : tout le club (5 comptes).
        Sanctum::actingAs($president);
        $this->getJson('/api/v1/members')->assertOk()->assertJsonCount(5, 'data');

        // Responsable : seulement son département (lui + 1 membre).
        Sanctum::actingAs($responsable);
        $this->getJson('/api/v1/members')->assertOk()->assertJsonCount(2, 'data');

        // Simple membre : pas d'accès au suivi, mais accès à l'annuaire.
        Sanctum::actingAs($simpleMember);
        $this->getJson('/api/v1/members')->assertForbidden();
        $this->getJson('/api/v1/directory')->assertOk()->assertJsonCount(4, 'data');
    }
}
