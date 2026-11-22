<?php

namespace App\Services;

use App\Enums\CodePurpose;
use App\Models\User;
use App\Models\VerificationCode;
use Illuminate\Support\Facades\Hash;

/**
 * Génère, envoie et vérifie les codes à 6 chiffres.
 *
 * Sécurité :
 *  - le code est stocké haché (jamais en clair en base) ;
 *  - valable 10 minutes, 5 essais maximum, usage unique ;
 *  - un nouveau code invalide les précédents du même type.
 *
 * Le code part par e-mail (MailService : Brevo en production).
 * Il n'est JAMAIS renvoyé dans la réponse de l'API, sauf si
 * CTECH_EXPOSE_CODES=true (tests en local uniquement).
 */
class VerificationCodeService
{
    public function __construct(private readonly MailService $mail) {}

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

        // L'échec d'envoi est journalisé par MailService, sans rien révéler au client.
        $this->mail->sendView(
            $user->email,
            $user->fullName(),
            $purpose === CodePurpose::EmailVerification
                ? 'C-Tech Tasks : votre code de confirmation'
                : 'C-Tech Tasks : réinitialisation du mot de passe',
            'mail.verification-code',
            ['user' => $user, 'code' => $code, 'purpose' => $purpose],
        );

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

    /**
     * Renvoyer le code dans la réponse ? Uniquement si CTECH_EXPOSE_CODES=true
     * ET hors production : pratique pour Postman en local, jamais en ligne.
     */
    public static function exposeInResponse(): bool
    {
        return (bool) config('services.ctech.expose_codes') && ! app()->environment('production');
    }
}
