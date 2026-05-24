import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/app_theme.dart';
import '../core/constants.dart';
import '../core/input_limits.dart';
import '../models/task.dart';
import '../models/user_profile.dart';
import '../services/database_service.dart';
import '../viewmodels/task_detail_view_model.dart';
import '../widgets/user_avatar.dart';

class TaskDetailScreen extends StatelessWidget {
  final String taskId;
  final UserProfile viewer;

  const TaskDetailScreen({
    super.key,
    required this.taskId,
    required this.viewer,
  });

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => TaskDetailViewModel(DatabaseService(), taskId, viewer),
      child: const _TaskDetailView(),
    );
  }
}

class _TaskDetailView extends StatelessWidget {
  const _TaskDetailView();

  @override
  Widget build(BuildContext context) {
    return Consumer<TaskDetailViewModel>(
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

        final task = vm.task;
        if (vm.isLoading && task == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('Zgłoszenie')),
            body: const Center(child: CircularProgressIndicator()),
          );
        }
        if (task == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('Zgłoszenie')),
            body: const Center(
              child: Text(
                'Zgłoszenie nie istnieje lub zostało usunięte.',
                style: TextStyle(fontSize: 16),
              ),
            ),
          );
        }

        return Scaffold(
          appBar: AppBar(title: Text(task.title, maxLines: 1, overflow: TextOverflow.ellipsis)),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(AppConstants.defaultPadding),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _StatusBanner(status: task.status),
                const SizedBox(height: 16),
                _CategoryRow(task: task),
                const SizedBox(height: 16),
                Text(
                  task.title,
                  style:
                      const TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
                ),
                if (task.description.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    task.description,
                    style: const TextStyle(fontSize: 16, height: 1.5),
                  ),
                ],
                const SizedBox(height: 20),
                if (vm.senior != null)
                  _PersonCard(
                    label: 'Senior (autor)',
                    profile: vm.senior!,
                    showContact: vm.isParticipant &&
                        task.status != TaskStatus.open,
                  ),
                if (vm.volunteer != null) ...[
                  const SizedBox(height: 12),
                  _PersonCard(
                    label: 'Wolontariusz',
                    profile: vm.volunteer!,
                    showContact: vm.isParticipant,
                  ),
                ],
                const SizedBox(height: 20),
                _AddressCard(vm: vm),
                const SizedBox(height: 20),
                _Timeline(task: task),
                const SizedBox(height: 24),
                _ActionButtons(vm: vm),
                const SizedBox(height: 32),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _StatusBanner extends StatelessWidget {
  final TaskStatus status;
  const _StatusBanner({required this.status});

  Color get _color => switch (status) {
        TaskStatus.open => AppTheme.primaryColor,
        TaskStatus.inProgress => Colors.orangeAccent,
        TaskStatus.done => AppTheme.textSecondaryColor,
        TaskStatus.cancelled => AppTheme.errorColor,
      };

  IconData get _icon => switch (status) {
        TaskStatus.open => Icons.fiber_new_rounded,
        TaskStatus.inProgress => Icons.hourglass_top_rounded,
        TaskStatus.done => Icons.check_circle_rounded,
        TaskStatus.cancelled => Icons.cancel_rounded,
      };

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: _color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppConstants.defaultBorderRadius),
        border: Border.all(color: _color, width: 1.5),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(_icon, color: _color, size: 24),
          const SizedBox(width: 8),
          Text(
            status.label,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: _color,
            ),
          ),
        ],
      ),
    );
  }
}

class _CategoryRow extends StatelessWidget {
  final HelpTask task;
  const _CategoryRow({required this.task});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.primaryColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(task.category.icon,
              color: AppTheme.primaryColor, size: 28),
          const SizedBox(width: 12),
          Text(
            task.category.label,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: AppTheme.primaryColor,
            ),
          ),
        ],
      ),
    );
  }
}

