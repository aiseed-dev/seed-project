// SPDX-License-Identifier: AGPL-3.0-only
import 'package:core/core.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../config.dart';

/// 出品管理(docs/05)。モバイル=カード+長押し選択 / ワイド=テーブル。
class ShopListingsScreen extends StatefulWidget {
  const ShopListingsScreen({super.key});

  @override
  State<ShopListingsScreen> createState() => _ShopListingsScreenState();
}

class _ShopListingsScreenState extends State<ShopListingsScreen> {
  List<Listing>? _listings;
  final Set<String> _selected = {};
  String _filter = 'all';
  String? _error;

  static const _statusLabels = {
    'active': '公開中',
    'closed': '終了',
    'suspended': '停止',
    'reserved': '取引中',
  };

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _listings = null;
      _error = null;
      _selected.clear();
    });
    try {
      final listings = await ApiClient.i.fetchShopListings();
      if (mounted) setState(() => _listings = listings);
    } on ApiException catch (e) {
      if (mounted) {
        setState(() =>
            _error = e.code == 'NOT_SHOP_STAFF' ? '店舗アカウントが必要です' : 'メンテナンス中です');
      }
    }
  }

  List<Listing> get _visible {
    final listings = _listings ?? [];
    if (_filter == 'all') return listings;
    return listings.where((l) => l.status == _filter).toList();
  }

  Future<void> _bulk(String action) async {
    int? price;
    if (action == 'price') {
      final controller = TextEditingController();
      price = await showDialog<int>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('新しい価格(円)'),
          content: TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              autofocus: true),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('やめる')),
            FilledButton(
              onPressed: () =>
                  Navigator.pop(context, int.tryParse(controller.text)),
              child: const Text('変更する'),
            ),
          ],
        ),
      );
      if (price == null) return;
    }
    if (!mounted) return;
    try {
      final updated = await ApiClient.i
          .bulkListings(_selected.toList(), action, priceYen: price);
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('$updated 件を更新しました')));
      }
      await _load();
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= wideBreakpoint;
        return Scaffold(
          appBar: AppBar(
            title: const Text('出品管理'),
            actions: [
              if (wide) ...[
                TextButton(
                  onPressed: () => context.go('/import'),
                  child: const Text('CSV取込'),
                ),
                TextButton(
                  onPressed: () => _showExport(context),
                  child: const Text('エクスポート'),
                ),
              ] else
                PopupMenuButton<String>(
                  itemBuilder: (context) => const [
                    PopupMenuItem(
                      enabled: false,
                      child: Text('CSV取込・エクスポートはWeb版で利用できます'),
                    ),
                  ],
                ),
            ],
          ),
          bottomNavigationBar:
              _selected.isNotEmpty && !wide ? _actionBar() : null,
          body: _error != null
              ? Center(
                  child:
                      TextButton(onPressed: _load, child: Text('$_error(再試行)')),
                )
              : _listings == null
                  ? const Center(child: CircularProgressIndicator())
                  : Column(
                      children: [
                        _filterBar(),
                        if (_selected.isNotEmpty && wide) _actionBar(),
                        Expanded(
                          child: wide ? _table() : _cards(),
                        ),
                      ],
                    ),
        );
      },
    );
  }

  Widget _filterBar() {
    return Padding(
      padding: const EdgeInsets.all(8),
      child: Wrap(
        spacing: 6,
        children: [
          for (final (value, label) in [
            ('all', 'すべて'),
            ('active', '公開中'),
            ('suspended', '停止'),
            ('closed', '終了'),
          ])
            ChoiceChip(
              label: Text(label),
              selected: _filter == value,
              onSelected: (_) => setState(() => _filter = value),
            ),
        ],
      ),
    );
  }

  Widget _actionBar() {
    return Material(
      color: SeedColors.surface,
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Wrap(
          spacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text('${_selected.length} 件選択'),
            FilledButton(
                onPressed: () => _bulk('publish'), child: const Text('公開')),
            OutlinedButton(
                onPressed: () => _bulk('close'), child: const Text('停止')),
            OutlinedButton(
                onPressed: () => _bulk('price'), child: const Text('価格変更')),
            TextButton(
              onPressed: () => setState(() => _selected.clear()),
              child: const Text('選択解除'),
            ),
          ],
        ),
      ),
    );
  }

  void _toggle(String id) {
    setState(() {
      if (!_selected.remove(id)) _selected.add(id);
    });
  }

  Widget _cards() {
    return ListView(
      padding: const EdgeInsets.all(8),
      children: [
        for (final listing in _visible)
          Card(
            color: _selected.contains(listing.id)
                ? const Color(0xFFE9EEDC)
                : SeedColors.surface,
            elevation: 0,
            child: ListTile(
              onLongPress: () => _toggle(listing.id),
              onTap: _selected.isNotEmpty ? () => _toggle(listing.id) : null,
              title: Text(listing.title),
              subtitle: DesignText(
                '${listing.priceYen ?? "-"}円・${_statusLabels[listing.status]}',
                size: 12,
                color: SeedColors.disabled,
              ),
              trailing: _selected.contains(listing.id)
                  ? const Icon(Icons.check_circle, color: SeedColors.green)
                  : null,
            ),
          ),
      ],
    );
  }

  Widget _table() {
    return SingleChildScrollView(
      child: DataTable(
        columns: const [
          DataColumn(label: Text('品種名')),
          DataColumn(label: Text('価格')),
          DataColumn(label: Text('状態')),
          DataColumn(label: Text('更新日')),
        ],
        rows: [
          for (final listing in _visible)
            DataRow(
              selected: _selected.contains(listing.id),
              onSelectChanged: (_) => _toggle(listing.id),
              cells: [
                DataCell(Text(listing.varietyNameFree ?? listing.title)),
                DataCell(DesignText('${listing.priceYen ?? "-"}円',
                    size: 13, color: SeedColors.orange)),
                DataCell(DesignText(
                    _statusLabels[listing.status] ?? listing.status,
                    size: 13)),
                DataCell(DesignText(listing.createdAt.substring(0, 10),
                    size: 13)),
              ],
            ),
        ],
      ),
    );
  }

  void _showExport(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('エクスポート'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('下記URLをブラウザで開くとダウンロードできます(要ログイン)。'),
            const SizedBox(height: 8),
            for (final (kind, label) in [
              ('listings', '出品一覧'),
              ('deals', '成約台帳'),
            ])
              for (final format in ['xlsx', 'csv'])
                SelectableText(
                  '$label($format): ${ApiClient.i.exportUrl(kind, format)}',
                  style: const TextStyle(fontSize: 12),
                ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('閉じる'),
          ),
        ],
      ),
    );
  }
}
