// SPDX-License-Identifier: AGPL-3.0-only
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'config.dart';

/// ナビの殻(docs/05)。<900px は下部ナビ、≥900px は左ナビ。
/// 同じ画面Widgetを LayoutBuilder で出し分ける(画面を2重に作らない)。
class NavShell extends StatelessWidget {
  const NavShell({super.key, required this.shell});

  final StatefulNavigationShell shell;

  static const _items = [
    (Icons.home_outlined, 'ホーム'),
    (Icons.grass, '出品'),
    (Icons.swap_horiz, '申込み'),
    (Icons.settings_outlined, '設定'),
  ];

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= wideBreakpoint;
        if (wide) {
          return Scaffold(
            body: Row(
              children: [
                NavigationRail(
                  selectedIndex: shell.currentIndex,
                  onDestinationSelected: (i) => shell.goBranch(i),
                  labelType: NavigationRailLabelType.all,
                  destinations: [
                    for (final (icon, label) in _items)
                      NavigationRailDestination(
                        icon: Icon(icon),
                        label: Text(label),
                      ),
                  ],
                ),
                const VerticalDivider(width: 1),
                Expanded(child: shell),
              ],
            ),
          );
        }
        return Scaffold(
          body: shell,
          bottomNavigationBar: NavigationBar(
            selectedIndex: shell.currentIndex,
            onDestinationSelected: (i) => shell.goBranch(i),
            destinations: [
              for (final (icon, label) in _items)
                NavigationDestination(icon: Icon(icon), label: label),
            ],
          ),
        );
      },
    );
  }
}
