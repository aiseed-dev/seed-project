// SPDX-License-Identifier: AGPL-3.0-only
import 'package:core/core.dart';
import 'package:flutter/material.dart';

/// 指定種苗の表示欄(docs/04 手順8)。種苗業者スイッチ ON のとき必須。
class SeedLabelFields extends StatelessWidget {
  const SeedLabelFields({
    super.key,
    required this.enabled,
    required this.onToggle,
    required this.sellerName,
    required this.sellerAddress,
    required this.productionArea,
    required this.germinationRate,
    required this.seedTreatment,
    required this.isSeed,
  });

  final bool enabled;
  final ValueChanged<bool> onToggle;
  final TextEditingController sellerName;
  final TextEditingController sellerAddress;
  final TextEditingController productionArea;
  final TextEditingController germinationRate;
  final TextEditingController seedTreatment;
  final bool isSeed;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('反復継続して販売しています(種苗業者に該当)'),
          subtitle: const Text(
            '該当する場合は種苗法22条の表示義務があります',
            style: TextStyle(fontSize: 11),
          ),
          value: enabled,
          onChanged: onToggle,
        ),
        if (!enabled)
          const Text(
            '個人の家庭採種品として「発芽保証なし」の注記が付きます',
            style: TextStyle(fontSize: 11, color: SeedColors.disabled),
          ),
        if (enabled) ...[
          const SizedBox(height: 8),
          TextField(
            controller: sellerName,
            decoration: const InputDecoration(
                labelText: '表示者の氏名/名称(必須)', border: OutlineInputBorder()),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: sellerAddress,
            decoration: const InputDecoration(
                labelText: '表示者の住所(必須)', border: OutlineInputBorder()),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: productionArea,
            decoration: const InputDecoration(
                labelText: '生産地(都道府県・必須)', border: OutlineInputBorder()),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: germinationRate,
            decoration: InputDecoration(
              labelText: isSeed ? '発芽率(種子は必須)' : '発芽率(苗は不要)',
              hintText: '例: 2026年6月現在 80%以上',
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: seedTreatment,
            decoration: const InputDecoration(
              labelText: '種子消毒等の薬剤処理(任意)',
              hintText: '例: 無処理',
              border: OutlineInputBorder(),
            ),
          ),
        ],
      ],
    );
  }
}
