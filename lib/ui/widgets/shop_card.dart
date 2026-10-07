import 'package:flutter/material.dart';

import '../../domain/models/producers.dart';
import '../../utils/number_format.dart';
import '../theme/palette.dart';

/// One buyable row in the shop: title, effect, cost and a buy button.
class ShopCard extends StatelessWidget {
  const ShopCard({
    required this.name,
    required this.description,
    required this.costLabel,
    required this.canAfford,
    required this.onBuy,
    this.owned,
    this.lockedReason,
    super.key,
  });

  final String name;
  final String description;
  final String costLabel;
  final bool canAfford;
  final VoidCallback onBuy;

  /// "Owned xN" badge when repeatable; null for one-time items.
  final int? owned;

  /// When set, the item is hidden behind a gate (e.g. requires a parent branch).
  final String? lockedReason;

  @override
  Widget build(BuildContext context) {
    final enabled = canAfford && lockedReason == null;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Palette.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Palette.border),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        name,
                        style: const TextStyle(
                          color: Palette.ink,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    if (owned != null) ...[
                      const SizedBox(width: 8),
                      Text(
                        'x$owned',
                        style: const TextStyle(
                          color: Palette.action,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  description,
                  style: const TextStyle(color: Palette.inkSoft, fontSize: 12),
                ),
                if (lockedReason != null)
                  Text(
                    lockedReason!,
                    style: const TextStyle(color: Palette.warn, fontSize: 12),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          SizedBox(
            height: 36,
            child: FilledButton(
              onPressed: enabled ? onBuy : null,
              style: FilledButton.styleFrom(
                backgroundColor: Palette.action,
                foregroundColor: Palette.paper,
                disabledBackgroundColor: Palette.surfaceAlt,
                disabledForegroundColor: Palette.inkFaint,
                minimumSize: const Size(96, 36),
              ),
              child: Text(
                costLabel,
                style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Formats a cost in the currency it is paid with, e.g. `1.2K C`.
String formatCost(double amount, ResourceKind kind) =>
    '${formatNumber(amount)} ${kind.name[0].toUpperCase()}';
