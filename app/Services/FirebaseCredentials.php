<?php

namespace App\Services;

/**
 * Lit le compte de service Firebase (clé privée Google) depuis :
 *  1. la variable FIREBASE_CREDENTIALS_JSON : contenu du fichier JSON, brut ou encodé en base64
 *     (méthode recommandée sur Railway, où l'on ne dépose pas de fichier) ;
 *  2. sinon le fichier indiqué par FIREBASE_CREDENTIALS (en local).
 *
 * Ce fichier est secret : il ne doit jamais être envoyé sur GitHub.
 */
class FirebaseCredentials
{
    private ?array $cache = null;

    /** @return array<string,mixed>|null */
    public function get(): ?array
    {
        if ($this->cache !== null) {
            return $this->cache;
        }

        $raw = (string) config('services.firebase.credentials_json');
        if ($raw !== '') {
            $json = str_starts_with(ltrim($raw), '{') ? $raw : base64_decode($raw, true);

            return $this->cache = $this->decode($json ?: null);
        }

        $path = $this->path();

        return $this->cache = is_readable($path) ? $this->decode(file_get_contents($path)) : null;
    }

    public function projectId(): ?string
    {
        return config('services.firebase.project_id') ?: ($this->get()['project_id'] ?? null);
    }

    private function path(): string
    {
        $path = (string) config('services.firebase.credentials');

        return str_starts_with($path, '/') || preg_match('/^[A-Za-z]:[\\\\\/]/', $path) ? $path : base_path($path);
    }

    private function decode(?string $json): ?array
    {
        if (! $json) {
            return null;
        }
        $data = json_decode($json, true);

        return is_array($data) && isset($data['client_email'], $data['private_key']) ? $data : null;
    }
}
