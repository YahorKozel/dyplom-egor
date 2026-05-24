import 'package:flutter/material.dart';

import '../core/app_theme.dart';
import '../core/constants.dart';
import '../services/auth_service.dart';
import '../services/database_service.dart';
import '../widgets/custom_text_field.dart';
import 'home_router.dart';
import 'registration_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();

  final _auth = AuthService();
  final _db = DatabaseService();

  bool _isLoading = false;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _signIn() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    try {
      final cred = await _auth.signInWithEmailAndPassword(
        _emailCtrl.text.trim(),
        _passwordCtrl.text.trim(),
      );
      final profile = await _db.getUserProfile(cred.user!.uid);
      if (!mounted) return;
      if (profile == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Brak profilu w bazie. Zarejestruj się ponownie.'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
        await _auth.signOut();
        return;
      }
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => HomeRouter(profile: profile)),
        (_) => false,
      );
    } catch (e) {
      if (!mounted) return;
      final err = e.toString();
      String msg;
      if (err.contains('user-not-found') || err.contains('invalid-credential')) {
        msg = 'Nieprawidłowy e-mail lub hasło';
      } else if (err.contains('wrong-password')) {
        msg = 'Nieprawidłowe hasło';
      } else if (err.contains('invalid-email')) {
        msg = 'Nieprawidłowy format e-mail';
      } else if (err.contains('too-many-requests')) {
        msg = 'Zbyt wiele prób. Spróbuj ponownie później.';
      } else {
        msg = err.replaceAll('Exception: ', '');
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg), backgroundColor: AppTheme.errorColor),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Logowanie')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppConstants.defaultPadding),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 20),
                Center(
                  child: Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.login,
                        size: 50, color: AppTheme.primaryColor),
                  ),
                ),
                const SizedBox(height: 16),
                const Center(
                  child: Text(
                    'Zaloguj się',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.primaryColor,
                    ),
                  ),
                ),
                const SizedBox(height: 32),
                CustomTextField(
                  controller: _emailCtrl,
                  label: 'Adres e-mail',
                  icon: Icons.email,
                  keyboardType: TextInputType.emailAddress,
                  validator: (v) => (v == null || !v.contains('@'))
                      ? 'Wpisz poprawny adres e-mail'
                      : null,
                ),
                const SizedBox(height: 20),
                CustomTextField(
                  controller: _passwordCtrl,
                  label: 'Hasło',
                  icon: Icons.lock,
                  obscureText: true,
                  validator: (v) => (v == null || v.length < 6)
                      ? 'Hasło musi mieć co najmniej 6 znaków'
                      : null,
                ),
                const SizedBox(height: 32),
                SizedBox(
                  height: 56,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _signIn,
                    child: _isLoading
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text('Zaloguj się'),
                  ),
                ),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: _isLoading
                      ? null
                      : () => Navigator.of(context).pushReplacement(
                            MaterialPageRoute(
                                builder: (_) => const RegistrationScreen()),
                          ),
                  child: const Text('Nie masz konta? Zarejestruj się'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
