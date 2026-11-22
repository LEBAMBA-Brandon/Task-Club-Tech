<?php

namespace App\Console\Commands;

use App\Services\MailService;
use Illuminate\Console\Command;
use Illuminate\Support\Facades\Http;

/**
 * Diagnostic de l'envoi d'e-mails (à lancer dans le terminal Railway) :
 *
 *   php artisan ctech:mail-test ton.adresse@gmail.com
 *
 * Affiche la configuration utilisée et la réponse exacte de Brevo en cas de refus
 * (clé invalide, expéditeur non vérifié, quota atteint...).
 */
class MailTestCommand extends Command
{
    protected $signature = 'ctech:mail-test {email}';

    protected $description = 'Envoie un e-mail de test et affiche le diagnostic Brevo';

    public function handle(MailService $mail): int
    {
        $from = config('mail.from.address');
        $this->line('Expéditeur (MAIL_FROM_ADDRESS) : '.$from);
        $this->line('Clé Brevo (BREVO_API_KEY)      : '.($mail->usesBrevo() ? 'présente' : 'ABSENTE'));

        if (! $mail->usesBrevo()) {
            $this->error('Sans BREVO_API_KEY, les e-mails ne partent pas depuis Railway (SMTP bloqué).');

            return self::FAILURE;
        }
        if (! $from || str_ends_with($from, 'example.com')) {
            $this->error('MAIL_FROM_ADDRESS doit être une adresse ajoutée et vérifiée dans Brevo (menu Expéditeurs).');

            return self::FAILURE;
        }

        // Appel direct pour afficher la réponse brute de Brevo.
        $response = Http::withHeaders(['api-key' => config('services.brevo.key')])->acceptJson()->timeout(15)
            ->post('https://api.brevo.com/v3/smtp/email', [
                'sender' => ['email' => $from, 'name' => config('mail.from.name')],
                'to' => [['email' => $this->argument('email')]],
                'subject' => 'C-Tech Tasks : e-mail de test',
                'htmlContent' => '<p>Si vous lisez ceci, l\'envoi d\'e-mails fonctionne.</p>',
            ]);

        if ($response->successful()) {
            $this->info('E-mail accepté par Brevo. Vérifiez la boîte de réception (et les spams).');

            return self::SUCCESS;
        }

        $this->error('Brevo a refusé l\'envoi ('.$response->status().') : '.$response->body());

        return self::FAILURE;
    }
}
