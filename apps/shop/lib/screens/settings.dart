// SPDX-License-Identifier: AGPL-3.0-only
import 'package:core/core.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// 店舗設定(docs/05)。担当名・店舗プロフィール(owner)・スタッフ一覧。
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  ShopInfo? _shop;
  List<ShopMemberInfo> _members = [];
  String? _error;

  bool get _isOwner => _members.any(
        (m) => m.userId == Session.instance.userId && m.role == 'owner',
      );

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
    try {
      final shop = await ApiClient.i.fetchShop();
      final members = await ApiClient.i.fetchShopMembers();
      if (mounted) {
        setState(() {
          _shop = shop;
          _members = members;
          _error = null;
        });
      }
    } on ApiException catch (e) {
      if (mounted) {
        setState(() =>
            _error = e.code == 'NOT_SHOP_STAFF' ? '店舗アカウントが必要です' : 'メンテナンス中です');
      }
    }
  }

  Future<void> _editContactLabel() async {
    final mine = _members
        .where((m) => m.userId == Session.instance.userId)
        .toList();
    final controller =
        TextEditingController(text: mine.isEmpty ? '' : mine.first.contactLabel);
    final label = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('担当部門/担当者名'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(hintText: '例: 種苗部 田中'),
          autofocus: true,
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('やめる')),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('保存する'),
          ),
        ],
      ),
    );
    if (label == null || label.isEmpty) return;
    try {
      await ApiClient.i.patchContactLabel(label);
      await _load();
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
  }

  Future<void> _editShop() async {
    final shop = _shop;
    if (shop == null) return;
    final fields = {
      'description': TextEditingController(text: shop.description ?? ''),
      'region': TextEditingController(text: shop.region ?? ''),
      'contact_phone': TextEditingController(text: shop.contactPhone ?? ''),
      'return_policy': TextEditingController(text: shop.returnPolicy ?? ''),
      'delivery_time': TextEditingController(text: shop.deliveryTime ?? ''),
    };
    const labels = {
      'description': '店舗紹介',
      'region': '住所(地域)',
      'contact_phone': '連絡先(特商法表示)',
      'return_policy': '返品方針(特商法表示)',
      'delivery_time': '引き渡し時期(特商法表示)',
    };
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('店舗プロフィール'),
        content: SizedBox(
          width: 420,
          child: ListView(
            shrinkWrap: true,
            children: [
              for (final entry in fields.entries)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: TextField(
                    controller: entry.value,
                    decoration: InputDecoration(
                      labelText: labels[entry.key],
                      border: const OutlineInputBorder(),
                    ),
                  ),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('やめる')),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('保存する'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await ApiClient.i.patchShop({
        for (final entry in fields.entries)
          entry.key: entry.value.text.trim(),
      });
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
    final shop = _shop;
    return Scaffold(
      appBar: AppBar(title: const Text('店舗設定')),
      body: _error != null
          ? Center(
              child: TextButton(
                onPressed: _error!.contains('ログイン')
                    ? () => context.go('/login')
                    : _load,
                child: Text(_error!),
              ),
            )
          : shop == null
              ? const Center(child: CircularProgressIndicator())
              : ListView(
                  children: [
                    ListTile(
                      title: Text(shop.name,
                          style:
                              const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text(
                          '店舗コード: ${shop.code}${shop.isVerified ? "・✓認証店" : ""}'),
                    ),
                    ListTile(
                      leading: const Icon(Icons.badge_outlined,
                          color: SeedColors.green),
                      title: const Text('担当部門/担当者名'),
                      subtitle: Text(_members
                              .where((m) =>
                                  m.userId == Session.instance.userId)
                              .map((m) => m.contactLabel ?? '(未登録)')
                              .join()),
                      onTap: _editContactLabel,
                    ),
                    if (_isOwner)
                      ListTile(
                        leading: const Icon(Icons.storefront_outlined,
                            color: SeedColors.green),
                        title: const Text('店舗プロフィール(特商法表示を含む)'),
                        onTap: _editShop,
                      ),
                    const Divider(),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16),
                      child: Text('スタッフ',
                          style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                    for (final member in _members)
                      ListTile(
                        dense: true,
                        title: Text(member.displayName),
                        subtitle: Text(member.contactLabel ?? '(担当名未登録)'),
                        trailing:
                            Text(member.role == 'owner' ? 'オーナー' : 'スタッフ'),
                      ),
                    const Divider(),
                    ListTile(
                      leading:
                          const Icon(Icons.logout, color: SeedColors.disabled),
                      title: const Text('ログアウト'),
                      onTap: () {
                        Session.instance.logout();
                        context.go('/login');
                      },
                    ),
                  ],
                ),
    );
  }
}
