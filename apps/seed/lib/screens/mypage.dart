// SPDX-License-Identifier: AGPL-3.0-only
import 'package:core/core.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// マイページ(docs/04)。申込み一覧への導線+ログイン状態の管理。
/// 出品管理・評価・貢献タブは以降のフェーズで拡充する。
class MyPageScreen extends StatefulWidget {
  const MyPageScreen({super.key});

  @override
  State<MyPageScreen> createState() => _MyPageScreenState();
}

class _MyPageScreenState extends State<MyPageScreen> {
  @override
  void initState() {
    super.initState();
    Session.instance.addListener(_onSession);
  }

  @override
  void dispose() {
    Session.instance.removeListener(_onSession);
    super.dispose();
  }

  void _onSession() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final session = Session.instance;
    return Scaffold(
      appBar: AppBar(title: const Text('マイページ')),
      body: !session.isLoggedIn
          ? Center(
              child: FilledButton(
                onPressed: () => context.go('/login'),
                child: const Text('ログインする'),
              ),
            )
          : ListView(
              children: [
                ListTile(
                  leading: const Icon(Icons.swap_horiz, color: SeedColors.green),
                  title: const Text('申込み(申込んだ・受けた)'),
                  onTap: () => context.go('/requests'),
                ),
                const ListTile(
                  leading: Icon(Icons.grass, color: SeedColors.disabled),
                  title: Text('出品管理(準備中)'),
                ),
                const ListTile(
                  leading: Icon(Icons.star_border, color: SeedColors.disabled),
                  title: Text('評価(準備中)'),
                ),
                const Divider(),
                ListTile(
                  leading: const Icon(Icons.logout, color: SeedColors.disabled),
                  title: const Text('ログアウト'),
                  onTap: () {
                    session.logout();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('ログアウトしました')),
                    );
                  },
                ),
              ],
            ),
    );
  }
}
