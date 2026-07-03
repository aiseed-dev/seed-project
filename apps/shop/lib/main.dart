// SPDX-License-Identifier: AGPL-3.0-only
import 'package:core/core.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'config.dart';
import 'nav.dart';
import 'screens/dashboard.dart';
import 'screens/import.dart';
import 'screens/listings.dart';
import 'screens/login.dart';
import 'screens/request.dart';
import 'screens/requests.dart';
import 'screens/settings.dart';

void main() {
  ApiClient.init(apiBase);
  Session.pocketbaseUrl = pbBase;
  runApp(const ShopApp());
}

/// 販売用アプリ(docs/05)。店舗スタッフが使う。
class ShopApp extends StatelessWidget {
  const ShopApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: '種の交換(店舗)',
      theme: seedTheme(),
      routerConfig: _router,
    );
  }
}

final _router = GoRouter(
  routes: [
    GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
    GoRoute(path: '/import', builder: (context, state) => const ImportScreen()),
    StatefulShellRoute.indexedStack(
      builder: (context, state, shell) => NavShell(shell: shell),
      branches: [
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/',
              builder: (context, state) => const DashboardScreen(),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/listings',
              builder: (context, state) => const ShopListingsScreen(),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/requests',
              builder: (context, state) => const ShopRequestsScreen(),
              routes: [
                GoRoute(
                  path: ':id',
                  builder: (context, state) => ShopRequestScreen(
                    requestId: state.pathParameters['id']!,
                  ),
                ),
              ],
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/settings',
              builder: (context, state) => const SettingsScreen(),
            ),
          ],
        ),
      ],
    ),
  ],
);
