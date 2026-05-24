import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/app_theme.dart';
import '../core/constants.dart';
import '../core/input_limits.dart';
import '../models/user_profile.dart';
import '../services/database_service.dart';
import '../widgets/user_avatar.dart';

/// Minimal profile editor — name, phone and photo URL. Image upload (storage
/// + camera) is deliberately deferred; for now the user pastes a URL.
class EditProfileScreen extends StatefulWidget {
  final UserProfile profile;
  const EditProfileScreen({super.key, required this.profile});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _firstNameCtrl = TextEditingController();
  final _lastNameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _photoCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  final _db = DatabaseService();

  bool _saving = false;
  bool _dirty = false;

  @override
  void initState() {
    super.initState();
    _firstNameCtrl.text = widget.profile.firstName;
    _lastNameCtrl.text = widget.profile.lastName;
    _phoneCtrl.text = widget.profile.phone ?? '';
    _photoCtrl.text = widget.profile.photoUrl ?? '';
    for (final c in [_firstNameCtrl, _lastNameCtrl, _phoneCtrl, _photoCtrl]) {
      c.addListener(_markDirty);
    }
  }

  void _markDirty() {
    if (!_dirty) setState(() => _dirty = true);
  }

  @override
  void dispose() {
    _firstNameCtrl.dispose();
    _lastNameCtrl.dispose();
    _phoneCtrl.dispose();
    _photoCtrl.dispose();
    super.dispose();
  }

  Future<bool> _confirmDiscard() async {
    if (!_dirty) return true;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Niezapisane zmiany'),
        content: const Text(
            'Masz niezapisane zmiany. Czy na pewno chcesz wyjść bez zapisu?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Wróć'),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: AppTheme.errorColor),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Odrzuć zmiany'),
          ),
        ],
      ),
    );
    return ok ?? false;
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Zapisać profil?'),
        content: const Text('Zmiany będą widoczne natychmiast w aplikacji.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Anuluj'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Zapisz'),
          ),
        ],
      ),
    );
    if (ok != true) return;

    setState(() => _saving = true);
    try {
      final updated = widget.profile.copyWith(
        firstName: _firstNameCtrl.text.trim(),
        lastName: _lastNameCtrl.text.trim(),
        phone: _phoneCtrl.text.trim().isEmpty ? null : _phoneCtrl.text.trim(),
        photoUrl: _photoCtrl.text.trim().isEmpty ? null : _photoCtrl.text.trim(),
      );
      await _db.updateUserProfile(updated);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Profil zapisany'),
          backgroundColor: AppTheme.primaryColor,
        ),
      );
      Navigator.of(context).pop(updated);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Nie udało się zapisać: $e'),
          backgroundColor: AppTheme.errorColor,
        ),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Use the live text from the controllers so the avatar preview reflects
    // the user's edits without having to save first.
    final previewProfile = widget.profile.copyWith(
      firstName: _firstNameCtrl.text.trim().isEmpty
          ? widget.profile.firstName
          : _firstNameCtrl.text.trim(),
      lastName: _lastNameCtrl.text.trim().isEmpty
          ? widget.profile.lastName
          : _lastNameCtrl.text.trim(),
      photoUrl: _photoCtrl.text.trim(),
    );
    return PopScope(
      canPop: !_dirty,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        if (await _confirmDiscard() && mounted) Navigator.of(context).pop();
      },
      child: Scaffold(
        appBar: AppBar(title: const Text('Mój profil')),
        body: Form(
          key: _formKey,
          autovalidateMode: AutovalidateMode.onUserInteraction,
          child: ListView(
            padding: const EdgeInsets.all(AppConstants.defaultPadding),
            children: [
              Center(child: UserAvatar(profile: previewProfile, radius: 56)),
              const SizedBox(height: 8),
              Center(
                child: Text(
                  widget.profile.email,
                  style:
                      const TextStyle(color: AppTheme.textSecondaryColor),
                ),
              ),
              const SizedBox(height: 24),
              TextFormField(
                controller: _firstNameCtrl,
                maxLength: InputLimits.firstName,
                inputFormatters: [
                  LengthLimitingTextInputFormatter(InputLimits.firstName),
                  FilteringTextInputFormatter.deny(RegExp(r'[\n\r\t]')),
                ],
                decoration: const InputDecoration(
                  labelText: 'Imię',
                  prefixIcon: Icon(Icons.person),
                ),
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? 'Imię jest wymagane'
                    : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _lastNameCtrl,
                maxLength: InputLimits.lastName,
                inputFormatters: [
                  LengthLimitingTextInputFormatter(InputLimits.lastName),
                  FilteringTextInputFormatter.deny(RegExp(r'[\n\r\t]')),
                ],
                decoration: const InputDecoration(
                  labelText: 'Nazwisko',
                  prefixIcon: Icon(Icons.person_outline),
                ),
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? 'Nazwisko jest wymagane'
                    : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _phoneCtrl,
                keyboardType: TextInputType.phone,
                maxLength: InputLimits.phone,
                inputFormatters: [
                  LengthLimitingTextInputFormatter(InputLimits.phone),
                  FilteringTextInputFormatter.allow(RegExp(r'[+0-9\s\-()]')),
                ],
                decoration: const InputDecoration(
                  labelText: 'Telefon',
                  hintText: '+48 600 123 456',
                  prefixIcon: Icon(Icons.phone),
                  helperText:
                      'Widoczny po podjęciu zgłoszenia — pozwala na szybki kontakt.',
                ),
                validator: InputValidators.phone,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _photoCtrl,
                keyboardType: TextInputType.url,
                maxLength: InputLimits.photoUrl,
                inputFormatters: [
                  LengthLimitingTextInputFormatter(InputLimits.photoUrl),
                  FilteringTextInputFormatter.deny(RegExp(r'[\s]')),
                ],
                decoration: const InputDecoration(
                  labelText: 'URL zdjęcia (opcjonalnie)',
                  hintText: 'https://...',
                  prefixIcon: Icon(Icons.image_outlined),
                  helperText:
                      'Wklej link do swojego zdjęcia (tylko http(s)).',
                ),
                onChanged: (_) => setState(() {}),
                validator: InputValidators.photoUrl,
              ),
              const SizedBox(height: 32),
              SizedBox(
                height: 56,
                child: ElevatedButton.icon(
                  onPressed: (_saving || !_dirty) ? null : _save,
                  icon: _saving
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.save_rounded),
                  label: const Text('Zapisz profil'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
