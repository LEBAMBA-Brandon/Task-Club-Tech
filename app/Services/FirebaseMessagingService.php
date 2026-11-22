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
 * Configuration : FIREBASE_PROJECT_ID + FIREBASE_CREDENTIALS_JSON (Railway)
 * ou FIREBASE_CREDENTIALS (chemin du fichier, en local). Voir FirebaseCredentials.
 * Si Firebase n'est pas configuré, l'envoi est simplement ignoré (journalisé).
 */
class FirebaseMessagingService
{
    private const SCOPE = 'https://www.googleapis.com/auth/firebase.messaging';

    public function __construct(private readonly FirebaseCredentials $credentials) {}

    public function isConfigured(): bool
    {
        return $this->credentials->get() !== null && $this->credentials->projectId() !== null;
    }

    /**
     * Notifie plusieurs utilisateurs (ceux sans jeton de téléphone sont ignorés).
     *
     * @param  iterable<User>  $users
     * @param  array<string,string>  $data
     */
    public function sendToUsers(iterable $users, string $title, string $body, array $data = []): void
    {
        foreach ($users as $user) {
            $this->sendToUser($user, $title, $body, $data);
        }
    }

    /**
     * Message « silencieux » de synchronisation (aucune notification affichée) :
     * l'application, si elle est ouverte, recharge discrètement l'écran concerné.
     * C'est ce qui donne l'effet « temps réel ».
     *
     * @param  iterable<User>  $users
     * @param  string  $scope  tasks | comments | approvals | chat
     * @param  array<string,string>  $data
     */
    public function sync(iterable $users, string $scope, array $data = []): void
    {
        foreach ($users as $user) {
            $this->sendToUser($user, null, null, ['type' => 'sync', 'scope' => $scope] + $data);
        }
    }

    /**
     * @param  ?string  $title  null = message de données seul (pas de bannière)
     * @param  array<string,string>  $data  données transmises à l'application (type, task_id, conversation_id...)
     */
    public function sendToUser(User $user, ?string $title, ?string $body, array $data = []): void
    {
        if (! $user->fcm_token) {
            return;
        }
        if (! $this->isConfigured()) {
            Log::debug('Firebase non configuré : notification ignorée', ['user' => $user->id, 'title' => $title]);

            return;
        }

        try {
            $response = Http::withToken($this->accessToken())
                ->timeout(10)
                ->post(sprintf('https://fcm.googleapis.com/v1/projects/%s/messages:send', $this->credentials->projectId()), [
                    'message' => $this->buildMessage($user->fcm_token, $title, $body, $data),
                ]);
        } catch (\Throwable $e) {
            Log::warning('FCM injoignable', ['error' => $e->getMessage()]);

            return;
        }

        if ($response->failed()) {
            $status = $response->json('error.details.0.errorCode') ?? $response->json('error.status');
            // Jeton périmé (application désinstallée...) : on l'efface.
            if (in_array($status, ['UNREGISTERED', 'INVALID_ARGUMENT'], true)) {
                $user->forceFill(['fcm_token' => null])->save();
            }
            Log::warning('Échec FCM', ['user' => $user->id, 'status' => $response->status(), 'error' => $status]);
        }
    }

    /** Message FCM : avec bannière si un titre est fourni, sinon données seules. */
    private function buildMessage(string $token, ?string $title, ?string $body, array $data): array
    {
        $message = [
            'token' => $token,
            'data' => array_map('strval', $data),
            'android' => ['priority' => 'high'],
        ];
        if ($title !== null) {
            $message['notification'] = ['title' => $title, 'body' => mb_strimwidth((string) $body, 0, 180, '…')];
            $message['android']['notification'] = ['channel_id' => 'ctech_tasks'];
        }

        return $message;
    }

    /** Jeton OAuth2 Google, mis en cache 50 minutes. */
    private function accessToken(): string
    {
        return Cache::remember('firebase_access_token', now()->addMinutes(50), function () {
            $credentials = $this->credentials->get();
            $tokenUri = $credentials['token_uri'] ?? 'https://oauth2.googleapis.com/token';

            $now = time();
            $segments = [
                $this->base64Url(json_encode(['alg' => 'RS256', 'typ' => 'JWT'])),
                $this->base64Url(json_encode([
                    'iss' => $credentials['client_email'],
                    'scope' => self::SCOPE,
                    'aud' => $tokenUri,
                    'iat' => $now,
                    'exp' => $now + 3600,
                ])),
            ];
            openssl_sign(implode('.', $segments), $signature, $credentials['private_key'], OPENSSL_ALGO_SHA256);
            $segments[] = $this->base64Url($signature);

            return Http::asForm()->timeout(10)->post($tokenUri, [
                'grant_type' => 'urn:ietf:params:oauth:grant-type:jwt-bearer',
                'assertion' => implode('.', $segments),
            ])->throw()->json('access_token');
        });
    }

    private function base64Url(string $value): string
    {
        return rtrim(strtr(base64_encode($value), '+/', '-_'), '=');
    }
}
