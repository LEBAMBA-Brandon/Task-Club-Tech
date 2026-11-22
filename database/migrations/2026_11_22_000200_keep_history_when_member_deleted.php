<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

/**
 * Supprimer un membre ne doit pas effacer l'historique du club :
 * ses tâches, commentaires et messages restent, avec l'auteur à « null »
 * (affiché « Ancien membre » par l'API).
 */
return new class extends Migration
{
    /** [table, colonne] dont la clé étrangère passe de « cascade » à « null ». */
    private array $columns = [
        ['tasks', 'creator_id'],
        ['task_comments', 'user_id'],
        ['messages', 'user_id'],
    ];

    public function up(): void
    {
        foreach ($this->columns as [$table, $column]) {
            Schema::table($table, function (Blueprint $t) use ($column) {
                $t->dropForeign([$column]);
                $t->unsignedBigInteger($column)->nullable()->change();
                $t->foreign($column)->references('id')->on('users')->nullOnDelete();
            });
        }
    }

    public function down(): void
    {
        foreach ($this->columns as [$table, $column]) {
            Schema::table($table, function (Blueprint $t) use ($column) {
                $t->dropForeign([$column]);
                $t->foreign($column)->references('id')->on('users')->cascadeOnDelete();
            });
        }
    }
};
