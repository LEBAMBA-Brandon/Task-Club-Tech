<?php

namespace App\Enums;

/**
 * Postes possibles d'un membre du club.
 *
 * Règle métier :
 *  - département « presidence »  => president | vice_president
 *  - tous les autres départements => responsable | membre
 *
 * Unicité : un seul président, un seul vice-président,
 * un seul responsable par département (comptes non rejetés).
 */
enum Position: string
{
    case President = 'president';
    case VicePresident = 'vice_president';
    case Responsable = 'responsable';
    case Membre = 'membre';

    /** Libellé affiché à l'utilisateur. */
    public function label(): string
    {
        return match ($this) {
            self::President => 'Président',
            self::VicePresident => 'Vice-président',
            self::Responsable => 'Responsable',
            self::Membre => 'Membre',
        };
    }

    /** Postes autorisés pour un département donné (par son slug). */
    public static function allowedFor(string $departmentSlug): array
    {
        return $departmentSlug === 'presidence'
            ? [self::President, self::VicePresident]
            : [self::Responsable, self::Membre];
    }

    /** Postes qui ne peuvent être occupés que par une seule personne (dans le club ou le département). */
    public function isUnique(): bool
    {
        return $this !== self::Membre;
    }

    /** La présidence (président + vice-président) a des droits étendus. */
    public function isPresidency(): bool
    {
        return in_array($this, [self::President, self::VicePresident], true);
    }
}
