<?php

namespace App\Enums;

/** Usage d'un code à 6 chiffres envoyé par e-mail. */
enum CodePurpose: string
{
    case EmailVerification = 'email_verification';
    case PasswordReset = 'password_reset';
}
