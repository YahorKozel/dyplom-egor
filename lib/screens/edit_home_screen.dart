import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/app_theme.dart';
import '../core/constants.dart';
import '../models/user_profile.dart';
import '../models/user_role.dart';
import '../services/database_service.dart';
import '../viewmodels/edit_home_view_model.dart';
import '../widgets/city_search_field.dart';
import '../widgets/interactive_map.dart';

/// Lets the signed-in user move their home pin (and, for volunteers, change
/// the search radius) after registration.
class EditHomeScreen extends StatelessWidget {
  final UserProfile profile;
  const EditHomeScreen({super.key, required this.profile});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => EditHomeViewModel(DatabaseService(), profile),
      child: const _EditHomeView(),
    );
  }
}

class _EditHomeView extends StatefulWidget {
  const _EditHomeView();

  @override
  State<_EditHomeView> createState() => _EditHomeViewState();
}

class _EditHomeViewState extends State<_EditHomeView> {
  final _cityController = TextEditingController();
  bool _cityInitialized = false;

  @override
  void dispose() {
    _cityController.dispose();
    super.dispose();
  }

  Future<bool> _confirmDiscard(BuildContext context, EditHomeViewModel vm) async {
    if (!vm.dirty) return true;
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

  Future<void> _onSave(BuildContext context, EditHomeViewModel vm) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Zapisać zmiany?'),
        content: Text(
          'Twój dom: ${vm.city.isNotEmpty ? vm.city : 'Nie podano'}\n'
          'Współrzędne: ${vm.selectedPosition.latitude.toStringAsFixed(4)}, '
          '${vm.selectedPosition.longitude.toStringAsFixed(4)}'
          '${vm.profile.role == UserRole.volunteer ? '\nPromień: ${vm.radiusKm?.toStringAsFixed(0)} km' : ''}',
        ),
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
    final saved = await vm.save();
    if (saved != null && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Zapisano nową lokalizację'),
          backgroundColor: AppTheme.primaryColor,
        ),
      );
      Navigator.of(context).pop(saved);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<EditHomeViewModel>(
      builder: (context, vm, _) {
        if (!_cityInitialized) {
          _cityController.text = vm.city;
          _cityInitialized = true;
        }

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

        return PopScope(
          canPop: !vm.dirty,
          onPopInvokedWithResult: (didPop, _) async {
            if (didPop) return;
            final allow = await _confirmDiscard(context, vm);
            if (allow && mounted) Navigator.of(context).pop();
          },
          child: Scaffold(
            appBar: AppBar(
              title: const Text('Mój dom'),
            ),
            body: vm.isLoading && vm.poiMarkers.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : SingleChildScrollView(
                    padding: const EdgeInsets.all(AppConstants.defaultPadding),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        CitySearchField(
                          controller: _cityController,
                          onSearch: vm.searchCities,
                          onSelected: (city) {
                            _cityController.text = city.name;
                            vm.focusOnCity(city);
                            vm.setCityManually(city);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                    '🔍 ${city.name} — mapa wycentrowana. Tapnij dom na mapie.'),
                                backgroundColor: AppTheme.accentColor,
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 20),
                        if (vm.profile.role == UserRole.volunteer) ...[
                          Row(
                            children: [
                              const Icon(Icons.radar,
                                  color: AppTheme.textSecondaryColor),
                              const SizedBox(width: 8),
                              Text(
                                'Promień działania: ${vm.radiusKm?.toStringAsFixed(0) ?? '—'} km',
                                style: const TextStyle(
                                    fontSize: 16,
                                    color: AppTheme.textSecondaryColor),
                              ),
                            ],
                          ),
                          Slider(
                            min: EditHomeViewModel.minRadiusKm,
                            max: EditHomeViewModel.maxRadiusKm,
                            divisions: (EditHomeViewModel.maxRadiusKm -
                                    EditHomeViewModel.minRadiusKm)
                                .toInt(),
                            value: vm.radiusKm ??
                                AppConstants.defaultVolunteerRadiusKm,
                            label:
                                '${vm.radiusKm?.toStringAsFixed(0) ?? '—'} km',
                            onChanged: vm.setRadiusKm,
                          ),
                          const SizedBox(height: 12),
                        ],
                        const Text(
                          'Tapnij dokładnie miejsce swojego domu — '
                          'czerwona pinezka zostanie tam, '
                          'a my dopasujemy gminę automatycznie.',
                          style: TextStyle(
                              fontSize: 14,
                              color: AppTheme.textSecondaryColor),
                        ),
                        const SizedBox(height: 16),
                        Container(
                          height: 400,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(
                                AppConstants.defaultBorderRadius),
                            border: Border.all(color: Colors.grey.shade300),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(
                                AppConstants.defaultBorderRadius),
                            child: InteractiveMap(
                              mapController: vm.mapController,
                              selectedPosition: vm.selectedPosition,
                              poiMarkers: vm.poiMarkers,
                              onTap: (pos) {
                                final region = vm.selectPositionOnMap(pos);
                                if (region != null) {
                                  _cityController.text = region.name;
                                }
                                final msg = region != null
                                    ? '📍 Zapisano nowy dom. Gmina: ${region.name}'
                                    : '📍 Zapisano nowy dom. Nie udało się rozpoznać gminy.';
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(msg),
                                    backgroundColor: AppTheme.primaryColor,
                                  ),
                                );
                              },
                              onMarkerTap: (city) {
                                vm.focusOnCity(city);
                              },
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Twój dom: '
                          '${vm.selectedPosition.latitude.toStringAsFixed(4)}, '
                          '${vm.selectedPosition.longitude.toStringAsFixed(4)}'
                          '${vm.matchedRegion != null ? '  •  gmina ${vm.matchedRegion!.name}' : ''}',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                              color: AppTheme.textSecondaryColor),
                        ),
                        const SizedBox(height: 32),
                        SizedBox(
                          height: 56,
                          child: ElevatedButton.icon(
                            onPressed:
                                (!vm.dirty || vm.isSaving) ? null : () => _onSave(context, vm),
                            icon: const Icon(Icons.save_rounded),
                            label: vm.isSaving
                                ? const SizedBox(
                                    width: 24,
                                    height: 24,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Text('Zapisz nową lokalizację'),
                          ),
                        ),
                        const SizedBox(height: 24),
                      ],
                    ),
                  ),
          ),
        );
      },
    );
  }
}
