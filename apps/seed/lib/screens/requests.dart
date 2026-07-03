// SPDX-License-Identifier: AGPL-3.0-only
import 'package:core/core.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// 申込み一覧(docs/04 RequestListScreen)。「申込んだ」「受けた」タブ。
class RequestListScreen extends StatefulWidget {
  const RequestListScreen({super.key});

  @override
  State<RequestListScreen> createState() => _RequestListScreenState();
}

class _RequestListScreenState extends State<RequestListScreen> {
  List<TradeRequestEntry>? _entries; // null=読込中
  String? _error;

  static const _statusLabels = {
    'requested': '申込み中',
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
      final entries = await ApiClient.i.fetchRequests();
      if (mounted) setState(() => _entries = entries);
    } on ApiException catch (e) {
      if (mounted) {
        setState(() => _error = e.status == 401 ? 'ログインが必要です' : 'メンテナンス中です');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final entries = _entries;
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('申込み'),
          bottom: const TabBar(tabs: [Tab(text: '申込んだ'), Tab(text: '受けた')]),
        ),
        body: _error != null
            ? Center(
                child: TextButton(onPressed: _load, child: Text('$_error(再試行)')),
              )
            : entries == null
                ? const Center(child: CircularProgressIndicator())
                : TabBarView(
                    children: [
                      _list(entries.where((e) => e.role == 'requester')),
                      _list(entries.where((e) => e.role == 'provider')),
                    ],
                  ),
      ),
    );
  }

  Widget _list(Iterable<TradeRequestEntry> entries) {
    final list = entries.toList();
    if (list.isEmpty) {
      return const Center(child: Text('まだありません'));
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.separated(
        itemCount: list.length,
        separatorBuilder: (_, _) => const Divider(height: 1),
        itemBuilder: (context, i) {
          final entry = list[i];
          final request = entry.request;
          return ListTile(
            title: Text('${request.requestNo}(${entry.itemCount}品目)'),
            subtitle: entry.lastMessage != null
                ? Text(entry.lastMessage!,
                    maxLines: 1, overflow: TextOverflow.ellipsis)
                : null,
            // 状態バッジはデザインの文字
            trailing: DesignText(
              _statusLabels[request.status] ?? request.status,
              size: 13,
              color: SeedColors.green,
            ),
            onTap: () => context.go('/requests/${request.id}'),
          );
        },
      ),
    );
  }
}
