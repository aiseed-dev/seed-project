// SPDX-License-Identifier: AGPL-3.0-only
import 'dart:async';

import 'package:core/core.dart';
import 'package:flutter/material.dart';

/// 申込み画面(docs/04 RequestScreen)。品目・状態・操作+メッセージ。
/// 画面表示中のみ10秒間隔でポーリングする(WebSocket は使わない)。
class RequestScreen extends StatefulWidget {
  const RequestScreen({super.key, required this.requestId});

  final String requestId;

  @override
  State<RequestScreen> createState() => _RequestScreenState();
}

class _RequestScreenState extends State<RequestScreen> {
  TradeRequest? _request; // null=読込中
  List<Message> _messages = [];
  bool _reviewed = false;
  String? _error;
  Timer? _poll;
  final _body = TextEditingController();
  bool _sending = false;

  bool get _isRequester =>
      _request?.requesterId == Session.instance.userId;

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
        setState(() => _error = e.status == 404 ? '申込みが見つかりません' : 'メンテナンス中です');
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

  Future<void> _review(int score, String comment) async {
    try {
      await ApiClient.i.postReview(widget.requestId, score, comment);
      setState(() => _reviewed = true);
    } on ApiException catch (e) {
      if (e.code == 'DUPLICATE_REVIEW') setState(() => _reviewed = true);
    }
  }

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
                    _header(request),
                    const Divider(height: 1),
                    Expanded(child: _messageList(request)),
                    _composer(request),
                  ],
                ),
    );
  }

  Widget _header(TradeRequest request) {
    const labels = {
      'requested': '申込み中',
      'accepted': '取引中',
      'declined': '辞退されました',
      'completed': '完了',
      'cancelled': '取下げ',
      'expired': '期限切れ',
    };
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ExpansionTile(
            tilePadding: EdgeInsets.zero,
            title: DesignText(
              '${labels[request.status]}・${request.items.length}品目',
              size: 14,
              color: SeedColors.green,
              bold: true,
            ),
            children: [
              for (final item in request.items)
                ListTile(
                  dense: true,
                  leading: TypeBadge(listingType: item.listingType),
                  title: Text(item.title),
                  trailing: DesignText(
                    item.priceYen != null
                        ? '¥${item.priceYen} × ${item.quantity}'
                        : '× ${item.quantity}',
                    size: 13,
                  ),
                ),
            ],
          ),
          _actions(request),
        ],
      ),
    );
  }

  Widget _actions(TradeRequest request) {
    final buttons = <Widget>[];
    if (request.status == 'requested') {
      if (_isRequester) {
        buttons.add(OutlinedButton(
          onPressed: () => _patch('cancelled'),
          child: const Text('取り下げる'),
        ));
      } else {
        buttons.add(FilledButton(
          onPressed: () => _patch('accepted'),
          child: const Text('承諾する'),
        ));
        buttons.add(OutlinedButton(
          onPressed: () => _patch('declined'),
          child: const Text('辞退する'),
        ));
      }
    }
    if (request.status == 'accepted') {
      buttons.add(FilledButton(
        onPressed: () => _patch('completed'),
        child: const Text('完了にする'),
      ));
    }
    if (buttons.isEmpty) return const SizedBox.shrink();
    return Wrap(spacing: 8, children: buttons);
  }

  Widget _messageList(TradeRequest request) {
    final children = <Widget>[
      for (final message in _messages) _bubble(message),
      if (request.status == 'completed' && !_reviewed)
        _ReviewPrompt(onSubmit: _review),
    ];
    return ListView(
      padding: const EdgeInsets.all(12),
      children: children,
    );
  }

  Widget _bubble(Message message) {
    final mine = message.senderId == Session.instance.userId;
    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        constraints: const BoxConstraints(maxWidth: 280),
        decoration: BoxDecoration(
          color: mine ? SeedColors.green : SeedColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: mine ? null : Border.all(color: const Color(0xFFE3DDCD)),
        ),
        child: Text(
          message.body,
          style:
              TextStyle(color: mine ? SeedColors.surface : SeedColors.ink),
        ),
      ),
    );
  }

  Widget _composer(TradeRequest request) {
    if (request.status case 'declined' || 'cancelled' || 'expired') {
      return const SizedBox.shrink();
    }
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _body,
                decoration: const InputDecoration(
                  hintText: 'メッセージ(支払い・受け渡しの相談)',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
            ),
            IconButton(
              onPressed: _sending ? null : _send,
              icon: const Icon(Icons.send, color: SeedColors.orange),
            ),
          ],
        ),
      ),
    );
  }
}

/// 完了後の評価(★5段階+コメント)。吹き出し列の末尾に挿入する。
class _ReviewPrompt extends StatefulWidget {
  const _ReviewPrompt({required this.onSubmit});

  final void Function(int score, String comment) onSubmit;

  @override
  State<_ReviewPrompt> createState() => _ReviewPromptState();
}

class _ReviewPromptState extends State<_ReviewPrompt> {
  int _score = 5;
  final _comment = TextEditingController();

  @override
  void dispose() {
    _comment.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      color: SeedColors.surface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(6),
        side: const BorderSide(color: SeedColors.green),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('取引はいかがでしたか?',
                style: TextStyle(fontWeight: FontWeight.bold)),
            Row(
              children: [
                for (var i = 1; i <= 5; i++)
                  IconButton(
                    onPressed: () => setState(() => _score = i),
                    icon: Icon(
                      i <= _score ? Icons.star : Icons.star_border,
                      color: SeedColors.orange,
                    ),
                  ),
              ],
            ),
            TextField(
              controller: _comment,
              decoration: const InputDecoration(
                hintText: 'コメント(任意)',
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
            const SizedBox(height: 8),
            FilledButton(
              onPressed: () => widget.onSubmit(_score, _comment.text.trim()),
              child: const Text('評価を送る'),
            ),
          ],
        ),
      ),
    );
  }
}
