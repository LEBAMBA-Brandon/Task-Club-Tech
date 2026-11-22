import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/responsive.dart';
import 'legal_texts.dart';
import 'tutorial_screen.dart';

/// Aide : relancer le tutoriel + questions fréquentes.
class HelpScreen extends StatelessWidget {
  const HelpScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Aide')),
      body: MaxWidth(
        maxWidth: 720,
        child: ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 32), children: [
          Card(
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              leading: const CircleAvatar(
                backgroundColor: AppColors.violet,
                child: Icon(Icons.play_lesson_rounded, color: Colors.white),
              ),
              title: const Text('Revoir le tutoriel', style: TextStyle(fontWeight: FontWeight.w700)),
              subtitle: const Text('Les bases de l\'application en 8 écrans'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(fullscreenDialog: true, builder: (_) => const TutorialScreen()),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text('Questions fréquentes', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Card(
            clipBehavior: Clip.antiAlias,
            child: Column(children: [
              for (final (question, answer) in LegalTexts.faq)
                ExpansionTile(
                  title: Text(question, style: const TextStyle(fontWeight: FontWeight.w600)),
                  childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
                  expandedCrossAxisAlignment: CrossAxisAlignment.start,
                  children: [Text(answer, style: const TextStyle(height: 1.5))],
                ),
            ]),
          ),
          const SizedBox(height: 20),
          const Text(
            'Toujours bloqué ? Contactez le bureau du Club-Tech (C-Tech) ou le responsable de votre département.',
            textAlign: TextAlign.center,
          ),
        ]),
      ),
    );
  }
}
