import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Deterministic colored initials avatar — no image assets needed, and
/// no risk of resembling any third-party illustration set.
class AppAvatar extends StatelessWidget {
  final String seed;
  final double size;

  const AppAvatar({super.key, required this.seed, this.size = 48});

  static const _palette = [
    AppColors.primary,
    Color(0xFFFFB020),
    Color(0xFF12B76A),
    Color(0xFF2E90FA),
    Color(0xFFF04438),
    Color(0xFF2ED3C6),
  ];

  @override
  Widget build(BuildContext context) {
    final trimmed = seed.trim();
    final initials = trimmed.isEmpty
        ? '?'
        : trimmed
            .split(RegExp(r'\s+'))
            .take(2)
            .map((w) => w.isNotEmpty ? w[0].toUpperCase() : '')
            .join();
    final color = _palette[trimmed.hashCode.abs() % _palette.length];

    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      child: Text(
        initials,
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w700,
          fontSize: size * 0.4,
        ),
      ),
    );
  }
}
