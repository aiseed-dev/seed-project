// SPDX-License-Identifier: AGPL-3.0-only
import 'dart:async';

import 'package:core/core.dart';
import 'package:flutter/material.dart';

/// 申込み詳細(docs/05)。申込番号・品目・小計 → 承諾/辞退 → メッセージ → 完了。
/// 承諾すると自分の担当名(contact_label)がサーバー側で記録される。
class ShopRequestScreen extends StatefulWidget {
  const ShopRequestScreen({super.key, required this.requestId});

  final String requestId;

  @override
  State<ShopRequestScreen> createState() => _ShopRequestScreenState();
}

class _ShopRequestScreenState extends State<ShopRequestScreen> {
  TradeRequest? _request;
  List<Message> _messages = [];
  String? _error;
  Timer? _poll;
  final _body = TextEditingController();
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _load();
    _poll = Timer.periodic(const Duration(seconds: 10), (_) => _load());
  }

  @override
  void dispose() {
    _poll?.cancel();
    _body.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final request = await ApiClient.i.fetchRequest(widget.requestId);
      final messages = await ApiClient.i.fetchMessages(widget.requestId);
      if (mounted) {
        setState(() {
          _request = request;
          _messages = messages;
          _error = null;
        });
      }
    } on ApiException catch (e) {
      if (mounted && _request == null) {
        setState(() =>
            _error = e.status == 404 ? '申込みが見つかりません' : 'メンテナンス中です');
      }
    }
  }

  Future<void> _patch(String status) async {
    try {
      await ApiClient.i.patchRequest(widget.requestId, status);
      await _load();
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
  }

  Future<void> _send() async {
    final text = _body.text.trim();
    if (text.isEmpty) return;
    setState(() => _sending = true);
    try {
      await ApiClient.i.postMessage(widget.requestId, text);
      _body.clear();
      await _load();
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  int get _subtotal => _request?.items.fold<int>(
          0, (sum, item) => sum + (item.priceYen ?? 0) * item.quantity) ??
      0;

  @override
  Widget build(BuildContext context) {
    final request = _request;
    return Scaffold(
      appBar: AppBar(title: Text(request?.requestNo ?? '申込み')),
      body: _error != null
          ? Center(child: Text(_error!))
          : request == null
              ? const Center(child: CircularProgressIndicator())
              : Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          for (final item in request.items)
                            Row(
                              children: [
                                Expanded(child: Text(item.title)),
                                Text(
                                  item.priceYen != null
                                      ? '¥${item.priceYen} × ${item.quantity}'
                                      : '× ${item.quantity}',
                                ),
                              ],
                            ),
                          const Divider(),
                          Row(
                            children: [
                              const Expanded(
                                  child: Text('小計(送料別)',
                                      style: TextStyle(
                                          fontWeight: FontWeight.bold))),
                              Text('¥$_subtotal',
                                  style: const TextStyle(
                                      color: SeedColors.orange,
                                      fontWeight: FontWeight.bold)),
                            ],
                          ),
                          const SizedBox(height: 8),
                          if (request.status == 'requested')
                            Wrap(
                              spacing: 8,
                              children: [
                                FilledButton(
                                  onPressed: () => _patch('accepted'),
                                  child: const Text('承諾する'),
                                ),
                                OutlinedButton(
                                  onPressed: () => _patch('declined'),
                                  child: const Text('辞退する'),
                                ),
                              ],
                            ),
                          if (request.status == 'accepted')
                            FilledButton(
                              onPressed: () => _patch('completed'),
                              child: const Text('完了にする(成約日を記録)'),
                            ),
                        ],
                      ),
                    ),
                    const Divider(height: 1),
                    Expanded(
                      child: ListView(
                        padding: const EdgeInsets.all(12),
                        children: [
                          for (final message in _messages)
                            _bubble(message),
                        ],
                      ),
                    ),
                    SafeArea(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
                        child: Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _body,
                                decoration: const InputDecoration(
                                  hintText: '支払い・発送のやり取り',
                                  border: OutlineInputBorder(),
                                  isDense: true,
                                ),
                              ),
                            ),
                            IconButton(
                              onPressed: _sending ? null : _send,
                              icon: const Icon(Icons.send,
                                  color: SeedColors.orange),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
    );
  }

  Widget _bubble(Message message) {
    final mine = message.senderId == Session.instance.userId;
    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        constraints: const BoxConstraints(maxWidth: 320),
        decoration: BoxDecoration(
          color: mine ? SeedColors.green : SeedColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: mine ? null : Border.all(color: const Color(0xFFE3DDCD)),
        ),
        child: Text(
          message.body,
          style: TextStyle(color: mine ? SeedColors.surface : SeedColors.ink),
        ),
      ),
    );
  }
}
