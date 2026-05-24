import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/app_theme.dart';
import '../core/constants.dart';
import '../core/input_limits.dart';
import '../models/task.dart';
import '../models/task_category.dart';
import '../models/user_profile.dart';
import '../services/database_service.dart';

/// Senior-only — create a new help request (zgłoszenie). The publish button
/// requires two clicks: it first asks for confirmation in a dialog and then
/// writes to Firestore.
class CreateTaskScreen extends StatefulWidget {
  final UserProfile senior;
  const CreateTaskScreen({super.key, required this.senior});

  @override
  State<CreateTaskScreen> createState() => _CreateTaskScreenState();
}

class _CreateTaskScreenState extends State<CreateTaskScreen> {
  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  final _db = DatabaseService();

  TaskCategory? _category;
  bool _submitting = false;

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  bool get _canSubmit =>
      _category != null &&
      _titleCtrl.text.trim().isNotEmpty &&
      _descCtrl.text.trim().isNotEmpty &&
      !_submitting;

  Future<void> _onPublish() async {
    if (!_formKey.currentState!.validate() || _category == null) return;

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Opublikować zgłoszenie?'),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 360),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Icon(_category!.icon, color: AppTheme.primaryColor),
                  const SizedBox(width: 8),
                  Text(_category!.label,
                      style:
                          const TextStyle(fontWeight: FontWeight.w600)),
                ]),
                const SizedBox(height: 12),
                Text(_titleCtrl.text.trim(),
                    style: const TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 18)),
                const SizedBox(height: 6),
                Text(_descCtrl.text.trim(),
                    style: const TextStyle(
                        color: AppTheme.textSecondaryColor)),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Wróć i popraw'),
          ),
          ElevatedButton.icon(
            onPressed: () => Navigator.of(ctx).pop(true),
            icon: const Icon(Icons.check_rounded),
            label: const Text('Opublikuj'),
          ),
        ],
      ),
    );

    if (ok != true) return;

    setState(() => _submitting = true);
    try {
      final draft = HelpTask(
        id: '',
        seniorId: widget.senior.uid,
        title: _titleCtrl.text.trim(),
        description: _descCtrl.text.trim(),
        category: _category!,
        status: TaskStatus.open,
      );
      await _db.createTask(draft);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Zgłoszenie opublikowane'),
          backgroundColor: AppTheme.primaryColor,
        ),
      );
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Nie udało się opublikować: $e'),
          backgroundColor: AppTheme.errorColor,
        ),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Nowe zgłoszenie')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppConstants.defaultPadding),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'W czym potrzebujesz pomocy?',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 12),
              _CategoryGrid(
                selected: _category,
                onSelected: (c) => setState(() => _category = c),
              ),
              const SizedBox(height: 24),
              TextFormField(
                controller: _titleCtrl,
                maxLength: InputLimits.taskTitle,
                inputFormatters: [
                  LengthLimitingTextInputFormatter(InputLimits.taskTitle),
                  FilteringTextInputFormatter.deny(RegExp(r'[\n\r]')),
                ],
                decoration: const InputDecoration(
                  labelText: 'Tytuł (krótko)',
                  prefixIcon: Icon(Icons.title),
                  helperText: 'Maksymalnie 80 znaków',
                ),
                onChanged: (_) => setState(() {}),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Wpisz tytuł';
                  if (v.trim().length < 3) return 'Tytuł jest za krótki';
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _descCtrl,
                maxLength: InputLimits.taskDescription,
                inputFormatters: [
                  LengthLimitingTextInputFormatter(InputLimits.taskDescription),
                ],
                decoration: const InputDecoration(
                  labelText: 'Opis (co konkretnie?)',
                  prefixIcon: Icon(Icons.description),
                  alignLabelWithHint: true,
                  helperText: 'Maksymalnie 1000 znaków',
                ),
                minLines: 4,
                maxLines: 8,
                onChanged: (_) => setState(() {}),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) {
                    return 'Opisz, czego potrzebujesz';
                  }
                  if (v.trim().length < 5) return 'Opis jest za krótki';
                  return null;
                },
              ),
              const SizedBox(height: 32),
              SizedBox(
                height: 56,
                child: ElevatedButton.icon(
                  onPressed: _canSubmit ? _onPublish : null,
                  icon: _submitting
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.send_rounded),
                  label: const Text('Opublikuj zgłoszenie'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CategoryGrid extends StatelessWidget {
  final TaskCategory? selected;
  final ValueChanged<TaskCategory> onSelected;

  const _CategoryGrid({required this.selected, required this.onSelected});

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 4,
      childAspectRatio: 0.85,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 10,
      crossAxisSpacing: 10,
      children: TaskCategory.values.map((c) {
        final isSelected = selected == c;
        return GestureDetector(
          onTap: () => onSelected(c),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            decoration: BoxDecoration(
              color: isSelected
                  ? AppTheme.primaryColor
                  : AppTheme.surfaceColor,
              borderRadius:
                  BorderRadius.circular(AppConstants.defaultBorderRadius),
              border: Border.all(
                color: isSelected
                    ? AppTheme.primaryColor
                    : Colors.white.withValues(alpha: 0.1),
                width: 2,
              ),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  c.icon,
                  size: 28,
                  color: isSelected
                      ? AppTheme.backgroundColor
                      : AppTheme.primaryColor,
                ),
                const SizedBox(height: 6),
                Text(
                  c.label,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: isSelected
                        ? AppTheme.backgroundColor
                        : AppTheme.textPrimaryColor,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}
