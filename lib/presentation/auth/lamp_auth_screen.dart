import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/theme/app_colors.dart';
import 'widgets/auth_card.dart';
import 'widgets/desk_lamp.dart';

/// Écran d'accueil reprenant la vidéo de référence :
/// pièce sombre + lampe de bureau. On tire le cordon : la lampe s'allume
/// et la carte de connexion / inscription apparaît dans sa lumière.
/// Toucher l'abat-jour change la couleur (violet, bleu, cyan, lavande).
///
/// Responsive :
///  - smartphone : lampe en haut, carte en dessous (défilement) ;
///  - tablette / desktop : lampe à gauche, carte à droite.
class LampAuthScreen extends StatefulWidget {
  const LampAuthScreen({super.key});

  @override
  State<LampAuthScreen> createState() => _LampAuthScreenState();
}

class _LampAuthScreenState extends State<LampAuthScreen> with SingleTickerProviderStateMixin {
  late final AnimationController _light =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 650));
  int _colorIndex = 0;

  bool get _isOn => _light.status == AnimationStatus.forward || _light.status == AnimationStatus.completed;
  Color get _color => AppColors.lampColors[_colorIndex];

  @override
  void dispose() {
    _light.dispose();
    super.dispose();
  }

  void _toggle() {
    if (_isOn) {
      _light.reverse();
    } else {
      _light.forward();
    }
  }

  void _nextColor() {
    setState(() => _colorIndex = (_colorIndex + 1) % AppColors.lampColors.length);
    if (!_isOn) _light.forward();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF111216),
      body: AnimatedBuilder(
        animation: _light,
        builder: (context, _) {
          // Petit scintillement au moment de l'allumage.
          final t = _light.value;
          final flicker = t > 0 && t < 0.35 ? (0.6 + 0.4 * math.sin(t * 60).abs()) : 1.0;
          final intensity = Curves.easeOut.transform(t) * flicker;

          return LayoutBuilder(builder: (context, constraints) {
            final wide = constraints.maxWidth >= 760;
            return Stack(children: [
              _Ambient(intensity: intensity, color: _color, wide: wide),
              SafeArea(child: wide ? _wideLayout(intensity) : _narrowLayout(intensity, constraints)),
            ]);
          });
        },
      ),
    );
  }

  Widget _lamp(double intensity) => DeskLamp(
        intensity: intensity,
        color: _color,
        onToggle: _toggle,
        onNextColor: _nextColor,
      );

  Widget _card(double intensity) {
    final visible = _light.value;
    return IgnorePointer(
      ignoring: visible < 0.5,
      child: Opacity(
        opacity: Curves.easeIn.transform(visible),
        child: Transform.translate(
          offset: Offset(0, 24 * (1 - visible)),
          child: AuthCard(accent: _color, glow: intensity),
        ),
      ),
    );
  }

  /// Tablette / desktop : lampe à gauche, carte à droite.
  Widget _wideLayout(double intensity) => Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1000),
          child: Row(children: [
            Expanded(
              child: Stack(alignment: Alignment.center, children: [
                SizedBox(height: 460, child: _lamp(intensity)),
                Positioned(bottom: 40, child: _Hint(visible: _light.value < 0.1, color: _color)),
              ]),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 16),
                child: Center(child: _card(intensity)),
              ),
            ),
          ]),
        ),
      );

  /// Smartphone : lampe en haut, carte en dessous.
  Widget _narrowLayout(double intensity, BoxConstraints constraints) {
    final lampHeight = _light.value > 0.5 ? 230.0 : math.min(constraints.maxHeight * 0.62, 420.0);
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 28),
      child: Column(children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeInOut,
          height: lampHeight,
          child: _lamp(intensity),
        ),
        _Hint(visible: _light.value < 0.1, color: _color),
        const SizedBox(height: 8),
        _card(intensity),
      ]),
    );
  }
}

/// Lueur colorée dans la pièce + quelques poussières en suspension.
class _Ambient extends StatelessWidget {
  const _Ambient({required this.intensity, required this.color, required this.wide});
  final double intensity;
  final Color color;
  final bool wide;

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: IgnorePointer(
        child: CustomPaint(painter: _AmbientPainter(intensity, color, wide)),
      ),
    );
  }
}

class _AmbientPainter extends CustomPainter {
  _AmbientPainter(this.intensity, this.color, this.wide);
  final double intensity;
  final Color color;
  final bool wide;

  static final _dust = List.generate(28, (i) {
    final r = math.Random(i * 7 + 3);
    return Offset(r.nextDouble(), r.nextDouble());
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF16171C), Color(0xFF0C0C10)],
        ).createShader(rect),
    );
    if (intensity <= 0) return;
    final center = wide ? Offset(size.width * 0.38, size.height * 0.45) : Offset(size.width * 0.55, size.height * 0.28);
    canvas.drawRect(
      rect,
      Paint()
        ..shader = RadialGradient(
          colors: [color.withValues(alpha: 0.28 * intensity), color.withValues(alpha: 0.06 * intensity), Colors.transparent],
          stops: const [0, 0.45, 1],
        ).createShader(Rect.fromCircle(center: center, radius: size.longestSide * 0.7)),
    );
    final dot = Paint()..color = Colors.white.withValues(alpha: 0.35 * intensity);
    for (final p in _dust) {
      canvas.drawCircle(Offset(p.dx * size.width, p.dy * size.height), 1.1, dot);
    }
  }

  @override
  bool shouldRepaint(covariant _AmbientPainter old) =>
      old.intensity != intensity || old.color != color || old.wide != wide;
}

/// Indication « Tirez le cordon » quand la lampe est éteinte.
class _Hint extends StatelessWidget {
  const _Hint({required this.visible, required this.color});
  final bool visible;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      opacity: visible ? 1 : 0,
      duration: const Duration(milliseconds: 300),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white12),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.south_rounded, size: 14, color: color),
          const SizedBox(width: 6),
          Text('Tirez le cordon pour allumer',
              style: GoogleFonts.manrope(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w600)),
        ]),
      ),
    );
  }
}
