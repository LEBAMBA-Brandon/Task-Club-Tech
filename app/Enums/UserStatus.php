<?php

namespace App\Enums;

/**
 * Cycle de vie d'un compte :
 * pending_verification -> (code e-mail validé) -> pending_approval
 * -> (validé par la présidence ou le responsable) -> active | rejected
 */
enum UserStatus: string
{
    case PendingVerification = 'pending_verification';
    case PendingApproval = 'pending_approval';
    case Active = 'active';
    case Rejected = 'rejected';
    case Suspended = 'suspended';
}
