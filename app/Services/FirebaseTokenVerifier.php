<?php

namespace App\Services;

use Illuminate\Support\Facades\Cache;
use Illuminate\Support\Facades\Http;
use Illuminate\Validation\ValidationException;

/**
 * Vérifie un « ID token » Firebase Authentication (connexion Google, GitHub...).
 *
 * L'application se connecte d'abord à Firebase avec Google ou GitHub, puis envoie
 * à l'API le jeton que Firebase lui a donné. On vérifie ici, sans bibliothèque :
 *  - la signature RS256 avec les certificats publics de Google ;
 *  - l'émetteur (iss) et le destinataire (aud) = notre projet Firebase ;
 *  - les dates (exp, iat) ;
 *  - la présence d'une adresse e-mail.
 * Doc : https://firebase.google.com/docs/auth/admin/verify-id-tokens
 */
class FirebaseTokenVerifier
{
    private const CERTS_URL = 'https://www.googleapis.com/robot/v1/metadata/x509/securetoken@system.gserviceaccount.com';

    public function __construct(private readonly FirebaseCredentials $credentials) {}

    /**
     * @return array{uid:string,email:string,name:?string,provider:string,email_verified:bool}
     */
    public function verify(string $idToken): array
    {
        $projectId = $this->credentials->projectId();
        $parts = explode('.', $idToken);
        if (! $projectId || count($parts) !== 3) {
            $this->fail();
        }

        [$h, $p, $sig] = $parts;
        $header = json_decode($this->b64($h), true);
        $payload = json_decode($this->b64($p), true);
        if (! is_array($header) || ! is_array($payload) || ($header['alg'] ?? '') !== 'RS256') {
            $this->fail();
        }

        $cert = $this->certificates()[$header['kid'] ?? ''] ?? null;
        if (! $cert || openssl_verify("$h.$p", $this->b64($sig), $cert, OPENSSL_ALGO_SHA256) !== 1) {
            $this->fail();
        }

        $now = time();
        $valid = ($payload['aud'] ?? null) === $projectId
            && ($payload['iss'] ?? null) === 'https://securetoken.google.com/'.$projectId
            && ($payload['exp'] ?? 0) > $now
            && ($payload['iat'] ?? PHP_INT_MAX) <= $now + 60
            && ! empty($payload['sub'])
            && ! empty($payload['email']);
        if (! $valid) {
            $this->fail();
        }

        return [
            'uid' => $payload['sub'],
            'email' => mb_strtolower($payload['email']),
            'name' => $payload['name'] ?? null,
            'provider' => $payload['firebase']['sign_in_provider'] ?? 'unknown',
            'email_verified' => (bool) ($payload['email_verified'] ?? false),
        ];
    }

    /** Certificats publics de Google, mis en cache 1 heure. */
    private function certificates(): array
    {
        return Cache::remember('firebase_auth_certs', now()->addHour(), fn () => Http::timeout(10)->get(self::CERTS_URL)->throw()->json());
    }

    private function b64(string $value): string
    {
        return (string) base64_decode(strtr($value, '-_', '+/').str_repeat('=', (4 - strlen($value) % 4) % 4));
    }

    private function fail(): never
    {
        throw ValidationException::withMessages(['id_token' => 'Connexion refusée : jeton invalide ou expiré. Réessayez.']);
    }
}
