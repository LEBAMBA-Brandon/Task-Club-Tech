<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

/**
 * Tâches, destinataires (accusés reçu / vu / effectué façon WhatsApp)
 * et commentaires.
 */
return new class extends Migration
{
    public function up(): void
    {
        Schema::create('tasks', function (Blueprint $table) {
            $table->id();
            $table->foreignId('creator_id')->constrained('users')->cascadeOnDelete();
            $table->foreignId('department_id')->constrained()->restrictOnDelete();
            $table->string('title', 150);
            $table->text('description')->nullable();
            $table->string('urgency', 10)->index(); // green | blue | yellow | red
            $table->timestamp('due_at')->nullable();
            $table->timestamps();
            $table->softDeletes();
        });

        // Une ligne par membre destinataire : c'est elle qui porte les accusés.
        Schema::create('task_recipients', function (Blueprint $table) {
            $table->id();
            $table->foreignId('task_id')->constrained()->cascadeOnDelete();
            $table->foreignId('user_id')->constrained()->cascadeOnDelete();
            $table->timestamp('delivered_at')->nullable(); // reçu (✓✓ gris)
            $table->timestamp('seen_at')->nullable();      // vu   (✓✓ bleu)
            $table->timestamp('done_at')->nullable();      // effectué (coché par le membre)
            $table->timestamps();

            $table->unique(['task_id', 'user_id']);
            $table->index(['user_id', 'done_at']);
        });

        Schema::create('task_comments', function (Blueprint $table) {
            $table->id();
            $table->foreignId('task_id')->constrained()->cascadeOnDelete();
            $table->foreignId('user_id')->constrained()->cascadeOnDelete();
            $table->text('body');
            $table->timestamps();
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('task_comments');
        Schema::dropIfExists('task_recipients');
        Schema::dropIfExists('tasks');
    }
};
