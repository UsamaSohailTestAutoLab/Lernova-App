import 'package:flutter/material.dart';

import 'app_metric.dart';

/// A single dashboard metric: icon, big value, small label. Shared by
/// the Home dashboard and the Statistics screen so both render the same
/// numbers the same way. A thin delegate onto [AppMetric].
class StatCard extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final String value;

  /// Full-colour glyph shown instead of [icon] — see
  /// [AppMetricData.emoji].
  final String? emoji;

  final VoidCallback? onTap;

  const StatCard({
    super.key,
    required this.icon,
    required this.color,
    required this.label,
    required this.value,
    this.emoji,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return AppMetric(
      data: AppMetricData(
        icon: icon,
        color: color,
        label: label,
        value: value,
        emoji: emoji,
      ),
      onTap: onTap,
    );
  }
}
