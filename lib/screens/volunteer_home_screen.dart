import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/app_theme.dart';
import '../core/constants.dart';
import '../core/input_limits.dart';
import '../models/task.dart';
import '../models/user_profile.dart';
import '../services/database_service.dart';
import '../viewmodels/volunteer_home_view_model.dart';
import 'edit_home_screen.dart';
import 'edit_profile_screen.dart';
import 'task_detail_screen.dart';

class VolunteerHomeScreen extends StatelessWidget {
  final UserProfile profile;
  final VoidCallback? onSignOut;
  final ValueChanged<UserProfile>? onProfileUpdated;

  const VolunteerHomeScreen({
    super.key,
    required this.profile,
    this.onSignOut,
    this.onProfileUpdated,
  });

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => VolunteerHomeViewModel(DatabaseService(), profile),
      child: _VolunteerHomeView(
        profile: profile,
        onSignOut: onSignOut,
        onProfileUpdated: onProfileUpdated,
      ),
    );
  }
}

class _VolunteerHomeView extends StatelessWidget {
  final UserProfile profile;
  final VoidCallback? onSignOut;
  final ValueChanged<UserProfile>? onProfileUpdated;

  const _VolunteerHomeView({
    required this.profile,
    this.onSignOut,
    this.onProfileUpdated,
  });

  Future<void> _openEditHome(BuildContext context) async {
    final updated = await Navigator.of(context).push<UserProfile>(
      MaterialPageRoute(builder: (_) => EditHomeScreen(profile: profile)),
    );
    if (updated != null) onProfileUpdated?.call(updated);
  }

  Future<void> _openEditProfile(BuildContext context) async {
    final updated = await Navigator.of(context).push<UserProfile>(
      MaterialPageRoute(builder: (_) => EditProfileScreen(profile: profile)),
    );
    if (updated != null) onProfileUpdated?.call(updated);
  }

  void _openDetail(BuildContext context, HelpTask task) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => TaskDetailScreen(taskId: task.id, viewer: profile),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Pomoc seniorom'),
          actions: [
            IconButton(
              tooltip: 'Mój dom',
              icon: const Icon(Icons.home_outlined),
              onPressed: () => _openEditHome(context),
            ),
            IconButton(
              tooltip: 'Mój profil',
              icon: const Icon(Icons.person_outline),
              onPressed: () => _openEditProfile(context),
            ),
            if (onSignOut != null)
              IconButton(
                tooltip: 'Wyloguj',
                icon: const Icon(Icons.logout),
                onPressed: onSignOut,
              ),
          ],
          bottom: const TabBar(
            tabs: [
              Tab(icon: Icon(Icons.public), text: 'W pobliżu'),
              Tab(icon: Icon(Icons.assignment_ind_outlined), text: 'Moje zadania'),
            ],
          ),
        ),
        body: Consumer<VolunteerHomeViewModel>(
          builder: (context, vm, _) {
            if (vm.errorMessage != null) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(vm.errorMessage!),
                    backgroundColor: AppTheme.errorColor,
                  ),
                );
                vm.clearError();
              });
            }

            return TabBarView(
              children: [
                _NearbyTab(
                  vm: vm,
                  onTap: (t) => _openDetail(context, t),
                ),
                _MyTasksTab(
                  vm: vm,
                  onTap: (t) => _openDetail(context, t),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

// ─── Nearby tab ───────────────────────────────────────────────────────────

class _NearbyTab extends StatelessWidget {
  final VolunteerHomeViewModel vm;
  final ValueChanged<HelpTask> onTap;
  const _NearbyTab({required this.vm, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _RadiusHeader(
          radiusKm: vm.currentRadiusKm,
          isUnlimited: vm.isUnlimited,
          count: vm.nearby.length,
          onChanged: vm.setRadiusKm,
        ),
        Expanded(child: _buildBody()),
      ],
    );
  }

  Widget _buildBody() {
    if (vm.isLoading && vm.nearby.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (vm.nearby.isEmpty) {
      final scope = vm.isUnlimited
          ? 'Brak otwartych zgłoszeń.'
          : 'Brak zgłoszeń w promieniu ${vm.currentRadiusKm.toStringAsFixed(0)} km.';
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.search_off,
                  size: 96, color: AppTheme.textSecondaryColor),
              const SizedBox(height: 16),
              Text(
                scope,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 18,
                  color: AppTheme.textSecondaryColor,
                ),
              ),
            ],
          ),
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.all(AppConstants.defaultPadding),
      itemCount: vm.nearby.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (_, i) {
        final item = vm.nearby[i];
        return _TaskCard(
          item: item,
          onTap: () => onTap(item.task),
        );
      },
    );
  }
}

// ─── My tasks tab ─────────────────────────────────────────────────────────

