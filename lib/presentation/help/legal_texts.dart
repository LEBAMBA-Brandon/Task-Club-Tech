/// Textes légaux de l'application (à faire relire et valider par le bureau du club).
class LegalTexts {
  LegalTexts._();

  static const lastUpdate = '22 novembre 2026';

  static const terms = <(String, String)>[
    ('Objet',
        'C-Tech Tasks est l\'application interne du Club-Tech (C-Tech) qui permet de rédiger, recevoir et suivre '
            'les tâches confiées aux départements du club.'),
    ('Accès',
        'L\'application est réservée aux membres du club. Chaque compte est personnel : il est créé par le membre '
            'lui-même, confirmé par un code reçu par e-mail, puis validé par le président, le vice-président ou le '
            'responsable du département.'),
    ('Postes',
        'Le poste choisi à l\'inscription doit correspondre à votre rôle réel dans le club. Il n\'existe qu\'un '
            'président, un vice-président et un responsable par département.'),
    ('Bon usage',
        'Les tâches et commentaires doivent concerner uniquement les activités du club et rester respectueux. '
            'Il est interdit de partager son mot de passe ou d\'utiliser le compte d\'un autre membre.'),
    ('Accusés de lecture',
        'Lorsqu\'une tâche vous est adressée, son auteur et la présidence peuvent voir si vous l\'avez reçue, '
            'ouverte et effectuée.'),
    ('Sanctions',
        'Tout usage abusif peut entraîner la suspension ou la suppression du compte par le bureau du club.'),
    ('Évolution',
        'Ces conditions peuvent être modifiées par le bureau. La version à jour est toujours disponible dans '
            'Profil › Informations.'),
  ];

  static const privacy = <(String, String)>[
    ('Données collectées',
        'Nom, prénom, adresse e-mail, département, poste et mot de passe (enregistré de façon chiffrée, '
            'personne ne peut le lire). L\'application enregistre aussi les tâches, commentaires et accusés '
            '(reçu, vu, effectué).'),
    ('Pourquoi',
        'Ces informations servent uniquement à faire fonctionner l\'application : identifier les membres, '
            'envoyer les tâches au bon département et suivre leur avancement.'),
    ('Qui peut les voir',
        'Les membres concernés par une tâche voient le nom et le poste de son auteur. L\'auteur et la présidence '
            'voient les accusés des destinataires. Vos données ne sont jamais vendues ni partagées hors du club.'),
    ('Messagerie',
        'Les messages privés ne sont visibles que par les deux membres concernés ; ceux du groupe d\'un '
            'département, par ses membres. Restez courtois : le bureau peut suspendre un compte en cas d\'abus.'),
    ('Connexion Google',
        'Si vous choisissez cette option, l\'application reçoit seulement votre nom et votre adresse e-mail. '
            'Elle n\'a jamais accès à votre mot de passe Google.'),
    ('Notifications',
        'Si vous les activez, un identifiant technique de votre téléphone est enregistré pour vous envoyer les '
            'nouvelles tâches. Vous pouvez les désactiver à tout moment dans Profil › Compte › Notifications.'),
    ('Sur votre téléphone',
        'Votre session est enregistrée de façon sécurisée et les dernières tâches sont gardées pour la '
            'consultation sans connexion. Tout est effacé à la déconnexion.'),
    ('Durée de conservation',
        'Les données sont conservées tant que vous êtes membre du club. Vous pouvez demander la suppression '
            'de votre compte au bureau.'),
    ('Vos droits',
        'Vous pouvez demander à consulter, corriger ou supprimer vos informations en contactant le bureau '
            'du Club-Tech (C-Tech).'),
  ];

  /// Questions fréquentes de la page d'aide.
  static const faq = <(String, String)>[
    ('Je ne reçois pas le code par e-mail',
        'Vérifiez vos courriers indésirables (spam), puis touchez « Renvoyer le code ». Le code est valable '
            '10 minutes.'),
    ('« Votre compte attend la validation »',
        'C\'est normal après l\'inscription : le président, le vice-président ou le responsable de votre '
            'département doit valider votre compte. Prévenez-le.'),
    ('Comment marquer une tâche comme faite ?',
        'Ouvrez la tâche et touchez le bouton vert « Marquer comme effectuée ». Vous pouvez annuler si besoin.'),
    ('Que veulent dire les coches ?',
        '✓ gris : envoyée · ✓✓ gris : reçue · ✓✓ bleu : vue · ✔ vert : effectuée.'),
    ('Que veulent dire les couleurs ?',
        'Vert : flexible · Bleu : normale · Jaune : importante · Rouge : urgente.'),
    ('Comment écrire à un membre ?',
        'Onglet « Messages » › « Nouveau message », puis cherchez son nom. Le groupe de votre département '
            'est déjà dans la liste.'),
    ('Puis-je m\'inscrire avec Google ?',
        'Oui : sur l\'écran d\'accueil, touchez « Continuer avec Google ». Il restera à choisir votre département '
            'et votre poste, puis à attendre la validation du bureau.'),
    ('Les informations se mettent-elles à jour toutes seules ?',
        'Oui : les nouvelles tâches, coches, messages et demandes apparaissent automatiquement, sans recharger. '
            'Il faut simplement une connexion internet.'),
    ('Je ne reçois pas de notifications',
        'Vérifiez Profil › Compte › Notifications, puis les réglages de notifications de votre téléphone '
            'pour C-Tech Tasks.'),
    ('J\'ai oublié mon mot de passe',
        'Sur l\'écran de connexion, touchez « Oublié ? » : un code vous est envoyé pour en choisir un nouveau.'),
  ];
}
