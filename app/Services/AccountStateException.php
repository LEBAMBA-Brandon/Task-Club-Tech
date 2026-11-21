<?php

namespace App\Services;

use Illuminate\Http\JsonResponse;
use RuntimeException;

/**
 * Levée quand un compte existe mais ne peut pas encore se connecter
 * (e-mail non confirmé, en attente de validation, refusé, suspendu).
 * L'application Flutter lit le champ « code » pour afficher le bon écran.
 */
class AccountStateException extends RuntimeException
{
    public function __construct(public readonly string $errorCode, string $message)
    {
        parent::__construct($message);
    }

    public function render(): JsonResponse
    {
        return response()->json(['message' => $this->getMessage(), 'code' => $this->errorCode], 403);
    }
}