class _PersonCard extends StatelessWidget {
  final String label;
  final UserProfile profile;
  final bool showContact;
  const _PersonCard({
    required this.label,
    required this.profile,
    required this.showContact,
  });

  Future<void> _callPhone(BuildContext context, String phone) async {
    // Strip everything but +digits to make `tel:` URLs reliable.
    final dial = phone.replaceAll(RegExp(r'[^+0-9]'), '');
    final uri = Uri.parse('tel:$dial');
    try {
      final ok = await launchUrl(uri);
      if (!ok && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Nie można otworzyć dialera. Numer: $phone'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Nie można zadzwonić. Numer: $phone'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(AppConstants.defaultBorderRadius),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Row(
        children: [
          UserAvatar(profile: profile, radius: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: const TextStyle(
                        fontSize: 13,
                        color: AppTheme.textSecondaryColor)),
                const SizedBox(height: 2),
                Text(
                  profile.fullName.isEmpty ? '—' : profile.fullName,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontSize: 17, fontWeight: FontWeight.w700),
                ),
                if (showContact && (profile.phone?.trim().isNotEmpty ?? false)) ...[
                  const SizedBox(height: 6),
                  InkWell(
                    onTap: () => _callPhone(context, profile.phone!),
                    child: Row(
                      children: [
                        const Icon(Icons.phone,
                            size: 16, color: AppTheme.primaryColor),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            profile.phone!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: AppTheme.primaryColor,
                              fontWeight: FontWeight.w600,
                              decoration: TextDecoration.underline,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AddressCard extends StatelessWidget {
  final TaskDetailViewModel vm;
  const _AddressCard({required this.vm});

  Future<void> _openMaps(BuildContext context, double lat, double lng) async {
    final uri = Uri.parse(
      'https://www.google.com/maps/dir/?api=1&destination=$lat,$lng',
    );
    try {
      final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!ok && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Nie można otworzyć map. Spróbuj zainstalować Mapy Google.'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Nie udało się otworzyć map.'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final senior = vm.senior;
    final task = vm.task!;
    final reveal = vm.canSeeExactAddress && task.status != TaskStatus.open;
    final cityName = senior?.city ?? '—';
    final km = vm.distanceKm;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(AppConstants.defaultBorderRadius),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.location_on_outlined,
                  color: AppTheme.primaryColor),
              SizedBox(width: 8),
              Text('Adres',
                  style: TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w700)),
            ],
          ),
          const SizedBox(height: 8),
          Text('Gmina: $cityName',
              style: const TextStyle(fontSize: 16)),
          if (km != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                'Dystans: ${km.toStringAsFixed(1)} km',
                style: const TextStyle(
                    fontSize: 14, color: AppTheme.textSecondaryColor),
              ),
            ),
          if (!reveal)
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: Text(
                'Dokładny adres widoczny dopiero po podjęciu zgłoszenia.',
                style: TextStyle(
                    color: AppTheme.textSecondaryColor, fontSize: 13),
              ),
            ),
          if (reveal && senior != null) ...[
            const SizedBox(height: 8),
            Text(
              'Współrzędne: '
              '${senior.homeLocation.latitude.toStringAsFixed(5)}, '
              '${senior.homeLocation.longitude.toStringAsFixed(5)}',
              style: const TextStyle(
                  fontSize: 13, color: AppTheme.textSecondaryColor),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () => _openMaps(
                context,
                senior.homeLocation.latitude,
                senior.homeLocation.longitude,
              ),
              icon: const Icon(Icons.map_outlined),
              label: const Text('Pokaż na mapie / Nawiguj'),
            ),
          ],
        ],
      ),
    );
  }
}

class _Timeline extends StatelessWidget {
  final HelpTask task;
  const _Timeline({required this.task});

  String _fmt(DateTime? d) {
    if (d == null) return '—';
    final dd = d.toLocal();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(dd.day)}.${two(dd.month)}.${dd.year} ${two(dd.hour)}:${two(dd.minute)}';
  }

