// SPDX-License-Identifier: AGPL-3.0-only
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// 下部ナビの殻。docs/04: ホーム / 検索 / 出品(+) / カート / マイページ。
class NavShell extends StatelessWidget {
  const NavShell({super.key, required this.shell});

  final StatefulNavigationShell shell;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: shell,
      bottomNavigationBar: NavigationBar(
        selectedIndex: shell.currentIndex,
        onDestinationSelected: (index) => shell.goBranch(
          index,
          initialLocation: index == shell.currentIndex,
        ),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), label: 'ホーム'),
          NavigationDestination(icon: Icon(Icons.search), label: '検索'),
          NavigationDestination(icon: Icon(Icons.add_circle_outline), label: '出品'),
          NavigationDestination(
            icon: Icon(Icons.shopping_cart_outlined),
            label: 'カート',
          ),
          NavigationDestination(icon: Icon(Icons.person_outline), label: 'マイページ'),
        ],
      ),
    );
  }
}
