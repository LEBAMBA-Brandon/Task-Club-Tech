<?php

namespace App\Mail;

use App\Enums\CodePurpose;
use App\Models\User;
use Illuminate\Bus\Queueable;
use Illuminate\Mail\Mailable;
use Illuminate\Mail\Mailables\Content;
use Illuminate\Mail\Mailables\Envelope;
use Illuminate\Queue\SerializesModels;

/** E-mail contenant le code de vérification / réinitialisation. */
class VerificationCodeMail extends Mailable
{
    use Queueable, SerializesModels;

    public function __construct(
        public User $user,
        public string $code,
        public CodePurpose $purpose,
    ) {}

    public function envelope(): Envelope
    {
        return new Envelope(
            subject: $this->purpose === CodePurpose::EmailVerification
                ? 'C-Tech Tasks : confirmez votre adresse e-mail'
                : 'C-Tech Tasks : réinitialisation du mot de passe',
        );
    }

    public function content(): Content
    {
        return new Content(view: 'mail.verification-code');
    }
}
