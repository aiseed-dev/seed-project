// SPDX-License-Identifier: AGPL-3.0-only
import 'package:core/core.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// カート(docs/04 CartScreen)。提供者ごとのグループ表示。
class CartScreen extends StatefulWidget {
  const CartScreen({super.key});

  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  List<CartGroup>? _groups; // null=読込中
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (!Session.instance.isLoggedIn) {
      setState(() {
        _groups = [];
        _error = 'ログインするとカートを使えます';
      });
      return;
    }
    setState(() {
      _groups = null;
      _error = null;
    });
    try {
      final groups = await ApiClient.i.fetchCart();
      if (mounted) setState(() => _groups = groups);
    } on ApiException catch (e) {
      if (mounted) {
        setState(() => _error = e.status == 401 ? 'ログインが必要です' : 'メンテナンス中です');
      }
    }
  }

  Future<void> _changeQuantity(CartLine line, int quantity) async {
    try {
      if (quantity <= 0) {
        await ApiClient.i.deleteCartItem(line.listingId);
      } else {
        await ApiClient.i.putCartItem(line.listingId, quantity);
      }
      await _load();
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
  }

  Future<void> _sendRequest(CartGroup group) async {
    final note = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('${group.provider.name} に申込みを送る'),
        content: TextField(
          controller: note,
          decoration: const InputDecoration(hintText: '一言メッセージ(任意)'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('やめる'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('申込みを送る'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    try {
      final request = await ApiClient.i.createRequest(
        providerKind: group.provider.kind,
        providerId: group.provider.id,
        note: note.text.trim(),
      );
      if (mounted) context.go('/requests/${request.id}');
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final groups = _groups;
    return Scaffold(
      appBar: AppBar(title: const Text('カート')),
      body: _error != null
          ? Center(
              child: TextButton(
                onPressed: Session.instance.isLoggedIn
                    ? _load
                    : () => context.go('/login'),
                child: Text(_error!),
              ),
            )
          : groups == null
              ? const Center(child: CircularProgressIndicator())
              : groups.isEmpty
                  ? const Center(child: Text('カートは空です'))
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: ListView(
                        padding: const EdgeInsets.all(12),
                        children: [
                          for (final group in groups) _group(group),
                        ],
                      ),
                    ),
    );
  }

  Widget _group(CartGroup group) {
    return Card(
      color: SeedColors.surface,
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(6),
        side: const BorderSide(color: Color(0xFFE3DDCD)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    group.provider.isVerified
                        ? '✓ ${group.provider.name}'
                        : group.provider.name,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: SeedColors.green),
                  ),
                ),
              ],
            ),
            const Divider(),
            for (final line in group.items) _line(line),
            if (group.subtotalYen != null)
              Align(
                alignment: Alignment.centerRight,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: DesignText(
                    '小計 ¥${group.subtotalYen}(送料別)',
                    size: 14,
                    color: SeedColors.orange,
                    bold: true,
                  ),
                ),
              ),
            FilledButton(
              onPressed: group.items.every((l) => l.status == 'active')
                  ? () => _sendRequest(group)
                  : null,
              child: const Text('申込みを送る'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _line(CartLine line) {
    final available = line.status == 'active';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          TypeBadge(listingType: line.listingType),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  line.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: available ? SeedColors.ink : SeedColors.disabled,
                  ),
                ),
                if (!available)
                  const DesignText('入手できなくなりました',
                      size: 11, color: SeedColors.disabled),
                if (line.priceYen != null)
                  DesignText('¥${line.priceYen}',
                      size: 12, color: SeedColors.orange),
              ],
            ),
          ),
          IconButton(
            onPressed: () => _changeQuantity(line, line.quantity - 1),
            icon: const Icon(Icons.remove_circle_outline, size: 20),
          ),
          Text('${line.quantity}'),
          IconButton(
            onPressed:
                available ? () => _changeQuantity(line, line.quantity + 1) : null,
            icon: const Icon(Icons.add_circle_outline, size: 20),
          ),
          IconButton(
            onPressed: () => _changeQuantity(line, 0),
            icon: const Icon(Icons.delete_outline, size: 20),
          ),
        ],
      ),
    );
  }
}
