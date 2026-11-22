<?php

namespace App\Services;

use Illuminate\Http\JsonResponse;
use RuntimeException;

/**
 * Levée quand un compte ne peut pas (encore) se connecter :
 * e-mail non confirmé, en attente de validation, refusé, suspendu,
 * ou profil à compléter après une connexion Google / GitHub.
 * L'application Flutter lit le champ « code » pour afficher le bon écran ;
 * « data » transporte des informations utiles (ex. nom pré-rempli).
 */
class AccountStateException extends RuntimeException
{
    public function __construct(
        public readonly string $errorCode,
        string $message,
        public readonly array $data = [],
        public readonly int $status = 403,
    ) {
        parent::__construct($message);
    }

    public function render(): JsonResponse
    {
        return response()->json(array_filter([
            'message' => $this->getMessage(),
            'code' => $this->errorCode,
            'data' => $this->data ?: null,
        ]), $this->status);
    }
}
