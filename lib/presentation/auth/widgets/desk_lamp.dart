import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Lampe de bureau interactive (reprise de la maquette vidéo).
///
/// - Tirer le cordon vers le bas puis relâcher : allume / éteint ([onToggle]).
/// - Toucher l'abat-jour : change la couleur de la lumière ([onNextColor]).
///
/// Tout est dessiné avec un [CustomPainter] dans un repère de 280 × 380
/// mis à l'échelle de la place disponible.
class DeskLamp extends StatefulWidget {
  const DeskLamp({
    super.key,
    required this.intensity,
    required this.color,
    required this.onToggle,
    required this.onNextColor,
  });

  /// 0 = éteinte, 1 = allumée (valeur animée par l'écran parent).
  final double intensity;
  final Color color;
  final VoidCallback onToggle;
  final VoidCallback onNextColor;

  @override
  State<DeskLamp> createState() => _DeskLampState();
}

class _DeskLampState extends State<DeskLamp> with SingleTickerProviderStateMixin {
  static const Size _design = Size(280, 380);
  static const double _maxPull = 70;
  static const double _toggleThreshold = 35;

  late final AnimationController _spring = AnimationController(vsync: this, duration: const Duration(milliseconds: 700))
    ..addListener(() => setState(() => _pull = _releaseFrom * (1 - Curves.elasticOut.transform(_spring.value))));

  double _pull = 0;
  double _releaseFrom = 0;
  bool _dragging = false;

  @override
  void dispose() {
    _spring.dispose();
    super.dispose();
  }

  /// Convertit une position écran en coordonnées du repère de dessin.
  Offset _toDesign(Offset local, Size size) {
    final scale = math.min(size.width / _design.width, size.height / _design.height);
    final dx = (size.width - _design.width * scale) / 2;
    final dy = (size.height - _design.height * scale) / 2;
    return Offset((local.dx - dx) / scale, (local.dy - dy) / scale);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final size = Size(constraints.maxWidth, constraints.maxHeight);
      return Semantics(
        button: true,
        label: widget.intensity > 0.5 ? 'Éteindre la lampe' : 'Allumer la lampe',
        onTap: widget.onToggle,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapUp: (d) {
            final p = _toDesign(d.localPosition, size);
            if ((p - _LampGeometry.knob(_pull)).distance < 28) {
              widget.onToggle(); // un simple toucher sur la poignée fonctionne aussi
            } else if ((p - _LampGeometry.headCenter).distance < 60) {
              widget.onNextColor();
            }
          },
          onVerticalDragStart: (d) {
            final p = _toDesign(d.localPosition, size);
            _dragging = (p - _LampGeometry.knob(_pull)).distance < 40;
            if (_dragging) _spring.stop();
          },
          onVerticalDragUpdate: (d) {
            if (!_dragging) return;
            final scale = math.min(size.width / _design.width, size.height / _design.height);
            setState(() => _pull = (_pull + d.delta.dy / scale).clamp(0.0, _maxPull));
          },
          onVerticalDragEnd: (_) {
            if (!_dragging) return;
            _dragging = false;
            if (_pull > _toggleThreshold) widget.onToggle();
            _releaseFrom = _pull;
            _spring.forward(from: 0);
          },
          child: CustomPaint(
            size: size,
            painter: _LampPainter(intensity: widget.intensity, color: widget.color, pull: _pull),
          ),
        ),
      );
    });
  }
}

/// Points clés de la lampe dans le repère 280 × 380.
class _LampGeometry {
  static const baseCenter = Offset(95, 345);
  static const baseJoint = Offset(95, 330);
  static const elbow = Offset(58, 222);
  static const headCenter = Offset(160, 118); // centre de l'ouverture de l'abat-jour
  static const headAngle = -0.38; // rotation (radians) : l'abat-jour regarde vers le bas à droite
  static const cordLength = 78.0;

  /// Point d'attache du bras supérieur sur l'abat-jour.
  static Offset get headJoint => headCenter + _rotate(const Offset(-38, -46));

  static Offset cordStart() => headCenter + _rotate(const Offset(0, 4));

  static Offset knob(double pull) => cordStart() + Offset(0, cordLength + pull);

  static Offset _rotate(Offset p) {
    final c = math.cos(headAngle), s = math.sin(headAngle);
    return Offset(p.dx * c - p.dy * s, p.dx * s + p.dy * c);
  }
}

class _LampPainter extends CustomPainter {
  _LampPainter({required this.intensity, required this.color, required this.pull});

  final double intensity;
  final Color color;
  final double pull;

  static const _gold = Color(0xFFD4A24C);
  static const _body = Color(0xFF1B1C22);
  static const _bodyLight = Color(0xFF3A3B45);

  @override
  void paint(Canvas canvas, Size size) {
    final scale = math.min(size.width / 280, size.height / 380);
    canvas.save();
    canvas.translate((size.width - 280 * scale) / 2, (size.height - 380 * scale) / 2);
    canvas.scale(scale);

    _paintLightCone(canvas);
    _paintBase(canvas);
    _paintArms(canvas);
    _paintCord(canvas);
    _paintHead(canvas);

    canvas.restore();
  }

