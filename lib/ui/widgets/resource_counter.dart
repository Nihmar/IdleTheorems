import 'package:flutter/material.dart';

import '../../utils/number_format.dart';
import '../theme/palette.dart';

/// One resource readout in the HUD: name, current balance and rate/s.
class ResourceCounter extends StatelessWidget {
  const ResourceCounter({
    required this.label,
    required this.icon,
    required this.value,
    required this.perSecond,
    super.key,
  });

  final String label;
  final IconData icon;
  final double value;
  final double perSecond;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Palette.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Palette.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 14, color: Palette.inkSoft),
              const SizedBox(width: 6),
              Text(
                label,
                style: const TextStyle(color: Palette.inkSoft, fontSize: 12),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            formatNumber(value),
            style: const TextStyle(
              fontFamily: 'monospace',
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Palette.ink,
            ),
          ),
          Text(
            '+${formatRate(perSecond)}',
            style: const TextStyle(
              fontFamily: 'monospace',
              fontSize: 11,
              color: Palette.inkSoft,
            ),
          ),
        ],
      ),
    );
  }
}
