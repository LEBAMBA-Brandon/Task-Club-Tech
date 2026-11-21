import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/config/app_config.dart';
import 'core/theme/app_theme.dart';
import 'presentation/auth/lamp_auth_screen.dart';
import 'presentation/common/common_widgets.dart';
import 'presentation/home/home_shell.dart';
import 'providers/auth_provider.dart';
import 'providers/data_providers.dart';

/// Racine de l'application : thèmes, langue française et aiguillage selon la session.
class CTechTasksApp extends ConsumerWidget {
  const CTechTasksApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authControllerProvider);

    return MaterialApp(
      title: AppConfig.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: ref.watch(themeModeProvider),
      locale: const Locale('fr', 'FR'),
      supportedLocales: const [Locale('fr', 'FR')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: AnimatedSwitcher(
        duration: const Duration(milliseconds: 400),
        child: switch (auth.status) {
          AuthStatus.unknown => const _Splash(),
          AuthStatus.signedOut => const LampAuthScreen(key: ValueKey('auth')),
          AuthStatus.signedIn => const HomeShell(key: ValueKey('home')),
        },
      ),
    );
  }
}

class _Splash extends StatelessWidget {
  const _Splash();

  @override
  Widget build(BuildContext context) =>
      const Scaffold(backgroundColor: Color(0xFF111216), body: Center(child: AppLogo(size: 96, brightness: Brightness.dark)));
}
