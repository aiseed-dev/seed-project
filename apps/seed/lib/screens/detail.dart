// SPDX-License-Identifier: AGPL-3.0-only
import 'package:core/core.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// 出品詳細(docs/04 ListingDetailScreen)。数量+「カートに入れる」付き。
class ListingDetailScreen extends StatefulWidget {
  const ListingDetailScreen({super.key, required this.listingId});

  final String listingId;

  @override
  State<ListingDetailScreen> createState() => _ListingDetailScreenState();
}

class _ListingDetailScreenState extends State<ListingDetailScreen> {
  Listing? _listing; // null=読込中
  String? _error;
  int _quantity = 1;
  bool _adding = false;

  Future<void> _addToCart() async {
    if (!Session.instance.isLoggedIn) {
      context.go('/login');
      return;
    }
    setState(() => _adding = true);
    try {
      await ApiClient.i.putCartItem(widget.listingId, _quantity);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('カートに追加しました')),
        );
      }
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message)),
        );
      }
    } finally {
      if (mounted) setState(() => _adding = false);
    }
  }

  Widget _bottomBar(Listing listing) {
    if (listing.status != 'active') {
      return Container(
        padding: const EdgeInsets.all(12),
        color: SeedColors.disabled,
        child: Text(
          listing.status == 'closed' ? '終了しました' : 'ただいま取引中です',
          textAlign: TextAlign.center,
          style: const TextStyle(color: SeedColors.surface),
        ),
      );
    }
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
        child: Row(
          children: [
            if (listing.listingType == 'sell') ...[
              IconButton(
                onPressed: _quantity > 1
                    ? () => setState(() => _quantity--)
                    : null,
                icon: const Icon(Icons.remove_circle_outline),
              ),
              Text('$_quantity'),
              IconButton(
                onPressed: () => setState(() => _quantity++),
                icon: const Icon(Icons.add_circle_outline),
              ),
              const SizedBox(width: 8),
            ],
            Expanded(
              child: FilledButton(
                onPressed: _adding ? null : _addToCart,
                child: const Text('カートに入れる'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _listing = null;
      _error = null;
    });
    try {
      final listing = await ApiClient.i.fetchListing(widget.listingId);
      if (mounted) setState(() => _listing = listing);
    } on ApiException catch (e) {
      if (mounted) {
        setState(
            () => _error = e.status == 404 ? '出品が見つかりません' : 'メンテナンス中です');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final listing = _listing;
    return Scaffold(
      appBar: AppBar(
        title: const Text('出品詳細'),
        actions: [
          if (listing != null)
            PopupMenuButton<String>(
              onSelected: (_) => _report(listing),
              itemBuilder: (context) => const [
                PopupMenuItem(value: 'report', child: Text('通報する')),
              ],
            ),
        ],
      ),
      bottomNavigationBar: listing == null ? null : _bottomBar(listing),
      body: _error != null
          ? Center(
              child: TextButton(onPressed: _load, child: Text('$_error(再試行)')),
            )
          : listing == null
              ? const Center(child: CircularProgressIndicator())
              : ListView(
                  children: [
                    PhotoCarousel(photos: listing.photos),
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              TypeBadge(listingType: listing.listingType),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  listing.title,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 18,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          _condition(listing),
                          const SizedBox(height: 12),
                          _varietyTile(listing),
                          const Divider(),
                          if (listing.description.isNotEmpty) ...[
                            Text(listing.description),
                            const SizedBox(height: 12),
                          ],
                          _specTable(listing),
                          if (listing.requiresSeedLabel) _seedLabel(listing),
                          if (listing.noWarranty &&
                              !listing.requiresSeedLabel)
                            const Padding(
                              padding: EdgeInsets.only(top: 12),
                              child: Text(
                                '家庭採種品です。発芽・生育は保証されません。',
                                style: TextStyle(
                                    color: SeedColors.disabled, fontSize: 12),
                              ),
                            ),
                          const Divider(),
                          _sellerTile(listing),
                          const SizedBox(height: 8),
                          const Text(
                            '支払い方法・送料は申込み後のメッセージで当事者間により協議します。',
                            style: TextStyle(
                                color: SeedColors.disabled, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
    );
  }

  Widget _condition(Listing listing) {
    switch (listing.listingType) {
      case 'sell':
        return Text(
          '${listing.priceYen}円(送料別)',
          style: const TextStyle(
            color: SeedColors.orange,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        );
      case 'exchange':
        return Text(
          '希望: ${listing.desiredTrade ?? "相談"}',
          style: const TextStyle(color: SeedColors.green, fontSize: 16),
        );
      default:
        return const Text(
          '無償でお譲りします(送料別)',
          style: TextStyle(color: SeedColors.blue, fontSize: 16),
        );
    }
  }

  /// VarietyInfoTile: 品種マスタ紐付けありなら辞典へ、自由入力なら準備中。
  Widget _varietyTile(Listing listing) {
    final name = listing.varietyNameFree ?? '品種情報';
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: const Icon(Icons.menu_book, color: SeedColors.green),
      title: Text(name),
      subtitle: Text(
        listing.varietyId != null ? '辞典で栽培方法を見る' : '辞典準備中(品種マスタ承認待ち)',
        style: const TextStyle(fontSize: 12),
      ),
      onTap: listing.varietyId != null
          ? () => context.go('/v/${listing.varietyId}')
          : null,
    );
  }

  Widget _specTable(Listing listing) {
    const label = TextStyle(color: SeedColors.disabled, fontSize: 12);
    final rows = <(String, String)>[
      if (listing.quantityNote != null) ('内容量', listing.quantityNote!),
      if (listing.harvestYear != null) ('採種年', '${listing.harvestYear}年'),
      if (listing.isSelfSaved) ('採種', '自家採種'),
      if (listing.region != null) ('地域', listing.region!),
      ('受け渡し', listing.deliveryMethod == 'mail' ? '郵送' : '直接'),
      (
        '支払い',
        switch (listing.paymentDefault) {
          'prepay' => '前払い',
          'cod' => '着払い',
          _ => '後払い(既定)',
        }
      ),
      if (listing.cultivationNote != null) ('栽培メモ', listing.cultivationNote!),
    ];
    return Column(
      children: [
        for (final (k, v) in rows)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(width: 80, child: Text(k, style: label)),
                Expanded(child: Text(v)),
              ],
            ),
          ),
      ],
    );
  }

  /// 指定種苗表示(種苗法22条)を1枠にまとめて表示。
  Widget _seedLabel(Listing listing) {
    const label = TextStyle(color: SeedColors.disabled, fontSize: 12);
    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: SeedColors.green),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('指定種苗表示',
              style: TextStyle(
                  color: SeedColors.green, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          for (final (k, v) in <(String, String?)>[
            ('氏名/名称', listing.labelSellerName),
            ('住所', listing.labelSellerAddress),
            ('生産地', listing.labelProductionArea),
            ('発芽率', listing.labelGerminationRate),
            ('薬剤処理', listing.labelSeedTreatment),
          ])
            if (v != null)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(width: 80, child: Text(k, style: label)),
                  Expanded(child: Text(v)),
                ],
              ),
        ],
      ),
    );
  }

  /// 通報UI(事後審査方式の入口)。
  Future<void> _report(Listing listing) async {
    if (!Session.instance.isLoggedIn) {
      context.go('/login');
      return;
    }
    final reason = await showDialog<String>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('通報の理由'),
        children: [
          for (final (value, label) in [
            ('registered_variety', '登録品種の疑い'),
            ('spam', 'スパム・宣伝'),
            ('fraud', '詐欺の疑い'),
            ('other', 'その他'),
          ])
            SimpleDialogOption(
              onPressed: () => Navigator.pop(context, value),
              child: Text(label),
            ),
        ],
      ),
    );
    if (reason == null || !mounted) return;
    try {
      await ApiClient.i.postReport(
        targetType: 'listing',
        targetId: listing.id,
        reason: reason,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('通報を受け付けました')),
        );
      }
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
  }

  /// SellerTile(評価は Phase 3 で表示)。
  Widget _sellerTile(Listing listing) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: const CircleAvatar(
        backgroundColor: SeedColors.green,
        child: Icon(Icons.person, color: SeedColors.surface),
      ),
      title: Text(listing.region != null ? '出品者(${listing.region})' : '出品者'),
      subtitle: const Text('評価は準備中です', style: TextStyle(fontSize: 12)),
    );
  }
}
