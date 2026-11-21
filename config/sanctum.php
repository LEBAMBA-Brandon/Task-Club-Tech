<?php

/*
| Configuration Laravel Sanctum.
| Les jetons expirent au bout de 7 semaines (7 × 7 × 24 × 60 = 70 560 minutes).
| L'expiration est aussi posée sur chaque jeton à sa création (AuthService).
*/
return [
    'stateful' => [],
    'guard' => ['web'],
    'expiration' => 70560,
    'token_prefix' => env('SANCTUM_TOKEN_PREFIX', 'ctech_'),
    'middleware' => [
        'authenticate_session' => Laravel\Sanctum\Http\Middleware\AuthenticateSession::class,
        'encrypt_cookies' => Illuminate\Cookie\Middleware\EncryptCookies::class,
        'validate_csrf_token' => Illuminate\Foundation\Http\Middleware\ValidateCsrfToken::class,
    ],
];
