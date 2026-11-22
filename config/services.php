<?php

return [

    'postmark' => [
        'key' => env('POSTMARK_API_KEY'),
    ],

    'resend' => [
        'key' => env('RESEND_API_KEY'),
    ],

    'ses' => [
        'key' => env('AWS_ACCESS_KEY_ID'),
        'secret' => env('AWS_SECRET_ACCESS_KEY'),
        'region' => env('AWS_DEFAULT_REGION', 'us-east-1'),
    ],

    'slack' => [
        'notifications' => [
            'bot_user_oauth_token' => env('SLACK_BOT_USER_OAUTH_TOKEN'),
            'channel' => env('SLACK_BOT_USER_DEFAULT_CHANNEL'),
        ],
    ],

    /*
    | Firebase Cloud Messaging (notifications push Android).
    | FIREBASE_CREDENTIALS : chemin du fichier JSON du compte de service
    | (Console Firebase > Paramètres du projet > Comptes de service > Générer une clé).
    | Ne jamais versionner ce fichier.
    */
    'firebase' => [
        'project_id' => env('FIREBASE_PROJECT_ID'),
        // En local : chemin du fichier JSON du compte de service.
        'credentials' => env('FIREBASE_CREDENTIALS', 'storage/app/private/firebase-service-account.json'),
        // Sur Railway : contenu du fichier JSON (brut ou base64) dans une variable.
        'credentials_json' => env('FIREBASE_CREDENTIALS_JSON'),
        // Adresse de la version web (https) ouverte quand on clique sur une notification web.
        'web_app_url' => env('WEB_APP_URL'),
    ],

    /*
    | Brevo : envoi des e-mails par API HTTPS (Railway bloque le SMTP).
    | Créer la clé dans Brevo > SMTP & API > Clés API.
    */
    'brevo' => [
        'key' => env('BREVO_API_KEY'),
    ],

    'ctech' => [
        // true = le code à 6 chiffres est aussi renvoyé par l'API (tests locaux uniquement).
        'expose_codes' => env('CTECH_EXPOSE_CODES', false),
    ],

];
