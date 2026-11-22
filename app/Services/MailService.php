<?php

namespace App\Services;

use Illuminate\Support\Facades\Http;
use Illuminate\Support\Facades\Log;
use Illuminate\Support\Facades\Mail;

/**
 * Envoi des e-mails de l'application.
 *
 * Pourquoi pas le SMTP classique ? Railway bloque les ports SMTP sur les offres
 * Free / Hobby. On passe donc par l'API HTTPS de Brevo (300 e-mails / jour gratuits).
 *
 * Configuration (.env ou variables Railway) :
 *   BREVO_API_KEY=xkeysib-...            clé API Brevo (SMTP & API > Clés API)
 *   MAIL_FROM_ADDRESS=club@exemple.com   expéditeur VÉRIFIÉ dans Brevo (Expéditeurs)
 *   MAIL_FROM_NAME="C-Tech Tasks"
 *
 * Sans BREVO_API_KEY, on utilise le mailer Laravel (MAIL_MAILER=log en local :
 * l'e-mail est alors écrit dans storage/logs/laravel.log).
 */
class MailService
{
    public function usesBrevo(): bool
    {
        return (bool) config('services.brevo.key');
    }

    /**
     * Envoie un e-mail HTML. Renvoie false en cas d'échec (journalisé),
     * sans jamais lever d'exception : un e-mail raté ne doit pas casser la requête.
     */
    public function send(string $toEmail, string $toName, string $subject, string $html): bool
    {
        try {
            if ($this->usesBrevo()) {
                $response = Http::withHeaders(['api-key' => config('services.brevo.key')])
                    ->acceptJson()
                    ->timeout(15)
                    ->post('https://api.brevo.com/v3/smtp/email', [
                        'sender' => ['email' => config('mail.from.address'), 'name' => config('mail.from.name')],
                        'to' => [['email' => $toEmail, 'name' => $toName]],
                        'subject' => $subject,
                        'htmlContent' => $html,
                    ]);

                if ($response->failed()) {
                    Log::error('Brevo : envoi refusé', ['status' => $response->status(), 'body' => $response->json()]);

                    return false;
                }

                return true;
            }

            Mail::html($html, fn ($message) => $message->to($toEmail, $toName)->subject($subject));

            return true;
        } catch (\Throwable $e) {
            Log::error('Envoi d\'e-mail impossible', ['to' => $toEmail, 'error' => $e->getMessage()]);

            return false;
        }
    }

    /** Rend une vue Blade d'e-mail puis l'envoie. */
    public function sendView(string $toEmail, string $toName, string $subject, string $view, array $data): bool
    {
        return $this->send($toEmail, $toName, $subject, view($view, $data)->render());
    }
}
