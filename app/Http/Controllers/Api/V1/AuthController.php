<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Http\Requests\Auth\ChangePasswordRequest;
use App\Http\Requests\Auth\EmailRequest;
use App\Http\Requests\Auth\LoginRequest;
use App\Http\Requests\Auth\RegisterRequest;
use App\Http\Requests\Auth\ResetPasswordRequest;
use App\Http\Requests\Auth\SocialLoginRequest;
use App\Http\Requests\Auth\VerifyCodeRequest;
use App\Http\Resources\UserResource;
use App\Services\AuthService;
use App\Services\FirebaseTokenVerifier;
use App\Services\VerificationCodeService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

/**
 * Contrôleur fin : il valide (Form Requests), délègue à AuthService et formate la réponse.
 */
class AuthController extends Controller
{
    public function __construct(private readonly AuthService $auth) {}

    /** POST /auth/register */
    public function register(RegisterRequest $request): JsonResponse
    {
        ['user' => $user, 'code' => $code] = $this->auth->register($request->validated());

        return response()->json($this->withDebugCode([
            'message' => 'Compte créé. Un code de confirmation a été envoyé à '.$user->email.'.',
            'email' => $user->email,
        ], $code), 201);
    }

    /** POST /auth/verify-email */
    public function verifyEmail(VerifyCodeRequest $request): JsonResponse
    {
        $user = $this->auth->verifyEmail($request->input('email'), $request->input('code'));

        return response()->json([
            'message' => 'Adresse confirmée. Votre compte attend maintenant la validation du bureau.',
            'status' => $user->status->value,
        ]);
    }

    /** POST /auth/resend-code */
    public function resendCode(EmailRequest $request): JsonResponse
    {
        $code = $this->auth->resendVerification($request->input('email'));

        return response()->json($this->withDebugCode([
            'message' => 'Si un compte en attente existe, un nouveau code a été envoyé.',
        ], $code));
    }

    /** POST /auth/login */
    public function login(LoginRequest $request): JsonResponse
    {
        $result = $this->auth->login(
            $request->input('email'),
            $request->input('password'),
            $request->input('device_name') ?: 'android',
        );

        return response()->json([
            'token' => $result['token'],
            'token_type' => 'Bearer',
            'expires_at' => $result['expires_at']->toIso8601String(),
            'user' => new UserResource($result['user']->load('department')),
        ]);
    }

    /**
     * POST /auth/social : connexion / inscription avec Google.
     * Réponses : 200 + jeton | 409 PROFILE_REQUIRED | 403 ACCOUNT_PENDING...
     */
    public function social(SocialLoginRequest $request, FirebaseTokenVerifier $verifier): JsonResponse
    {
        $result = $this->auth->social($request->validated(), $verifier);

        return response()->json([
            'token' => $result['token'],
            'token_type' => 'Bearer',
            'expires_at' => $result['expires_at']->toIso8601String(),
            'user' => new UserResource($result['user']->load('department')),
        ]);
    }

    /** POST /auth/forgot-password */
    public function forgotPassword(EmailRequest $request): JsonResponse
    {
        $code = $this->auth->forgotPassword($request->input('email'));

        return response()->json($this->withDebugCode([
            'message' => 'Si cette adresse existe, un code de réinitialisation a été envoyé.',
        ], $code));
    }

    /** POST /auth/reset-password */
    public function resetPassword(ResetPasswordRequest $request): JsonResponse
    {
        $this->auth->resetPassword($request->input('email'), $request->input('code'), $request->input('password'));

        return response()->json(['message' => 'Mot de passe modifié. Vous pouvez vous connecter.']);
    }

    /** GET /auth/me */
    public function me(Request $request): UserResource
    {
        return new UserResource($request->user()->load('department'));
    }

    /** POST /auth/logout : révoque uniquement le jeton de cet appareil. */
    public function logout(Request $request): JsonResponse
    {
        $request->user()->forceFill(['fcm_token' => null])->save();
        $request->user()->currentAccessToken()->delete();

        return response()->json(['message' => 'Déconnecté.']);
    }

    /** PUT /auth/password : changement de mot de passe depuis le profil. */
    public function changePassword(ChangePasswordRequest $request): JsonResponse
    {
        $token = $request->user()->currentAccessToken();
        $this->auth->changePassword(
            $request->user(),
            $request->input('current_password'),
            $request->input('password'),
            is_object($token) && isset($token->id) ? (int) $token->id : null,
        );

        return response()->json(['message' => 'Mot de passe modifié. Vos autres appareils ont été déconnectés.']);
    }

    /** PUT /auth/fcm-token : enregistre le jeton Firebase du téléphone. */
    public function updateFcmToken(Request $request): JsonResponse
    {
        $data = $request->validate(['fcm_token' => ['nullable', 'string', 'max:512']]);
        $request->user()->forceFill(['fcm_token' => $data['fcm_token'] ?? null])->save();

        return response()->json(['message' => 'Jeton de notification enregistré.']);
    }

    /** Ajoute « debug_code » à la réponse en local uniquement (pas de SMTP en développement). */
    private function withDebugCode(array $payload, ?string $code): array
    {
        if ($code && VerificationCodeService::exposeInResponse()) {
            $payload['debug_code'] = $code;
        }

        return $payload;
    }
}
