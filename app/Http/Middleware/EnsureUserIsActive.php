<?php

namespace App\Http\Middleware;

use Closure;
use Illuminate\Http\Request;
use Symfony\Component\HttpFoundation\Response;

/**
 * Bloque un compte suspendu ou refusé même s'il possède encore un jeton.
 */
class EnsureUserIsActive
{
    public function handle(Request $request, Closure $next): Response
    {
        $user = $request->user();

        if (! $user || ! $user->isActive()) {
            // Révoque le jeton utilisé (sauf jeton « transitoire » des tests).
            $token = $user?->currentAccessToken();
            if ($token && method_exists($token, 'delete')) {
                $token->delete();
            }

            return response()->json(['message' => 'Compte inactif.', 'code' => 'ACCOUNT_INACTIVE'], 403);
        }

        return $next($request);
    }
}
