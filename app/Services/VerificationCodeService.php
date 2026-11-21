<?php

namespace App\Services;

use App\Enums\CodePurpose;
use App\Mail\VerificationCodeMail;
use App\Models\User;
use App\Models\VerificationCode;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Facades\Log;
use Illuminate\Support\Facades\Mail;

/**
 * Génère, envoie et vérifie les codes à 6 chiffres.
 *
 * Sécurité :
 *  - le code est stocké haché (jamais en clair en base) ;
 *  - valable 10 minutes, 5 essais maximum, usage unique ;
 *  - un nouveau code invalide les précédents du même type.
 *
 * Sans compte SMTP (MAIL_MAILER=log), l'e-mail est écrit dans
 * storage/logs/laravel.log : c'est là qu'on lit le code en développement.
 */
class VerificationCodeService
{
    public const TTL_MINUTES = 10;

    /** Crée un code, l'envoie par e-mail et le retourne (en clair, pour le mode debug uniquement). */
    public function issue(User $user, CodePurpose $purpose): string
    {
        // Invalide les anciens codes non utilisés du même type.
        $user->verificationCodes()
            ->where('purpose', $purpose->value)
            ->whereNull('consumed_at')
            ->update(['consumed_at' => now()]);

        $code = (string) random_int(100000, 999999);

        $user->verificationCodes()->create([
            'purpose' => $purpose,
            'code_hash' => Hash::make($code),
            'expires_at' => now()->addMinutes(self::TTL_MINUTES),
        ]);

        try {
            Mail::to($user->email)->send(new VerificationCodeMail($user, $code, $purpose));
        } catch (\Throwable $e) {
            // L'échec d'envoi ne doit pas révéler d'information au client.
            Log::error('Envoi du code impossible', ['user' => $user->id, 'error' => $e->getMessage()]);
        }

        return $code;
    }

    /** Vérifie un code ; le consomme s'il est bon. */
    public function verify(User $user, CodePurpose $purpose, string $code): bool
    {
        /** @var VerificationCode|null $record */
        $record = $user->verificationCodes()
            ->where('purpose', $purpose->value)
            ->whereNull('consumed_at')
            ->latest('id')
            ->first();

        if (! $record || ! $record->isUsable()) {
            return false;
        }

        if (! Hash::check($code, $record->code_hash)) {
            $record->increment('attempts');

            return false;
        }

        $record->update(['consumed_at' => now()]);

        return true;
    }

    /** En local avec APP_DEBUG=true, on renvoie le code dans la réponse pour faciliter les tests. */
    public static function exposeInResponse(): bool
    {
        return app()->environment('local') && config('app.debug');
    }
}
