// SPDX-License-Identifier: AGPL-3.0-only
import 'package:core/core.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// 店舗宛の申込み一覧(docs/05)。requested を上に。スタッフ全員で共有。
class ShopRequestsScreen extends StatefulWidget {
  const ShopRequestsScreen({super.key});

  @override
  State<ShopRequestsScreen> createState() => _ShopRequestsScreenState();
}

class _ShopRequestsScreenState extends State<ShopRequestsScreen> {
  List<TradeRequestEntry>? _entries;
  String? _error;

  static const _statusLabels = {
    'requested': '未対応',
    'accepted': '取引中',
    'declined': '辞退',
    'completed': '完了',
    'cancelled': '取下げ',
    'expired': '期限切れ',
  };

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _entries = null;
      _error = null;
    });
    try {
      final entries = await ApiClient.i.fetchShopRequests();
      if (mounted) setState(() => _entries = entries);
    } on ApiException catch (e) {
      if (mounted) {
        setState(() =>
            _error = e.code == 'NOT_SHOP_STAFF' ? '店舗アカウントが必要です' : 'メンテナンス中です');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final entries = _entries;
    return Scaffold(
      appBar: AppBar(title: const Text('申込み対応')),
      body: _error != null
          ? Center(
              child: TextButton(onPressed: _load, child: Text('$_error(再試行)')),
            )
          : entries == null
              ? const Center(child: CircularProgressIndicator())
              : entries.isEmpty
                  ? const Center(child: Text('申込みはまだありません'))
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: ListView.separated(
                        itemCount: entries.length,
                        separatorBuilder: (_, _) =>
                            const Divider(height: 1),
                        itemBuilder: (context, i) {
                          final entry = entries[i];
                          final request = entry.request;
                          final pending = request.status == 'requested';
                          return ListTile(
                            leading: pending
                                ? const Icon(Icons.circle,
                                    color: Colors.red, size: 12)
                                : null,
                            title: Text(
                                '${request.requestNo}(${entry.itemCount}品目)'),
                            subtitle:
                                Text(request.createdAt.substring(0, 10)),
                            trailing: Text(
                              _statusLabels[request.status] ?? request.status,
                              style: TextStyle(
                                color: pending
                                    ? Colors.red
                                    : SeedColors.green,
                              ),
                            ),
                            onTap: () =>
                                context.go('/requests/${request.id}'),
                          );
                        },
                      ),
                    ),
    );
  }
}
