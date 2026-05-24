import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../core/app_theme.dart';
import '../core/constants.dart';
import '../core/input_limits.dart';
import '../models/user_role.dart';
import '../services/auth_service.dart';
import '../services/database_service.dart';
import '../services/location_service.dart';
import '../viewmodels/registration_view_model.dart';
import '../widgets/city_search_field.dart';
import '../widgets/custom_text_field.dart';
import '../widgets/interactive_map.dart';
import 'home_router.dart';
import 'login_screen.dart';

class RegistrationScreen extends StatelessWidget {
  const RegistrationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) {
        final vm = RegistrationViewModel(
          AuthService(),
          DatabaseService(),
          LocationService(),
        );
        vm.initLocationAndMarkers();
        return vm;
      },
      child: const _RegistrationView(),
    );
  }
}

class _RegistrationView extends StatefulWidget {
  const _RegistrationView();

  @override
  State<_RegistrationView> createState() => _RegistrationViewState();
}

class _RegistrationViewState extends State<_RegistrationView> {
  final _formKey = GlobalKey<FormState>();

  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _cityController = TextEditingController();
  final _radiusController = TextEditingController(
    text: AppConstants.defaultVolunteerRadiusKm.toStringAsFixed(0),
  );

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _firstNameController.dispose();
    _lastNameController.dispose();
    _cityController.dispose();
    _radiusController.dispose();
    super.dispose();
  }

  void _onRegister(RegistrationViewModel vm) async {
    if (!_formKey.currentState!.validate()) return;

    final radius = vm.role == UserRole.volunteer
        ? double.tryParse(_radiusController.text.trim().replaceAll(',', '.'))
        : null;

    final success = await vm.registerUser(
      email: _emailController.text.trim(),
      password: _passwordController.text.trim(),
      firstName: _firstNameController.text.trim(),
      lastName: _lastNameController.text.trim(),
      city: _cityController.text.trim(),
      radiusKm: radius,
    );

    if (success && mounted && vm.registeredProfile != null) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => HomeRouter(profile: vm.registeredProfile!),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Rejestracja')),
      body: Consumer<RegistrationViewModel>(
        builder: (context, vm, child) {
          if (vm.errorMessage != null) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(vm.errorMessage!),
                  backgroundColor: AppTheme.errorColor,
                ),
              );
              vm.clearError();
            });
          }

          // Keep city field in sync with detected region if user hasn't typed
          // anything custom yet.
          final detected = vm.matchedRegion?.name;
          if (detected != null && _cityController.text != detected) {
            _cityController.text = detected;
          }

          return SingleChildScrollView(
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
                      child: const Icon(Icons.group_add, size: 50, color: AppTheme.primaryColor),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Center(
                    child: Text(
                      'Utwórz Konto',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.primaryColor,
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),

                  _RoleSelector(
                    role: vm.role,
                    onChanged: vm.setRole,
                  ),
                  const SizedBox(height: 24),

                  CustomTextField(
                    controller: _emailController,
                    label: 'Adres e-mail',
                    icon: Icons.email,
                    keyboardType: TextInputType.emailAddress,
                    maxLength: 120,
                    inputFormatters: [
                      LengthLimitingTextInputFormatter(120),
                      FilteringTextInputFormatter.deny(RegExp(r'\s')),
                    ],
                    validator: (val) {
                      if (val == null || val.trim().isEmpty) {
                        return 'Wpisz adres e-mail';
                      }
                      final email = val.trim();
                      final ok = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email);
                      return ok ? null : 'Wpisz poprawny adres e-mail';
                    },
                  ),
                  const SizedBox(height: 20),

                  CustomTextField(
                    controller: _passwordController,
                    label: 'Hasło',
                    icon: Icons.lock,
                    obscureText: true,
                    maxLength: 64,
                    inputFormatters: [
                      LengthLimitingTextInputFormatter(64),
                    ],
                    validator: (val) {
                      if (val == null || val.length < 6) {
                        return 'Hasło musi mieć co najmniej 6 znaków';
                      }
                      if (val.length > 64) return 'Hasło jest za długie';
                      return null;
                    },
                  ),
                  const SizedBox(height: 20),

                  CustomTextField(
                    controller: _firstNameController,
                    label: 'Imię',
                    icon: Icons.person,
                    maxLength: InputLimits.firstName,
                    inputFormatters: [
                      LengthLimitingTextInputFormatter(InputLimits.firstName),
                      FilteringTextInputFormatter.deny(RegExp(r'[\n\r\t]')),
                    ],
                    validator: (val) => (val == null || val.trim().isEmpty)
                        ? 'To pole jest wymagane'
                        : null,
                  ),
                  const SizedBox(height: 20),
                  CustomTextField(
                    controller: _lastNameController,
                    label: 'Nazwisko',
                    icon: Icons.person_outline,
                    maxLength: InputLimits.lastName,
                    inputFormatters: [
                      LengthLimitingTextInputFormatter(InputLimits.lastName),
                      FilteringTextInputFormatter.deny(RegExp(r'[\n\r\t]')),
                    ],
                    validator: (val) => (val == null || val.trim().isEmpty)
                        ? 'To pole jest wymagane'
                        : null,
                  ),
                  const SizedBox(height: 20),

                  CitySearchField(
                    controller: _cityController,
                    onSearch: vm.searchCities,
                    onSelected: (city) {
                      _cityController.text = city.name;
                      vm.focusOnCity(city);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                              '🔍 ${city.name} — mapa wycentrowana. Tapnij dom na mapie.'),
                          backgroundColor: AppTheme.accentColor,
                        ),
                      );
                    },
                    validator: (val) =>
                        (val == null || val.trim().isEmpty) ? 'Wybierz miasto' : null,
                  ),
                  const SizedBox(height: 24),

                  if (vm.role == UserRole.volunteer) ...[
                    CustomTextField(
                      controller: _radiusController,
                      label: 'Promień działania (km)',
                      icon: Icons.radar,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      validator: (val) {
                        final n = double.tryParse((val ?? '').replaceAll(',', '.'));
                        if (n == null || n <= 0) return 'Podaj liczbę większą od 0';
                        if (n > 500) return 'Maksymalnie 500 km';
                        return null;
                      },
                    ),
                    const SizedBox(height: 24),
                  ],

                  const Text(
                    'Gdzie mieszkasz?',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Tapnij dokładnie miejsce swojego domu — czerwona pinezka zostanie tam, '
                    'a my dopasujemy gminę automatycznie.',
                    style: TextStyle(fontSize: 14, color: AppTheme.textSecondaryColor),
                  ),
                  const SizedBox(height: 16),

                  Container(
                    height: 350,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(AppConstants.defaultBorderRadius),
                      border: Border.all(color: Colors.grey.shade300),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.05),
                          blurRadius: 10,
                          offset: const Offset(0, 5),
                        )
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(AppConstants.defaultBorderRadius),
                      child: InteractiveMap(
                        mapController: vm.mapController,
                        selectedPosition: vm.selectedPosition,
                        poiMarkers: vm.poiMarkers,
                        onTap: (pos) {
                          final region = vm.selectPositionOnMap(pos);
                          final msg = region != null
                              ? '📍 Zapisano dom. Gmina: ${region.name}'
                              : '📍 Zapisano dom. Nie udało się rozpoznać gminy.';
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(msg),
                              backgroundColor: AppTheme.primaryColor,
                            ),
                          );
                        },
                        onMarkerTap: (city) {
                          vm.focusOnCity(city);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                  '🔍 ${city.name} — mapa wycentrowana. Tapnij dom na mapie.'),
                              backgroundColor: AppTheme.accentColor,
                            ),
                          );
                        },
                      ),
                    ),
                  ),

                  if (vm.selectedPosition != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      'Twój dom: '
                      '${vm.selectedPosition!.latitude.toStringAsFixed(4)}, '
                      '${vm.selectedPosition!.longitude.toStringAsFixed(4)}'
                      '${vm.matchedRegion != null ? '  •  gmina ${vm.matchedRegion!.name}' : ''}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: AppTheme.textSecondaryColor),
                    ),
                  ],

                  const SizedBox(height: 40),

                  SizedBox(
                    height: 56,
                    child: ElevatedButton(
                      onPressed: vm.isLoading ? null : () => _onRegister(vm),
                      child: vm.isLoading
                          ? const CircularProgressIndicator(color: Colors.white)
                          : const Text('Zarejestruj się'),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: vm.isLoading
                        ? null
                        : () => Navigator.of(context).pushReplacement(
                              MaterialPageRoute(builder: (_) => const LoginScreen()),
                            ),
                    child: const Text('Masz już konto? Zaloguj się'),
                  ),
                  const SizedBox(height: 12),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _RoleSelector extends StatelessWidget {
  final UserRole role;
  final ValueChanged<UserRole> onChanged;

  const _RoleSelector({required this.role, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Kim jesteś?',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 12),
        SegmentedButton<UserRole>(
          segments: const [
            ButtonSegment(
              value: UserRole.senior,
              label: Text('Senior'),
              icon: Icon(Icons.elderly),
            ),
            ButtonSegment(
              value: UserRole.volunteer,
              label: Text('Wolontariusz'),
              icon: Icon(Icons.volunteer_activism),
            ),
          ],
          selected: {role},
          onSelectionChanged: (s) => onChanged(s.first),
        ),
      ],
    );
  }
}
