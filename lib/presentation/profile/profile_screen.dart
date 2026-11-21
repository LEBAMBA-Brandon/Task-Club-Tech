import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/config/app_config.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/responsive.dart';
import '../../providers/auth_provider.dart';
import '../../providers/data_providers.dart';
import '../common/common_widgets.dart';

/// Profil, choix du thème (clair / sombre / système) et déconnexion.
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final themeMode = ref.watch(themeModeProvider);
    if (user == null) return const SizedBox.shrink();

    return MaxWidth(
      maxWidth: 600,
      child: ListView(padding: const EdgeInsets.all(16), children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(children: [
              InitialsAvatar(user.initials, radius: 36),
              const SizedBox(height: 12),
              Text(user.fullName, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
              const SizedBox(height: 4),
              Text('${user.positionLabel} · ${user.department?.name ?? ''}',
                  style: const TextStyle(color: AppColors.violetLight, fontWeight: FontWeight.w600)),
              const SizedBox(height: 4),
              Text(user.email),
            ]),
          ),
        ),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Thème', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 10),
              SegmentedButton<ThemeMode>(
                segments: const [
                  ButtonSegment(value: ThemeMode.system, label: Text('Système'), icon: Icon(Icons.brightness_auto)),
                  ButtonSegment(value: ThemeMode.light, label: Text('Clair'), icon: Icon(Icons.light_mode)),
                  ButtonSegment(value: ThemeMode.dark, label: Text('Sombre'), icon: Icon(Icons.dark_mode)),
                ],
                selected: {themeMode},
                onSelectionChanged: (s) => ref.read(themeModeProvider.notifier).set(s.first),
              ),
            ]),
          ),
        ),
        const SizedBox(height: 16),
        OutlinedButton.icon(
          style: OutlinedButton.styleFrom(foregroundColor: AppColors.error, minimumSize: const Size(0, 50)),
          onPressed: () => ref.read(authControllerProvider.notifier).signOut(),
          icon: const Icon(Icons.logout),
          label: const Text('Se déconnecter'),
        ),
        const SizedBox(height: 24),
        Center(
          child: Text('${AppConfig.appName} · ${AppConfig.clubName}',
              style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5), fontSize: 12)),
        ),
      ]),
    );
  }
}
