import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/app_theme.dart';
import '../core/constants.dart';
import '../core/input_limits.dart';
import '../models/task.dart';
import '../models/user_profile.dart';
import '../services/database_service.dart';
import '../viewmodels/senior_home_view_model.dart';
import '../widgets/user_avatar.dart';
import 'create_task_screen.dart';
import 'edit_home_screen.dart';
import 'edit_profile_screen.dart';
import 'task_detail_screen.dart';

class SeniorHomeScreen extends StatelessWidget {
  final UserProfile profile;
  final VoidCallback? onSignOut;
  final ValueChanged<UserProfile>? onProfileUpdated;

  const SeniorHomeScreen({
    super.key,
    required this.profile,
    this.onSignOut,
    this.onProfileUpdated,
  });

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => SeniorHomeViewModel(DatabaseService(), profile),
      child: _SeniorHomeView(
        profile: profile,
        onSignOut: onSignOut,
        onProfileUpdated: onProfileUpdated,
      ),
    );
  }
}

class _SeniorHomeView extends StatelessWidget {
  final UserProfile profile;
  final VoidCallback? onSignOut;
  final ValueChanged<UserProfile>? onProfileUpdated;

  const _SeniorHomeView({
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

  Future<void> _openCreate(BuildContext context) async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => CreateTaskScreen(senior: profile)),
    );
    // Senior list updates automatically via stream — no manual refresh.
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('Moje zgłoszenia'),
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
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openCreate(context),
        icon: const Icon(Icons.add),
        label: const Text('Nowe zgłoszenie'),
      ),
      body: Consumer<SeniorHomeViewModel>(
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

          if (vm.isLoading && vm.tasks.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }

          if (vm.tasks.isEmpty) {
            return _EmptyState(name: vm.senior.firstName);
          }

          final filtered = vm.filteredTasks;
          return Column(
            children: [
              _StatusFilter(
                selected: vm.statusFilter,
                onChanged: vm.setStatusFilter,
              ),
              Expanded(
                child: filtered.isEmpty
                    ? const Center(
                        child: Padding(
                          padding: EdgeInsets.all(32),
                          child: Text(
                            'Brak zgłoszeń w wybranym statusie.',
                            style: TextStyle(
                                color: AppTheme.textSecondaryColor,
                                fontSize: 16),
                          ),
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(
                          AppConstants.defaultPadding,
                          8,
                          AppConstants.defaultPadding,
                          96,
                        ),
                        itemCount: filtered.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 12),
                        itemBuilder: (_, i) {
                          final task = filtered[i];
                          return _TaskCard(
                            task: task,
                            volunteer: vm.volunteerFor(task),
                            onTap: () => _openDetail(context, task),
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _StatusFilter extends StatelessWidget {
  final TaskStatus? selected;
  final ValueChanged<TaskStatus?> onChanged;
  const _StatusFilter({required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    Widget chip(String label, TaskStatus? value) {
      final isOn = selected == value;
      return Padding(
        padding: const EdgeInsets.only(right: 8),
        child: FilterChip(
          label: Text(label),
          selected: isOn,
          onSelected: (_) => onChanged(value),
          selectedColor: AppTheme.primaryColor,
          labelStyle: TextStyle(
            color: isOn ? AppTheme.backgroundColor : AppTheme.textPrimaryColor,
            fontWeight: FontWeight.w600,
          ),
        ),
      );
    }

    return SizedBox(
      height: 50,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(
            horizontal: AppConstants.defaultPadding, vertical: 6),
        children: [
          chip('Wszystkie', null),
          chip('Otwarte', TaskStatus.open),
          chip('W trakcie', TaskStatus.inProgress),
          chip('Zrobione', TaskStatus.done),
          chip('Anulowane', TaskStatus.cancelled),
        ],
      ),
    );
  }
}

class _TaskCard extends StatelessWidget {
  final HelpTask task;
  final UserProfile? volunteer;
  final VoidCallback onTap;

  const _TaskCard({
    required this.task,
    required this.volunteer,
    required this.onTap,
  });

  Color get _statusColor => switch (task.status) {
        TaskStatus.open => AppTheme.primaryColor,
        TaskStatus.inProgress => Colors.orangeAccent,
        TaskStatus.done => AppTheme.textSecondaryColor,
        TaskStatus.cancelled => AppTheme.errorColor,
      };

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppConstants.defaultBorderRadius),
      child: Container(
        decoration: BoxDecoration(
          color: AppTheme.surfaceColor,
          borderRadius: BorderRadius.circular(AppConstants.defaultBorderRadius),
          border: Border.all(color: _statusColor.withValues(alpha: 0.4)),
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(task.category.icon, color: _statusColor),
                const SizedBox(width: 8),
                Text(
                  task.category.label,
                  style: TextStyle(
                    color: _statusColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: _statusColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    task.status.label,
                    style: TextStyle(
                        color: _statusColor, fontWeight: FontWeight.w600),
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
            if (task.description.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                task.description,
                maxLines: InputLimits.feedDescriptionLines,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    fontSize: 14, color: AppTheme.textSecondaryColor),
              ),
            ],
            if (volunteer != null) ...[
              const SizedBox(height: 10),
              Row(
                children: [
                  UserAvatar(profile: volunteer!, radius: 14),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      task.status == TaskStatus.cancelled
                          ? 'Wcześniej: ${volunteer!.fullName}'
                          : 'Pomaga: ${volunteer!.fullName}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ],
            if (task.status == TaskStatus.cancelled &&
                (task.cancelReason?.trim().isNotEmpty ?? false)) ...[
              const SizedBox(height: 6),
              Text(
                'Powód: ${task.cancelReason}',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    fontSize: 12,
                    color: AppTheme.textSecondaryColor,
                    fontStyle: FontStyle.italic),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final String name;
  const _EmptyState({required this.name});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.inbox, size: 96, color: AppTheme.textSecondaryColor),
            const SizedBox(height: 16),
            Text(
              'Witaj, $name!',
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            const Text(
              'Nie masz jeszcze żadnych zgłoszeń.\nNaciśnij „Nowe zgłoszenie”, aby poprosić o pomoc.',
              style: TextStyle(fontSize: 16, color: AppTheme.textSecondaryColor),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
