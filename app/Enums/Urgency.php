<?php

namespace App\Enums;

/**
 * Niveaux d'urgence d'une tâche, du plus flexible au plus pressant :
 * vert -> bleu -> jaune -> rouge.
 */
enum Urgency: string
{
    case Green = 'green';
    case Blue = 'blue';
    case Yellow = 'yellow';
    case Red = 'red';

    public function label(): string
    {
        return match ($this) {
            self::Green => 'Flexible',
            self::Blue => 'Normale',
            self::Yellow => 'Importante',
            self::Red => 'Urgente',
        };
    }

    /** Poids pour trier du plus pressant au plus flexible. */
    public function weight(): int
    {
        return match ($this) {
            self::Green => 1,
            self::Blue => 2,
            self::Yellow => 3,
            self::Red => 4,
        };
    }
}
