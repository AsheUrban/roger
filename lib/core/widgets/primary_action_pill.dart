import 'package:flutter/material.dart';

import '../theme/colors.dart';

class PrimaryActionPill extends StatelessWidget {
  final String label;
  final bool enabled;
  final VoidCallback? onTap;

  const PrimaryActionPill({
    super.key,
    required this.label,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: enabled ? warmWhite : warmWhite.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: enabled ? charcoal : warmWhite.withValues(alpha: 0.3),
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
