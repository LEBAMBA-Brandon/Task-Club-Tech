import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

/// Petits composants partagés par les formulaires de la carte d'authentification.

/// Champ de saisie sombre avec libellé au-dessus (style de la maquette).
class AuthField extends StatefulWidget {
  const AuthField({
    super.key,
    required this.label,
    required this.controller,
    required this.icon,
    this.hint,
    this.obscure = false,
    this.keyboardType,
    this.validator,
    this.trailing,
    this.maxLength,
    this.inputFormatters,
    this.textInputAction = TextInputAction.next,
    this.autofillHints,
    this.onSubmitted,
  });

  final String label;
  final String? hint;
  final TextEditingController controller;
  final IconData icon;
  final bool obscure;
  final TextInputType? keyboardType;
  final String? Function(String?)? validator;
  final Widget? trailing;
  final int? maxLength;
  final List<TextInputFormatter>? inputFormatters;
  final TextInputAction textInputAction;
  final Iterable<String>? autofillHints;
  final ValueChanged<String>? onSubmitted;

  @override
  State<AuthField> createState() => _AuthFieldState();
}

class _AuthFieldState extends State<AuthField> {
  late bool _hidden = widget.obscure;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Text(widget.label, style: GoogleFonts.manrope(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
            const Spacer(),
            if (widget.trailing != null) widget.trailing!,
          ]),
          const SizedBox(height: 6),
          TextFormField(
            controller: widget.controller,
            obscureText: _hidden,
            keyboardType: widget.keyboardType,
            validator: widget.validator,
            maxLength: widget.maxLength,
            inputFormatters: widget.inputFormatters,
            textInputAction: widget.textInputAction,
            autofillHints: widget.autofillHints,
            onFieldSubmitted: widget.onSubmitted,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              counterText: '',
              hintText: widget.hint,
              hintStyle: const TextStyle(color: Colors.white38, fontSize: 14),
              prefixIcon: Icon(widget.icon, size: 18, color: Colors.white54),
              suffixIcon: widget.obscure
                  ? IconButton(
                      tooltip: _hidden ? 'Afficher' : 'Masquer',
                      icon: Icon(_hidden ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                          size: 18, color: Colors.white54),
                      onPressed: () => setState(() => _hidden = !_hidden),
                    )
                  : null,
              filled: true,
              fillColor: Colors.white.withValues(alpha: 0.04),
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: Colors.white12),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: Theme.of(context).colorScheme.primary, width: 1.4),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Liste déroulante au même style que [AuthField].
class AuthDropdown<T> extends StatelessWidget {
  const AuthDropdown({
    super.key,
    required this.label,
    required this.icon,
    required this.items,
    required this.value,
    required this.onChanged,
    this.hint,
    this.validator,
  });

  final String label;
  final IconData icon;
  final List<DropdownMenuItem<T>> items;
  final T? value;
  final ValueChanged<T?> onChanged;
  final String? hint;
  final String? Function(T?)? validator;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: GoogleFonts.manrope(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          DropdownButtonFormField<T>(
            key: ValueKey('$label-$value-${items.length}'),
            initialValue: value,
            items: items,
            onChanged: onChanged,
            validator: validator,
            isExpanded: true,
            dropdownColor: const Color(0xFF23232E),
            style: const TextStyle(color: Colors.white),
            iconEnabledColor: Colors.white54,
            hint: Text(hint ?? '', style: const TextStyle(color: Colors.white38, fontSize: 14)),
            decoration: InputDecoration(
              prefixIcon: Icon(icon, size: 18, color: Colors.white54),
              filled: true,
              fillColor: Colors.white.withValues(alpha: 0.04),
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: Colors.white12),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Bouton principal coloré par la lampe (« Se connecter → »).
class AccentButton extends StatelessWidget {
  const AccentButton({super.key, required this.label, required this.onPressed, this.loading = false, required this.color});

  final String label;
  final VoidCallback? onPressed;
  final bool loading;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: FilledButton(
        style: FilledButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          disabledBackgroundColor: color.withValues(alpha: 0.5),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
        onPressed: loading ? null : onPressed,
        child: loading
            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
            : Text('$label  →', style: GoogleFonts.manrope(fontWeight: FontWeight.w700)),
      ),
    );
  }
}

/// Message d'erreur rouge dans la carte.
class AuthError extends StatelessWidget {
  const AuthError(this.message, {super.key});
  final String? message;

  @override
  Widget build(BuildContext context) {
    if (message == null) return const SizedBox.shrink();
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFFEF4444).withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFEF4444).withValues(alpha: 0.4)),
      ),
      child: Row(children: [
        const Icon(Icons.error_outline, color: Color(0xFFEF4444), size: 18),
        const SizedBox(width: 8),
        Expanded(child: Text(message!, style: const TextStyle(color: Color(0xFFFCA5A5), fontSize: 13))),
      ]),
    );
  }
}

/// Validateurs communs.
class Validators {
  Validators._();

  static String? required(String? v) => (v == null || v.trim().isEmpty) ? 'Champ obligatoire' : null;

  static String? email(String? v) {
    if (v == null || v.trim().isEmpty) return 'Champ obligatoire';
    return RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(v.trim()) ? null : 'Adresse e-mail invalide';
  }

  /// Même règle que l'API : 8 caractères, majuscule, minuscule, chiffre.
  static String? password(String? v) {
    if (v == null || v.length < 8) return '8 caractères minimum';
    if (!RegExp(r'[A-Z]').hasMatch(v) || !RegExp(r'[a-z]').hasMatch(v)) return 'Majuscules et minuscules requises';
    if (!RegExp(r'\d').hasMatch(v)) return 'Au moins un chiffre';
    return null;
  }

  static String? code(String? v) => RegExp(r'^\d{6}$').hasMatch(v ?? '') ? null : 'Code à 6 chiffres';
}
