import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

/// Saisie du code de vérification en 6 cases séparées.
///
/// - Un seul champ invisible reçoit la frappe : le curseur « saute » de case en case,
///   l'effacement revient en arrière, le collage d'un code complet remplit tout.
/// - La case active s'illumine à la couleur de la lampe ; chaque chiffre apparaît
///   avec un petit rebond ; les cases tremblent et passent au rouge en cas d'erreur.
/// - [onCompleted] est appelé dès que les 6 chiffres sont saisis.
class CodeInput extends StatefulWidget {
  const CodeInput({
    super.key,
    required this.controller,
    required this.accent,
    this.onCompleted,
    this.hasError = false,
    this.length = 6,
  });

  final TextEditingController controller;
  final Color accent;
  final ValueChanged<String>? onCompleted;
  final bool hasError;
  final int length;

  @override
  State<CodeInput> createState() => _CodeInputState();
}

class _CodeInputState extends State<CodeInput> with SingleTickerProviderStateMixin {
  final _focus = FocusNode();
  late final AnimationController _shake =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 420));

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onChanged);
    _focus.addListener(() => setState(() {}));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focus.requestFocus();
    });
  }

  @override
  void didUpdateWidget(covariant CodeInput old) {
    super.didUpdateWidget(old);
    if (widget.hasError && !old.hasError) {
      _shake.forward(from: 0);
      HapticFeedback.mediumImpact();
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onChanged);
    _focus.dispose();
    _shake.dispose();
    super.dispose();
  }

  void _onChanged() {
    setState(() {});
    final text = widget.controller.text;
    if (text.length == widget.length) {
      HapticFeedback.lightImpact();
      widget.onCompleted?.call(text);
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = widget.controller.text;

    return AnimatedBuilder(
      animation: _shake,
      builder: (context, child) {
        // Tremblement horizontal amorti en cas de code faux.
        final t = _shake.value;
        final dx = t == 0 ? 0.0 : 10 * (1 - t) * (((t * 8).floor().isEven) ? 1 : -1);
        return Transform.translate(offset: Offset(dx, 0), child: child);
      },
      child: GestureDetector(
        onTap: () => _focus.requestFocus(),
        child: Stack(children: [
          // Champ réel, invisible, qui reçoit le clavier et le collage.
          Positioned.fill(
            child: Opacity(
              opacity: 0,
              child: TextField(
                controller: widget.controller,
                focusNode: _focus,
                keyboardType: TextInputType.number,
                autofillHints: const [AutofillHints.oneTimeCode],
                maxLength: widget.length,
                showCursor: false,
                enableInteractiveSelection: true,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: const InputDecoration(counterText: '', border: InputBorder.none),
              ),
            ),
          ),
          IgnorePointer(
            child: LayoutBuilder(builder: (context, c) {
              const gap = 8.0;
              final box = ((c.maxWidth - gap * (widget.length - 1)) / widget.length).clamp(36.0, 54.0);
              return Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (var i = 0; i < widget.length; i++) ...[
                    if (i > 0) const SizedBox(width: gap),
                    _box(i, text, box),
                  ],
                ],
              );
            }),
          ),
        ]),
      ),
    );
  }

  Widget _box(int i, String text, double size) {
    final filled = i < text.length;
    final active = _focus.hasFocus && (i == text.length || (i == widget.length - 1 && text.length == widget.length));
    final color = widget.hasError
        ? const Color(0xFFEF4444)
        : active
            ? widget.accent
            : filled
                ? widget.accent.withValues(alpha: 0.55)
                : Colors.white24;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      width: size,
      height: size * 1.18,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: filled ? widget.accent.withValues(alpha: 0.10) : Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color, width: active ? 2 : 1.2),
        boxShadow: active ? [BoxShadow(color: widget.accent.withValues(alpha: 0.45), blurRadius: 14)] : null,
      ),
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 220),
        transitionBuilder: (child, anim) => ScaleTransition(
          scale: CurvedAnimation(parent: anim, curve: Curves.elasticOut),
          child: FadeTransition(opacity: anim, child: child),
        ),
        child: filled
            ? Text(text[i],
                key: ValueKey('$i-${text[i]}'),
                style: GoogleFonts.manrope(color: Colors.white, fontSize: size * 0.48, fontWeight: FontWeight.w800))
            : active
                ? _Caret(key: const ValueKey('caret'), color: widget.accent, height: size * 0.45)
                : const SizedBox.shrink(key: ValueKey('empty')),
      ),
    );
  }
}

/// Petit curseur clignotant dans la case active.
class _Caret extends StatefulWidget {
  const _Caret({super.key, required this.color, required this.height});
  final Color color;
  final double height;

  @override
  State<_Caret> createState() => _CaretState();
}

class _CaretState extends State<_Caret> with SingleTickerProviderStateMixin {
  late final AnimationController _blink =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 900))..repeat(reverse: true);

  @override
  void dispose() {
    _blink.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FadeTransition(
        opacity: _blink,
        child: Container(width: 2, height: widget.height, color: widget.color),
      );
}

/// Bouton « Coller le code » : récupère les 6 chiffres depuis le presse-papiers
/// (pratique quand on copie le code depuis l'e-mail).
class PasteCodeButton extends StatelessWidget {
  const PasteCodeButton({super.key, required this.controller, required this.accent});
  final TextEditingController controller;
  final Color accent;

  Future<void> _paste(BuildContext context) async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final digits = RegExp(r'\d{6}').firstMatch(data?.text ?? '')?.group(0);
    if (digits != null) {
      controller.text = digits;
    } else if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Aucun code à 6 chiffres à coller.')));
    }
  }

  @override
  Widget build(BuildContext context) => Align(
        alignment: Alignment.centerRight,
        child: TextButton.icon(
          onPressed: () => _paste(context),
          icon: Icon(Icons.content_paste_rounded, size: 16, color: accent),
          label: Text('Coller le code', style: TextStyle(color: accent, fontSize: 12, fontWeight: FontWeight.w700)),
        ),
      );
}