  @override
  Widget build(BuildContext context) {
    final rows = <_TimelineRow>[
      _TimelineRow(
        icon: Icons.add_circle_outline,
        color: AppTheme.primaryColor,
        label: 'Opublikowano',
        when: _fmt(task.createdAt),
      ),
      if (task.acceptedAt != null)
        _TimelineRow(
          icon: Icons.handshake_outlined,
          color: Colors.orangeAccent,
          label: 'Podjęte przez wolontariusza',
          when: _fmt(task.acceptedAt),
        ),
      if (task.completedAt != null)
        _TimelineRow(
          icon: Icons.check_circle_outline,
          color: AppTheme.textSecondaryColor,
          label: 'Wykonane',
          when: _fmt(task.completedAt),
        ),
      if (task.cancelledAt != null)
        _TimelineRow(
          icon: Icons.cancel_outlined,
          color: AppTheme.errorColor,
          label: task.cancelledBy != null
              ? 'Anulowane (${task.cancelledBy!.label})'
              : 'Anulowane',
          when: _fmt(task.cancelledAt),
          note: task.cancelReason,
        ),
    ];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(AppConstants.defaultBorderRadius),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Historia',
              style: TextStyle(
                  fontSize: 16, fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
          for (final r in rows) r,
        ],
      ),
    );
  }
}

