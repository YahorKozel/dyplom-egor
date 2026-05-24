import 'package:cloud_firestore/cloud_firestore.dart';

import 'task_category.dart';

enum TaskStatus {
  open,
  inProgress,
  done,
  cancelled;

  String toWire() => switch (this) {
        TaskStatus.open => 'OPEN',
        TaskStatus.inProgress => 'IN_PROGRESS',
        TaskStatus.done => 'DONE',
        TaskStatus.cancelled => 'CANCELLED',
      };

  static TaskStatus fromWire(String? value) => switch (value) {
        'IN_PROGRESS' => TaskStatus.inProgress,
        'DONE' => TaskStatus.done,
        'CANCELLED' => TaskStatus.cancelled,
        _ => TaskStatus.open,
      };

  String get label => switch (this) {
        TaskStatus.open => 'Otwarte',
        TaskStatus.inProgress => 'W trakcie',
        TaskStatus.done => 'Zrobione',
        TaskStatus.cancelled => 'Anulowane',
      };
}

enum CancelledBy {
  senior,
  volunteer;

  String toWire() => switch (this) {
        CancelledBy.senior => 'SENIOR',
        CancelledBy.volunteer => 'VOLUNTEER',
      };

  static CancelledBy? fromWire(String? value) => switch (value) {
        'SENIOR' => CancelledBy.senior,
        'VOLUNTEER' => CancelledBy.volunteer,
        _ => null,
      };

  String get label => switch (this) {
        CancelledBy.senior => 'Senior',
        CancelledBy.volunteer => 'Wolontariusz',
      };
}

class HelpTask {
  final String id;
  final String seniorId;
  final String title;
  final String description;
  final TaskCategory category;
  final TaskStatus status;
  final String? volunteerId;
  final CancelledBy? cancelledBy;
  final String? cancelReason;
  final DateTime? createdAt;
  final DateTime? acceptedAt;
  final DateTime? completedAt;
  final DateTime? cancelledAt;

  HelpTask({
    required this.id,
    required this.seniorId,
    required this.title,
    required this.description,
    required this.category,
    required this.status,
    this.volunteerId,
    this.cancelledBy,
    this.cancelReason,
    this.createdAt,
    this.acceptedAt,
    this.completedAt,
    this.cancelledAt,
  });

  Map<String, dynamic> toCreateMap() {
    return {
      'senior_id': seniorId,
      'title': title,
      'description': description,
      'category': category.toWire(),
      'status': status.toWire(),
      if (volunteerId != null) 'volunteer_id': volunteerId,
      'createdAt': FieldValue.serverTimestamp(),
    };
  }

  factory HelpTask.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return HelpTask(
      id: doc.id,
      seniorId: (data['senior_id'] as String?) ?? '',
      title: (data['title'] as String?) ?? '',
      description: (data['description'] as String?) ?? '',
      category: TaskCategory.fromWire(data['category'] as String?),
      status: TaskStatus.fromWire(data['status'] as String?),
      volunteerId: data['volunteer_id'] as String?,
      cancelledBy: CancelledBy.fromWire(data['cancelled_by'] as String?),
      cancelReason: data['cancel_reason'] as String?,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      acceptedAt: (data['acceptedAt'] as Timestamp?)?.toDate(),
      completedAt: (data['completedAt'] as Timestamp?)?.toDate(),
      cancelledAt: (data['cancelledAt'] as Timestamp?)?.toDate(),
    );
  }
}
