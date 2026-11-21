<?php

namespace Database\Seeders;

use App\Models\Department;
use Illuminate\Database\Seeder;

/** Les 8 départements du Club C-Tech. */
class DepartmentSeeder extends Seeder
{
    public const DEPARTMENTS = [
        'recherche-developpement' => 'Recherche et développement',
        'communication' => 'Communication',
        'intendance' => 'Intendance',
        'zone-51' => 'Zone 51',
        'presidence' => 'Présidence',
        'secretariat' => 'Secrétariat',
        'logistique' => 'Logistique',
        'bureau-executif' => 'Bureau exécutif',
    ];

    public function run(): void
    {
        foreach (self::DEPARTMENTS as $slug => $name) {
            Department::updateOrCreate(['slug' => $slug], ['name' => $name]);
        }
    }
}