class _TimelineRow extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final String when;
  final String? note;

  const _TimelineRow({
    required this.icon,
    required this.color,
    required this.label,
    required this.when,
    this.note,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: const TextStyle(fontWeight: FontWeight.w600)),
                Text(when,
                    style: const TextStyle(
                        fontSize: 13,
                        color: AppTheme.textSecondaryColor)),
                if (note != null && note!.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text('Powód: $note',
                      style: const TextStyle(
                          fontSize: 13,
                          color: AppTheme.textSecondaryColor,
                          fontStyle: FontStyle.italic)),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionButtons extends StatelessWidget {
  final TaskDetailViewModel vm;
  const _ActionButtons({required this.vm});

  Future<void> _confirmAndAccept(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Podjąć to zgłoszenie?'),
        content: const Text(
          'Senior zobaczy Twoje imię, telefon i dokładny adres. '
          'Po podjęciu skontaktuj się z seniorem i wykonaj pomoc.\n\n'
          'Tej akcji nie można cofnąć bez wskazania powodu.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Anuluj'),
          ),
          ElevatedButton.icon(
            onPressed: () => Navigator.of(ctx).pop(true),
            icon: const Icon(Icons.handshake),
            label: const Text('Pomagam'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await vm.accept();
  }

  Future<void> _confirmAndComplete(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Oznaczyć jako wykonane?'),
        content: const Text(
            'Czy pomoc została wykonana? Tej akcji nie można cofnąć.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Jeszcze nie'),
          ),
          ElevatedButton.icon(
            onPressed: () => Navigator.of(ctx).pop(true),
            icon: const Icon(Icons.done_all),
            label: const Text('Wykonane'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await vm.markDone();
  }

  Future<void> _confirmAndCancel(BuildContext context, {required bool asSenior}) async {
    final reason = await _askReason(
      context,
      title: asSenior ? 'Anulować zgłoszenie?' : 'Zrezygnować z zadania?',
      hint: asSenior
          ? 'Krótko opisz, dlaczego anulujesz (np. „już nie potrzebuję pomocy”)'
          : 'Krótko opisz, dlaczego rezygnujesz (np. „nie mogę dojechać”)',
      confirmLabel: asSenior ? 'Anuluj zgłoszenie' : 'Zrezygnuj',
    );
    if (reason == null || reason.trim().isEmpty) return;
    if (asSenior) {
      await vm.cancelBySenior(reason.trim());
    } else {
      await vm.withdrawAsVolunteer(reason.trim());
    }
  }

  Future<String?> _askReason(
    BuildContext context, {
    required String title,
    required String hint,
    required String confirmLabel,
  }) {
    final ctrl = TextEditingController();
    final formKey = GlobalKey<FormState>();
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Form(
          key: formKey,
          child: TextFormField(
            controller: ctrl,
            autofocus: true,
            minLines: 2,
            maxLines: 4,
            maxLength: InputLimits.cancelReason,
            inputFormatters: [
              LengthLimitingTextInputFormatter(InputLimits.cancelReason),
            ],
            decoration: InputDecoration(
              labelText: 'Powód',
              hintText: hint,
              border: const OutlineInputBorder(),
            ),
            validator: (v) {
              if (v == null || v.trim().isEmpty) return 'Powód jest wymagany';
              if (v.trim().length < 3) return 'Powód jest za krótki';
              return null;
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(null),
            child: const Text('Wróć'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.errorColor,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              if (formKey.currentState!.validate()) {
                Navigator.of(ctx).pop(ctrl.text.trim());
              }
            },
            child: Text(confirmLabel),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final task = vm.task!;
    final buttons = <Widget>[];

    // Volunteer: open → can accept
    if (!vm.isSenior && task.status == TaskStatus.open) {
      buttons.add(SizedBox(
        height: 56,
        child: ElevatedButton.icon(
          onPressed: vm.isBusy ? null : () => _confirmAndAccept(context),
          icon: const Icon(Icons.handshake),
          label: const Text('Pomagam'),
        ),
      ));
    }

    // Senior: open → can cancel
    if (vm.isSenior && task.status == TaskStatus.open) {
      buttons.add(SizedBox(
        height: 56,
        child: OutlinedButton.icon(
          style: OutlinedButton.styleFrom(
            foregroundColor: AppTheme.errorColor,
            side: const BorderSide(color: AppTheme.errorColor),
            minimumSize: const Size(double.infinity, 56),
          ),
          onPressed: vm.isBusy
              ? null
              : () => _confirmAndCancel(context, asSenior: true),
          icon: const Icon(Icons.cancel_outlined),
          label: const Text('Anuluj zgłoszenie'),
        ),
      ));
    }

    // Senior: in progress → can mark done OR cancel
    if (vm.isSenior && task.status == TaskStatus.inProgress) {
      buttons.add(SizedBox(
        height: 56,
        child: ElevatedButton.icon(
          onPressed:
              vm.isBusy ? null : () => _confirmAndComplete(context),
          icon: const Icon(Icons.done_all),
          label: const Text('Oznacz jako wykonane'),
        ),
      ));
      buttons.add(const SizedBox(height: 12));
      buttons.add(SizedBox(
        height: 56,
        child: OutlinedButton.icon(
          style: OutlinedButton.styleFrom(
            foregroundColor: AppTheme.errorColor,
            side: const BorderSide(color: AppTheme.errorColor),
            minimumSize: const Size(double.infinity, 56),
          ),
          onPressed: vm.isBusy
              ? null
              : () => _confirmAndCancel(context, asSenior: true),
          icon: const Icon(Icons.cancel_outlined),
          label: const Text('Anuluj zgłoszenie'),
        ),
      ));
    }

    // Volunteer responder: in progress → can withdraw
    if (vm.isResponder && task.status == TaskStatus.inProgress) {
      buttons.add(SizedBox(
        height: 56,
        child: OutlinedButton.icon(
          style: OutlinedButton.styleFrom(
            foregroundColor: AppTheme.errorColor,
            side: const BorderSide(color: AppTheme.errorColor),
            minimumSize: const Size(double.infinity, 56),
          ),
          onPressed: vm.isBusy
              ? null
              : () => _confirmAndCancel(context, asSenior: false),
          icon: const Icon(Icons.do_not_disturb_on_outlined),
          label: const Text('Zrezygnuj'),
        ),
      ));
    }

    if (buttons.isEmpty) {
      return const SizedBox.shrink();
    }
    return Column(children: buttons);
  }
}
