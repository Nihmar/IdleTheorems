import 'package:flutter/material.dart';

import '../../utils/number_format.dart';

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
        color: Colors.black.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 14, color: Colors.white70),
              const SizedBox(width: 6),
              Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12)),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            formatNumber(value),
            style: const TextStyle(
              fontFamily: 'monospace',
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          Text(
            '+${formatRate(perSecond)}',
            style: const TextStyle(fontFamily: 'monospace', fontSize: 11, color: Colors.white54),
          ),
        ],
      ),
    );
  }
}
