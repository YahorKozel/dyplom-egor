import 'package:flutter/material.dart';

enum TaskCategory {
  shopping,
  repair,
  cleaning,
  garden,
  transport,
  technology,
  health,
  other;

  String toWire() => switch (this) {
        TaskCategory.shopping => 'SHOPPING',
        TaskCategory.repair => 'REPAIR',
        TaskCategory.cleaning => 'CLEANING',
        TaskCategory.garden => 'GARDEN',
        TaskCategory.transport => 'TRANSPORT',
        TaskCategory.technology => 'TECHNOLOGY',
        TaskCategory.health => 'HEALTH',
        TaskCategory.other => 'OTHER',
      };

  static TaskCategory fromWire(String? value) => switch (value) {
        'SHOPPING' => TaskCategory.shopping,
        'REPAIR' => TaskCategory.repair,
        'CLEANING' => TaskCategory.cleaning,
        'GARDEN' => TaskCategory.garden,
        'TRANSPORT' => TaskCategory.transport,
        'TECHNOLOGY' => TaskCategory.technology,
        'HEALTH' => TaskCategory.health,
        _ => TaskCategory.other,
      };

  String get label => switch (this) {
        TaskCategory.shopping => 'Zakupy',
        TaskCategory.repair => 'Naprawa',
        TaskCategory.cleaning => 'Sprzątanie',
        TaskCategory.garden => 'Dom i ogród',
        TaskCategory.transport => 'Transport',
        TaskCategory.technology => 'Technologia',
        TaskCategory.health => 'Zdrowie',
        TaskCategory.other => 'Inne',
      };

  IconData get icon => switch (this) {
        TaskCategory.shopping => Icons.shopping_cart_rounded,
        TaskCategory.repair => Icons.build_rounded,
        TaskCategory.cleaning => Icons.cleaning_services_rounded,
        TaskCategory.garden => Icons.yard_rounded,
        TaskCategory.transport => Icons.directions_car_rounded,
        TaskCategory.technology => Icons.devices_rounded,
        TaskCategory.health => Icons.health_and_safety_rounded,
        TaskCategory.other => Icons.help_outline_rounded,
      };
}
