import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/api_exception.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/date_format.dart';
import '../../core/utils/responsive.dart';
import '../../providers/core_providers.dart';
import '../../providers/data_providers.dart';
import '../common/common_widgets.dart';

/// Rédaction d'une tâche adressée à un département.
/// Tous les membres actifs du département la recevront (et seront notifiés).
class CreateTaskScreen extends ConsumerStatefulWidget {
  const CreateTaskScreen({super.key});

  @override
  ConsumerState<CreateTaskScreen> createState() => _CreateTaskScreenState();
}

class _CreateTaskScreenState extends ConsumerState<CreateTaskScreen> {
  final _form = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _description = TextEditingController();
  int? _departmentId;
  String _urgency = 'blue';
  DateTime? _dueAt;
  bool _saving = false;

  static const _urgencies = [
    ('green', 'Flexible'),
    ('blue', 'Normale'),
    ('yellow', 'Importante'),
    ('red', 'Urgente'),
  ];

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    super.dispose();
  }

  Future<void> _pickDueDate() async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
      initialDate: _dueAt ?? now.add(const Duration(days: 1)),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(context: context, initialTime: const TimeOfDay(hour: 18, minute: 0));
    if (!mounted) return;
    setState(() => _dueAt = DateTime(date.year, date.month, date.day, time?.hour ?? 18, time?.minute ?? 0));
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      await ref.read(taskRepositoryProvider).create(
            title: _title.text,
            description: _description.text,
            departmentId: _departmentId!,
            urgency: _urgency,
            dueAt: _dueAt,
          );
      ref.invalidate(taskListProvider);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Tâche envoyée au département.')));
      Navigator.pop(context);
    } on ApiException catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final meta = ref.watch(metaProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Nouvelle tâche')),
      body: meta.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => MessageView(icon: Icons.error_outline, title: 'Référentiel indisponible', message: '$e'),
        data: (meta) => MaxWidth(
          maxWidth: 640,
          child: Form(
            key: _form,
            child: ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 32), children: [
              TextFormField(
                controller: _title,
                maxLength: 150,
                decoration: const InputDecoration(labelText: 'Titre', prefixIcon: Icon(Icons.title)),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Titre obligatoire' : null,
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _description,
                minLines: 4,
                maxLines: 10,
                maxLength: 5000,
                decoration: const InputDecoration(labelText: 'Description (facultatif)', alignLabelWithHint: true),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<int>(
                initialValue: _departmentId,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Département destinataire', prefixIcon: Icon(Icons.apartment)),
                items: [for (final d in meta.departments) DropdownMenuItem(value: d.id, child: Text(d.name))],
                onChanged: (v) => setState(() => _departmentId = v),
                validator: (v) => v == null ? 'Choisissez un département' : null,
              ),
              const SizedBox(height: 20),
              Text('Urgence', style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 8),
              Wrap(spacing: 8, runSpacing: 8, children: [
                for (final (value, label) in _urgencies)
                  ChoiceChip(
                    label: Text(label),
                    selected: _urgency == value,
                    avatar: CircleAvatar(backgroundColor: AppColors.urgencyColor(value), radius: 6),
                    selectedColor: AppColors.urgencyColor(value).withValues(alpha: 0.25),
                    showCheckmark: false,
                    onSelected: (_) => setState(() => _urgency = value),
                  ),
              ]),
              const SizedBox(height: 20),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.event_outlined),
                title: Text(_dueAt == null ? 'Pas d\'échéance' : 'Échéance : ${DateFormatter.full(_dueAt!)}'),
                trailing: _dueAt == null
                    ? TextButton(onPressed: _pickDueDate, child: const Text('Ajouter'))
                    : IconButton(
                        tooltip: 'Retirer',
                        icon: const Icon(Icons.close),
                        onPressed: () => setState(() => _dueAt = null),
                      ),
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: _saving ? null : _submit,
                icon: _saving
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.send_rounded),
                label: const Text('Envoyer la tâche'),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}