class _MyTasksTab extends StatelessWidget {
  final VolunteerHomeViewModel vm;
  final ValueChanged<HelpTask> onTap;
  const _MyTasksTab({required this.vm, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final all = vm.mine;
    if (all.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Text(
            'Nie podjąłeś jeszcze żadnego zgłoszenia.\n'
            'Przejdź do zakładki „W pobliżu”, aby pomóc.',
            textAlign: TextAlign.center,
            style: TextStyle(
                color: AppTheme.textSecondaryColor, fontSize: 16),
          ),
        ),
      );
    }
    final active = all
        .where((n) => n.task.status == TaskStatus.inProgress)
        .toList();
    final history = all
        .where((n) =>
            n.task.status == TaskStatus.done ||
            n.task.status == TaskStatus.cancelled ||
            n.task.status == TaskStatus.open)
        .toList();

    return ListView(
      padding: const EdgeInsets.all(AppConstants.defaultPadding),
      children: [
        if (active.isNotEmpty) ...[
          const _SectionLabel('Aktywne'),
          for (final item in active)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _TaskCard(item: item, onTap: () => onTap(item.task)),
            ),
        ],
        if (history.isNotEmpty) ...[
          const SizedBox(height: 8),
          const _SectionLabel('Historia'),
          for (final item in history)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _TaskCard(item: item, onTap: () => onTap(item.task)),
            ),
        ],
      ],
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, top: 4),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w700,
          color: AppTheme.textSecondaryColor,
          letterSpacing: 0.4,
        ),
      ),
    );
  }
}

// ─── Shared widgets ───────────────────────────────────────────────────────

class _RadiusHeader extends StatelessWidget {
  final double radiusKm;
  final bool isUnlimited;
  final int count;
  final ValueChanged<double> onChanged;

  const _RadiusHeader({
    required this.radiusKm,
    required this.isUnlimited,
    required this.count,
    required this.onChanged,
  });

  String get _scopeLabel =>
      isUnlimited ? 'Wszystkie' : '${radiusKm.toStringAsFixed(0)} km';

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
      color: AppTheme.surfaceColor,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isUnlimited ? Icons.public : Icons.radar,
                size: 18,
                color: AppTheme.textSecondaryColor,
              ),
              const SizedBox(width: 8),
              Text(
                'Zasięg: $_scopeLabel',
                style: const TextStyle(color: AppTheme.textSecondaryColor),
              ),
              const Spacer(),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '$count szt.',
                  style: const TextStyle(
                    color: AppTheme.primaryColor,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          Slider(
            min: VolunteerHomeViewModel.minRadiusKm,
            max: VolunteerHomeViewModel.maxRadiusKm,
            divisions: (VolunteerHomeViewModel.maxRadiusKm -
                    VolunteerHomeViewModel.minRadiusKm)
                .toInt(),
            value: radiusKm,
            label: _scopeLabel,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}

class _TaskCard extends StatelessWidget {
  final NearbyTask item;
  final VoidCallback onTap;
  const _TaskCard({required this.item, required this.onTap});

  Color _statusColor(TaskStatus s) => switch (s) {
        TaskStatus.open => AppTheme.primaryColor,
        TaskStatus.inProgress => Colors.orangeAccent,
        TaskStatus.done => AppTheme.textSecondaryColor,
        TaskStatus.cancelled => AppTheme.errorColor,
      };

  @override
  Widget build(BuildContext context) {
    final task = item.task;
    final senior = item.senior;
    final sc = _statusColor(task.status);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppConstants.defaultBorderRadius),
      child: Container(
        decoration: BoxDecoration(
          color: AppTheme.surfaceColor,
          borderRadius: BorderRadius.circular(AppConstants.defaultBorderRadius),
          border: Border.all(color: sc.withValues(alpha: 0.4)),
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(task.category.icon, color: sc),
                const SizedBox(width: 8),
                Text(
                  task.category.label,
                  style: TextStyle(color: sc, fontWeight: FontWeight.w600),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: sc.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    task.status.label,
                    style:
                        TextStyle(color: sc, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              task.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style:
                  const TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 6),
            Text(
              '${senior.fullName} · ${senior.city}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: AppTheme.textSecondaryColor),
            ),
            if (task.description.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                task.description,
                maxLines: InputLimits.feedDescriptionLines,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 14),
              ),
            ],
            const SizedBox(height: 10),
            Row(
              children: [
                const Icon(Icons.directions_walk,
                    size: 18, color: AppTheme.textSecondaryColor),
                const SizedBox(width: 4),
                Text(
                  '${item.distanceKm.toStringAsFixed(1)} km',
                  style: const TextStyle(
                    color: AppTheme.textSecondaryColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                const Icon(Icons.chevron_right, color: AppTheme.primaryColor),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
