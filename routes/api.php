<?php

use App\Http\Controllers\Api\V1\ApprovalController;
use App\Http\Controllers\Api\V1\AuthController;
use App\Http\Controllers\Api\V1\CommentController;
use App\Http\Controllers\Api\V1\DepartmentController;
use App\Http\Controllers\Api\V1\MetaController;
use App\Http\Controllers\Api\V1\TaskController;
use Illuminate\Support\Facades\Route;

/*
|--------------------------------------------------------------------------
| API C-Tech Tasks — version 1 (préfixe : /api/v1)
|--------------------------------------------------------------------------
| Public   : méta, inscription, code e-mail, connexion, mot de passe oublié
| Protégé  : auth:sanctum (jeton Bearer 7 semaines) + compte actif
*/

Route::prefix('v1')->group(function () {
    Route::get('meta', MetaController::class)->middleware('throttle:api');

    // ----- Authentification (limitée à 5 requêtes / minute / IP + e-mail)
    Route::prefix('auth')->middleware('throttle:auth')->group(function () {
        Route::post('register', [AuthController::class, 'register']);
        Route::post('verify-email', [AuthController::class, 'verifyEmail']);
        Route::post('resend-code', [AuthController::class, 'resendCode']);
        Route::post('login', [AuthController::class, 'login']);
        Route::post('forgot-password', [AuthController::class, 'forgotPassword']);
        Route::post('reset-password', [AuthController::class, 'resetPassword']);
    });

    // ----- Routes protégées
    Route::middleware(['auth:sanctum', 'active', 'throttle:api'])->group(function () {
        Route::get('auth/me', [AuthController::class, 'me']);
        Route::post('auth/logout', [AuthController::class, 'logout']);
        Route::put('auth/fcm-token', [AuthController::class, 'updateFcmToken']);

        Route::get('departments/{department}/members', [DepartmentController::class, 'members']);

        Route::post('tasks/delivered', [TaskController::class, 'delivered']);
        Route::get('tasks', [TaskController::class, 'index']);
        Route::post('tasks', [TaskController::class, 'store']);
        Route::get('tasks/{task}', [TaskController::class, 'show']);
        Route::delete('tasks/{task}', [TaskController::class, 'destroy']);
        Route::post('tasks/{task}/done', [TaskController::class, 'markDone']);
        Route::delete('tasks/{task}/done', [TaskController::class, 'unmarkDone']);
        Route::get('tasks/{task}/comments', [CommentController::class, 'index']);
        Route::post('tasks/{task}/comments', [CommentController::class, 'store']);

        Route::get('approvals', [ApprovalController::class, 'index']);
        Route::post('approvals/{user}/approve', [ApprovalController::class, 'approve']);
        Route::post('approvals/{user}/reject', [ApprovalController::class, 'reject']);
    });
});
