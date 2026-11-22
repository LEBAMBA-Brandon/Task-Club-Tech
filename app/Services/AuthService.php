<?php

namespace App\Services;

use App\Enums\CodePurpose;
use App\Enums\Position;
use App\Enums\UserStatus;
use App\Models\User;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Hash;
use Illuminate\Validation\ValidationException;

/**
 * Logique d'authentification : inscription, vérification e-mail,
 * connexion (jeton Sanctum de 7 semaines), mot de passe oublié.
 */
class AuthService
{
    /** Durée de vie des jetons, demandée dans le cahier des charges. */
    public const TOKEN_LIFETIME_WEEKS = 7;

    public function __construct(private readonly VerificationCodeService $codes) {}

    /**
     * Crée le compte (statut pending_verification) et envoie le code e-mail.
     *
     * @return array{user: User, code: string}
     */
    public function register(array $data): array
    {
        $user = DB::transaction(fn () => User::create([
            'first_name' => $data['first_name'],
            'last_name' => $data['last_name'],
            'email' => mb_strtolower($data['email']),
            'password' => $data['password'],
            'department_id' => $data['department_id'],
            'position' => Position::from($data['position']),
            'status' => UserStatus::PendingVerification,
            'terms_accepted_at' => now(),
        ]));

        $code = $this->codes->issue($user, CodePurpose::EmailVerification);

        return ['user' => $user, 'code' => $code];
    }

    /** Valide le code reçu par e-mail : le compte passe « en attente de validation ». */
    public function verifyEmail(string $email, string $code): User
    {
        $user = User::where('email', mb_strtolower($email))->first();

        if (! $user || $user->status !== UserStatus::PendingVerification
            || ! $this->codes->verify($user, CodePurpose::EmailVerification, $code)) {
            throw ValidationException::withMessages(['code' => 'Code invalide ou expiré.']);
        }

        $user->forceFill([
            'email_verified_at' => now(),
            'status' => UserStatus::PendingApproval,
        ])->save();

        return $user;
    }

    /** Renvoie un code de vérification (réponse identique que le compte existe ou non). */
    public function resendVerification(string $email): ?string
    {
        $user = User::where('email', mb_strtolower($email))->first();

        if ($user && $user->status === UserStatus::PendingVerification) {
            return $this->codes->issue($user, CodePurpose::EmailVerification);
        }

        return null;
    }

    /**
     * Connexion e-mail + mot de passe.
     *
     * @return array{user: User, token: string, expires_at: \Illuminate\Support\Carbon}
     */
    public function login(string $email, string $password, string $deviceName): array
    {
        $user = User::where('email', mb_strtolower($email))->first();

        // Message volontairement générique : on ne révèle pas si l'e-mail existe.
        if (! $user || ! Hash::check($password, $user->password)) {
            throw ValidationException::withMessages(['email' => 'Identifiants incorrects.']);
        }

        match ($user->status) {
            UserStatus::PendingVerification => throw new AccountStateException('EMAIL_NOT_VERIFIED', 'Adresse e-mail non confirmée. Saisissez le code reçu par e-mail.'),
            UserStatus::PendingApproval => throw new AccountStateException('ACCOUNT_PENDING', 'Votre compte attend la validation du bureau.'),
            UserStatus::Rejected => throw new AccountStateException('ACCOUNT_REJECTED', 'Votre demande d\'inscription a été refusée.'),
            UserStatus::Suspended => throw new AccountStateException('ACCOUNT_SUSPENDED', 'Votre compte est suspendu.'),
            UserStatus::Active => null,
        };

        $expiresAt = now()->addWeeks(self::TOKEN_LIFETIME_WEEKS);
        $token = $user->createToken(mb_substr($deviceName, 0, 100), ['*'], $expiresAt)->plainTextToken;

        return ['user' => $user, 'token' => $token, 'expires_at' => $expiresAt];
    }

    /** Envoie un code de réinitialisation si le compte existe (réponse toujours identique). */
    public function forgotPassword(string $email): ?string
    {
        $user = User::where('email', mb_strtolower($email))->first();

        return $user ? $this->codes->issue($user, CodePurpose::PasswordReset) : null;
    }

    /** Change le mot de passe et révoque toutes les sessions ouvertes. */
    public function resetPassword(string $email, string $code, string $password): void
    {
        $user = User::where('email', mb_strtolower($email))->first();

        if (! $user || ! $this->codes->verify($user, CodePurpose::PasswordReset, $code)) {
            throw ValidationException::withMessages(['code' => 'Code invalide ou expiré.']);
        }

        DB::transaction(function () use ($user, $password) {
            $user->forceFill(['password' => $password])->save();
            $user->tokens()->delete();
        });
    }

    /**
     * Change le mot de passe d'un utilisateur connecté.
     * Les autres appareils sont déconnectés ; l'appareil courant reste connecté.
     */
    public function changePassword(User $user, string $current, string $new, ?int $keepTokenId): void
    {
        if (! Hash::check($current, $user->password)) {
            throw ValidationException::withMessages(['current_password' => 'Mot de passe actuel incorrect.']);
        }

        DB::transaction(function () use ($user, $new, $keepTokenId) {
            $user->forceFill(['password' => $new])->save();
            $user->tokens()->when($keepTokenId, fn ($q) => $q->where('id', '!=', $keepTokenId))->delete();
        });
    }
}
