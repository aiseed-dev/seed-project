// SPDX-License-Identifier: MIT
import 'package:flutter/material.dart';

import '../constants.dart';
import '../models.dart';
import 'type_badge.dart';

/// 出品カード(docs/10「出品カードの解剖」の簡略適用。全アプリ共通)。
///
/// 写真+種別バッジ / 品種名 / チップ / スペック行 / 条件行 の順。
/// 写真配信は Phase 5a(静的配信)まではプレースホルダ。
class ListingCard extends StatelessWidget {
  const ListingCard({super.key, required this.listing, this.onTap});

  final Listing listing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: SeedColors.surface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(6),
        side: const BorderSide(color: Color(0xFFE3DDCD)),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _photo(),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      listing.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 4,
                      runSpacing: 2,
                      children: [
                        if (listing.isSelfSaved)
                          const SeedChip(label: '自家採種'),
                        if (listing.region != null)
                          SeedChip(label: listing.region!),
                      ],
                    ),
                    const SizedBox(height: 4),
                    // 高さが足りないカードではスペック行を切り詰める
                    Expanded(
                      child: SingleChildScrollView(
                        physics: const NeverScrollableScrollPhysics(),
                        child: _specs(),
                      ),
                    ),
                    const SizedBox(height: 4),
                    _condition(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _photo() {
    return AspectRatio(
      aspectRatio: 4 / 3,
      child: Stack(
        children: [
          Container(
            color: const Color(0xFFEFEBDE),
            alignment: Alignment.center,
            width: double.infinity,
            child: const Icon(Icons.grass, color: SeedColors.disabled, size: 40),
          ),
          Positioned(
            top: 6,
            left: 6,
            child: TypeBadge(listingType: listing.listingType),
          ),
        ],
      ),
    );
  }

  /// 業者品は発芽率、個人品は同じ位置に無保証注記(docs/10 の対照)。
  Widget _specs() {
    const label = TextStyle(color: SeedColors.disabled, fontSize: 11);
    const value = TextStyle(color: SeedColors.ink, fontSize: 11);
    final rows = <(String, String)>[
      if (listing.quantityNote != null) ('内容量', listing.quantityNote!),
      if (listing.harvestYear != null) ('採種年', '${listing.harvestYear}年'),
      if (listing.requiresSeedLabel &&
          listing.labelGerminationRate != null)
        ('発芽率', listing.labelGerminationRate!),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final (k, v) in rows)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(width: 44, child: Text(k, style: label)),
              Expanded(
                child: Text(v,
                    style: value, maxLines: 1, overflow: TextOverflow.ellipsis),
              ),
            ],
          ),
        if (listing.noWarranty && !listing.requiresSeedLabel)
          const Text('家庭採種・発芽保証なし', style: label),
      ],
    );
  }

  Widget _condition() {
    switch (listing.listingType) {
      case 'sell':
        return Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              '${listing.priceYen ?? "-"}円',
              style: const TextStyle(
                color: SeedColors.orange,
                fontWeight: FontWeight.bold,
                fontSize: 15,
              ),
            ),
            const SizedBox(width: 4),
            const Text('送料別',
                style: TextStyle(color: SeedColors.disabled, fontSize: 10)),
          ],
        );
      case 'exchange':
        return Text(
          '希望: ${listing.desiredTrade ?? "相談"}',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(color: SeedColors.green, fontSize: 12),
        );
      default:
        return const Text(
          '無償でお譲りします(送料別)',
          style: TextStyle(color: SeedColors.blue, fontSize: 12),
        );
    }
  }
}
