<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

/**
 * Plateforme du jeton de notification : android | web.
 * Les navigateurs ne reçoivent pas les signaux « silencieux » (ils afficheraient
 * un message générique) : la version web se met à jour par interrogation régulière.
 */
return new class extends Migration
{
    public function up(): void
    {
        Schema::table('users', function (Blueprint $table) {
            $table->string('fcm_platform', 10)->nullable()->after('fcm_token');
        });
    }

    public function down(): void
    {
        Schema::table('users', function (Blueprint $table) {
            $table->dropColumn('fcm_platform');
        });
    }
};
