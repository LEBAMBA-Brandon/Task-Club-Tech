<?php

namespace App\Console\Commands;

use App\Enums\UserStatus;
use App\Models\User;
use Illuminate\Console\Command;

/**
 * Valide un compte depuis le serveur.
 * Indispensable pour le tout premier compte (le président), puisqu'aucun
 * membre actif n'existe encore pour le valider depuis l'application.
 *
 *   php artisan ctech:approve president@exemple.com
 */
class ApproveUserCommand extends Command
{
    protected $signature = 'ctech:approve {email}';

    protected $description = 'Active un compte (e-mail confirmé ou non) sans passer par l\'application';

    public function handle(): int
    {
        $user = User::where('email', mb_strtolower($this->argument('email')))->first();
        if (! $user) {
            $this->error('Aucun compte avec cette adresse.');

            return self::FAILURE;
        }

        $user->forceFill([
            'status' => UserStatus::Active,
            'email_verified_at' => $user->email_verified_at ?? now(),
            'approved_at' => now(),
        ])->save();

        $this->info($user->fullName().' est maintenant actif ('.$user->position->label().').');

        return self::SUCCESS;
    }
}
