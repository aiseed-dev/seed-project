// SPDX-License-Identifier: AGPL-3.0-only
import 'package:core/core.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// ダッシュボード(docs/05)。公開中出品数・未対応件数・直近の申込み。
class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  ShopInfo? _shop;
  List<Listing>? _listings;
  List<TradeRequestEntry>? _requests;
  bool _needsLabel = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (!Session.instance.isLoggedIn) {
      setState(() => _error = 'ログインしてください');
      return;
    }
    setState(() {
      _error = null;
      _listings = null;
    });
    try {
      final shop = await ApiClient.i.fetchShop();
      final listings = await ApiClient.i.fetchShopListings();
      final requests = await ApiClient.i.fetchShopRequests();
      final members = await ApiClient.i.fetchShopMembers();
      final mine = members
          .where((m) => m.userId == Session.instance.userId)
          .toList();
      if (mounted) {
        setState(() {
          _shop = shop;
          _listings = listings;
          _requests = requests;
          _needsLabel = mine.isNotEmpty && mine.first.contactLabel == null;
        });
      }
    } on ApiException catch (e) {
      if (mounted) {
        setState(() => _error = switch (e.code) {
              'NOT_SHOP_STAFF' => '店舗アカウントが必要です。運営(info@tanenomori.org)までご連絡ください',
              'SHOP_INACTIVE' => '店舗契約が有効ではありません',
              _ => e.status == 401 ? 'ログインしてください' : 'メンテナンス中です',
            });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      final needsLogin = _error!.contains('ログイン');
      return Scaffold(
        appBar: AppBar(title: const Text('ダッシュボード')),
        body: Center(
          child: TextButton(
            onPressed: needsLogin ? () => context.go('/login') : _load,
            child: Text(_error!),
          ),
        ),
      );
    }
    final listings = _listings;
    final requests = _requests;
    if (listings == null || requests == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('ダッシュボード')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    final active = listings.where((l) => l.status == 'active').length;
    final pending =
        requests.where((r) => r.request.status == 'requested').length;
    return Scaffold(
      appBar: AppBar(title: Text(_shop?.name ?? 'ダッシュボード')),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (_needsLabel)
              Card(
                color: const Color(0xFFFFF4E2),
                child: ListTile(
                  leading:
                      const Icon(Icons.badge_outlined, color: SeedColors.orange),
                  title: const Text('担当者名を登録してください'),
                  subtitle: const Text('申込み対応時に「誰が対応したか」の記録に使います'),
                  onTap: () => context.go('/settings'),
                ),
              ),
            Row(
              children: [
                _stat('公開中の出品', '$active 件', SeedColors.green),
                const SizedBox(width: 8),
                _stat(
                  '未対応の申込み',
                  '$pending 件',
                  pending > 0 ? Colors.red : SeedColors.disabled,
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Text('直近の申込み',
                style: TextStyle(fontWeight: FontWeight.bold)),
            for (final entry in requests.take(5))
              ListTile(
                title: Text(
                    '${entry.request.requestNo}(${entry.itemCount}品目)'),
                trailing: Text(entry.request.status),
                onTap: () => context.go('/requests/${entry.request.id}'),
              ),
            if (requests.isEmpty)
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text('申込みはまだありません'),
              ),
          ],
        ),
      ),
    );
  }

  Widget _stat(String label, String value, Color color) {
    return Expanded(
      child: Card(
        color: SeedColors.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(6),
          side: const BorderSide(color: Color(0xFFE3DDCD)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(fontSize: 12)),
              const SizedBox(height: 4),
              Text(value,
                  style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: color)),
            ],
          ),
        ),
      ),
    );
  }
}
