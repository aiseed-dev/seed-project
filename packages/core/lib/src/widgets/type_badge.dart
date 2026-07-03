// SPDX-License-Identifier: MIT
import 'package:flutter/material.dart';

import '../constants.dart';

/// 種別バッジ(docs/10): 販売=橙 / 交換=緑 / 譲渡=青。
class TypeBadge extends StatelessWidget {
  const TypeBadge({super.key, required this.listingType});

  final String listingType;

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (listingType) {
      'sell' => ('販売', SeedColors.orange),
      'exchange' => ('交換', SeedColors.green),
      'give' => ('譲渡', SeedColors.blue),
      _ => (listingType, SeedColors.disabled),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(3),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: SeedColors.surface,
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

/// チップ(docs/10): 白地・緑枠・緑字(固定種 / 在来種 / 自家採種 等)。
class SeedChip extends StatelessWidget {
  const SeedChip({super.key, required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
        color: SeedColors.surface,
        border: Border.all(color: SeedColors.green),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: const TextStyle(color: SeedColors.green, fontSize: 11),
      ),
    );
  }
}
