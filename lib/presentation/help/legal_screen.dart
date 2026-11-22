import 'package:flutter/material.dart';

import '../../core/utils/responsive.dart';
import 'legal_texts.dart';

/// Affiche un texte en sections : conditions d'utilisation ou politique de confidentialité.
class LegalScreen extends StatelessWidget {
  const LegalScreen({super.key, required this.title, required this.sections});

  factory LegalScreen.terms() => const LegalScreen(title: 'Conditions d\'utilisation', sections: LegalTexts.terms);
  factory LegalScreen.privacy() =>
      const LegalScreen(title: 'Politique de confidentialité', sections: LegalTexts.privacy);

  final String title;
  final List<(String, String)> sections;

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6);
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: MaxWidth(
        maxWidth: 720,
        child: ListView(padding: const EdgeInsets.fromLTRB(20, 4, 20, 32), children: [
          Text('Mise à jour : ${LegalTexts.lastUpdate}', style: TextStyle(color: muted, fontSize: 12)),
          const SizedBox(height: 12),
          for (final (i, (heading, body)) in sections.indexed) ...[
            Text('${i + 1}. $heading',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            Text(body, style: const TextStyle(height: 1.55)),
            const SizedBox(height: 18),
          ],
        ]),
      ),
    );
  }
}
