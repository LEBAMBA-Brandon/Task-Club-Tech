<!DOCTYPE html>
<html lang="fr">
<body style="font-family: Arial, sans-serif; background:#0b0b1a; color:#ffffff; padding:24px;">
    <div style="max-width:480px; margin:auto; background:#15152b; border-radius:16px; padding:32px;">
        <p style="color:#8b5cf6; letter-spacing:2px; font-size:12px; margin:0;">CLUB C-TECH</p>
        <h1 style="font-size:22px;">Bonjour {{ $user->first_name }},</h1>
        <p>
            @if ($purpose === \App\Enums\CodePurpose::EmailVerification)
                Voici votre code pour confirmer votre inscription :
            @else
                Voici votre code pour réinitialiser votre mot de passe :
            @endif
        </p>
        <p style="font-size:34px; letter-spacing:10px; font-weight:bold; color:#60a5fa;">{{ $code }}</p>
        <p style="color:#a1a1c2; font-size:13px;">Ce code expire dans 10 minutes. Si vous n'êtes pas à l'origine de cette demande, ignorez cet e-mail.</p>
    </div>
</body>
</html>
