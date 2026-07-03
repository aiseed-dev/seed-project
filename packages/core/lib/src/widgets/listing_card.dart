// SPDX-License-Identifier: MIT
import 'package:flutter/material.dart';

import '../constants.dart';
import '../models.dart';
import 'design_text.dart';
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
                    // 高さが足りないカード(文字サイズ設定拡大時など)では
                    // チップとスペック行を静かに切り詰める(条件行は常に残す)
                    Expanded(
                      child: SingleChildScrollView(
                        physics: const NeverScrollableScrollPhysics(),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
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
                            _specs(),
                          ],
                        ),
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
  /// スペック行は「デザインの文字」: サイズ設定に影響されない(整列が核)。
  Widget _specs() {
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
              SizedBox(
                width: 44,
                child: DesignText(k, size: 11, color: SeedColors.disabled),
              ),
              Expanded(
                child: DesignText(v,
                    size: 11,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
              ),
            ],
          ),
        if (listing.noWarranty && !listing.requiresSeedLabel)
          const DesignText('家庭採種・発芽保証なし',
              size: 11, color: SeedColors.disabled),
      ],
    );
  }

  /// 条件行(価格等)も「デザインの文字」。
  Widget _condition() {
    switch (listing.listingType) {
      case 'sell':
        return Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            DesignText('${listing.priceYen ?? "-"}円',
                size: 15, color: SeedColors.orange, bold: true),
            const SizedBox(width: 4),
            const DesignText('送料別', size: 10, color: SeedColors.disabled),
          ],
        );
      case 'exchange':
        return DesignText(
          '希望: ${listing.desiredTrade ?? "相談"}',
          size: 12,
          color: SeedColors.green,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        );
      default:
        return const DesignText(
          '無償でお譲りします(送料別)',
          size: 12,
          color: SeedColors.blue,
        );
    }
  }
}