  /// Faisceau lumineux qui part de l'abat-jour.
  void _paintLightCone(Canvas canvas) {
    if (intensity <= 0) return;
    final o = _LampGeometry.headCenter;
    final dir = _LampGeometry._rotate(const Offset(0, 1)); // axe de l'ouverture
    final far = o + dir * 420;
    final normal = Offset(-dir.dy, dir.dx);
    final path = Path()
      ..moveTo(o.dx + normal.dx * 50, o.dy + normal.dy * 50)
      ..lineTo(far.dx + normal.dx * 260, far.dy + normal.dy * 260)
      ..lineTo(far.dx - normal.dx * 260, far.dy - normal.dy * 260)
      ..lineTo(o.dx - normal.dx * 50, o.dy - normal.dy * 50)
      ..close();
    canvas.drawPath(
      path,
      Paint()
        ..shader = RadialGradient(
          colors: [color.withValues(alpha: 0.35 * intensity), color.withValues(alpha: 0)],
        ).createShader(Rect.fromCircle(center: o, radius: 430))
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 18),
    );
  }

  void _paintBase(Canvas canvas) {
    final rect = Rect.fromCenter(center: _LampGeometry.baseCenter, width: 130, height: 24);
    canvas.drawOval(rect.shift(const Offset(0, 8)), Paint()..color = Colors.black.withValues(alpha: 0.45)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8));
    canvas.drawOval(
      rect,
      Paint()..shader = const LinearGradient(colors: [_bodyLight, _body]).createShader(rect),
    );
    canvas.drawOval(rect, Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..color = _gold.withValues(alpha: 0.6));
  }

  void _paintArms(Canvas canvas) {
    final arm = Paint()
      ..color = _body
      ..strokeWidth = 9
      ..strokeCap = StrokeCap.round;
    final highlight = Paint()
      ..color = _bodyLight
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(_LampGeometry.baseJoint, _LampGeometry.elbow, arm);
    canvas.drawLine(_LampGeometry.elbow, _LampGeometry.headJoint, arm);
    canvas.drawLine(_LampGeometry.baseJoint + const Offset(-2, 0), _LampGeometry.elbow + const Offset(-2, 0), highlight);

    for (final joint in [_LampGeometry.baseJoint, _LampGeometry.elbow, _LampGeometry.headJoint]) {
      canvas.drawCircle(joint, 9, Paint()..color = _gold);
      canvas.drawCircle(joint, 4, Paint()..color = _body);
    }
  }

  void _paintCord(Canvas canvas) {
    final start = _LampGeometry.cordStart();
    final knob = _LampGeometry.knob(pull);
    canvas.drawLine(start, knob, Paint()
      ..color = _gold
      ..strokeWidth = 1.6);
    if (intensity > 0) {
      canvas.drawCircle(knob, 14, Paint()..color = color.withValues(alpha: 0.25 * intensity)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8));
    }
    canvas.drawCircle(knob, 7, Paint()..color = _gold);
    canvas.drawCircle(knob + const Offset(-2, -2), 2, Paint()..color = Colors.white.withValues(alpha: 0.6));
  }

  void _paintHead(Canvas canvas) {
    canvas.save();
    canvas.translate(_LampGeometry.headCenter.dx, _LampGeometry.headCenter.dy);
    canvas.rotate(_LampGeometry.headAngle);

    // Dôme de l'abat-jour (origine = centre de l'ouverture).
    final dome = Path()
      ..moveTo(-58, 0)
      ..cubicTo(-58, -62, -28, -84, 0, -84)
      ..cubicTo(28, -84, 58, -62, 58, 0)
      ..close();
    final domeRect = const Rect.fromLTRB(-58, -84, 58, 0);
    canvas.drawPath(dome, Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF4A4B57), _body, Color(0xFF0E0E12)],
      ).createShader(domeRect));
    // Reflet
    canvas.drawPath(
      Path()
        ..moveTo(-40, -18)
        ..cubicTo(-40, -55, -20, -72, 2, -74),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4
        ..strokeCap = StrokeCap.round
        ..color = Colors.white.withValues(alpha: 0.12),
    );

    // Ouverture : sombre éteinte, colorée allumée.
    final opening = Rect.fromCenter(center: Offset.zero, width: 116, height: 26);
    canvas.drawOval(opening, Paint()..color = Color.lerp(const Color(0xFF2B2B33), color, intensity)!);
    canvas.drawOval(opening, Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = _gold.withValues(alpha: 0.8));

    // Ampoule
    if (intensity > 0) {
      canvas.drawCircle(const Offset(0, 2), 28, Paint()
        ..color = color.withValues(alpha: 0.55 * intensity)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 14));
    }
    canvas.drawCircle(const Offset(0, 2), 8, Paint()
      ..color = Color.lerp(const Color(0xFF55555F), Colors.white, intensity)!);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _LampPainter old) =>
      old.intensity != intensity || old.color != color || old.pull != pull;
}
