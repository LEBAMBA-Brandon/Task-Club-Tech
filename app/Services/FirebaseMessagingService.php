<?php

namespace App\Services;

use App\Models\User;
use Illuminate\Support\Facades\Cache;
use Illuminate\Support\Facades\Http;
use Illuminate\Support\Facades\Log;

/**
 * Envoi de notifications push via Firebase Cloud Messaging (API HTTP v1),
 * sans dépendance externe : on signe nous-mêmes le JWT du compte de service.
 *
 * Configuration (.env) :
 *   FIREBASE_PROJECT_ID=mon-projet
 *   FIREBASE_CREDENTIALS=storage/app/private/firebase-service-account.json
 *
 * Si Firebase n'est pas configuré, l'envoi est simplement ignoré (journalisé).
 */
class FirebaseMessagingService
{
    private const SCOPE = 'https://www.googleapis.com/auth/firebase.messaging';

    public function isConfigured(): bool
    {
        return (bool) config('services.firebase.project_id') && is_readable($this->credentialsPath());
    }

    /**
     * @param  array<string,string>  $data  données transmises à l'application (ex. task_id)
     */
    public function sendToUser(User $user, string $title, string $body, array $data = []): void
    {
        if (! $user->fcm_token) {
            return;
        }
        if (! $this->isConfigured()) {
            Log::info('Firebase non configuré : notification ignorée', ['user' => $user->id, 'title' => $title]);

            return;
        }

        $response = Http::withToken($this->accessToken())
            ->timeout(10)
            ->post(sprintf('https://fcm.googleapis.com/v1/projects/%s/messages:send', config('services.firebase.project_id')), [
                'message' => [
                    'token' => $user->fcm_token,
                    'notification' => ['title' => $title, 'body' => $body],
                    'data' => array_map('strval', $data),
                    'android' => [
                        'priority' => 'high',
                        'notification' => ['channel_id' => 'ctech_tasks'],
                    ],
                ],
            ]);

        if ($response->failed()) {
            $status = $response->json('error.details.0.errorCode') ?? $response->json('error.status');
            // Jeton périmé (appli désinstallée...) : on l'efface.
            if (in_array($status, ['UNREGISTERED', 'INVALID_ARGUMENT'], true)) {
                $user->forceFill(['fcm_token' => null])->save();
            }
            Log::warning('Échec FCM', ['user' => $user->id, 'status' => $response->status(), 'error' => $status]);
        }
    }

    /** Jeton OAuth2 Google, mis en cache 50 minutes. */
    private function accessToken(): string
    {
        return Cache::remember('firebase_access_token', now()->addMinutes(50), function () {
            $credentials = json_decode(file_get_contents($this->credentialsPath()), true, flags: JSON_THROW_ON_ERROR);

            $now = time();
            $segments = [
                $this->base64Url(json_encode(['alg' => 'RS256', 'typ' => 'JWT'])),
                $this->base64Url(json_encode([
                    'iss' => $credentials['client_email'],
                    'scope' => self::SCOPE,
                    'aud' => $credentials['token_uri'] ?? 'https://oauth2.googleapis.com/token',
                    'iat' => $now,
                    'exp' => $now + 3600,
                ])),
            ];
            openssl_sign(implode('.', $segments), $signature, $credentials['private_key'], OPENSSL_ALGO_SHA256);
            $segments[] = $this->base64Url($signature);

            return Http::asForm()->timeout(10)->post($credentials['token_uri'] ?? 'https://oauth2.googleapis.com/token', [
                'grant_type' => 'urn:ietf:params:oauth:grant-type:jwt-bearer',
                'assertion' => implode('.', $segments),
            ])->throw()->json('access_token');
        });
    }

    private function credentialsPath(): string
    {
        $path = (string) config('services.firebase.credentials');

        return str_starts_with($path, '/') || preg_match('/^[A-Za-z]:\\\\/', $path) ? $path : base_path($path);
    }

    private function base64Url(string $value): string
    {
        return rtrim(strtr(base64_encode($value), '+/', '-_'), '=');
    }
}
