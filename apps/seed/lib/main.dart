// SPDX-License-Identifier: AGPL-3.0-only
import 'package:core/core.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'config.dart';
import 'nav.dart';
import 'screens/cart.dart';
import 'screens/detail.dart';
import 'screens/home.dart';
import 'screens/listings.dart';
import 'screens/login.dart';
import 'screens/mypage.dart';
import 'screens/post.dart';
import 'screens/articleedit.dart';
import 'screens/register.dart';
import 'screens/request.dart';
import 'screens/requests.dart';
import 'screens/revqueue.dart';
import 'screens/revreview.dart';
import 'screens/search.dart';
import 'screens/variety.dart';

void main() {
  ApiClient.init(apiBase);
  Session.pocketbaseUrl = pbBase;
  runApp(const SeedApp());
}

/// 交換用アプリ。ルーティングは docs/04(go_router のみ)。
class SeedApp extends StatelessWidget {
  const SeedApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: '種の交換',
      theme: seedTheme(),
      routerConfig: _router,
    );
  }
}

final _router = GoRouter(
  routes: [
    GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
    GoRoute(
      path: '/register',
      builder: (context, state) => const RegisterScreen(),
    ),
    GoRoute(
      path: '/requests',
      builder: (context, state) => const RequestListScreen(),
      routes: [
        GoRoute(
          path: ':id',
          builder: (context, state) =>
              RequestScreen(requestId: state.pathParameters['id']!),
        ),
      ],
    ),
    GoRoute(
      path: '/v/:id',
      builder: (context, state) =>
          VarietyArticleScreen(varietyId: state.pathParameters['id']!),
      routes: [
        GoRoute(
          path: 'edit',
          builder: (context, state) =>
              ArticleEditScreen(varietyId: state.pathParameters['id']!),
        ),
      ],
    ),
    GoRoute(
      path: '/editor/revisions',
      builder: (context, state) => const RevisionQueueScreen(),
      routes: [
        GoRoute(
          path: ':id',
          builder: (context, state) =>
              RevisionReviewScreen(revisionId: state.pathParameters['id']!),
        ),
      ],
    ),
    StatefulShellRoute.indexedStack(
      builder: (context, state, shell) => NavShell(shell: shell),
      branches: [
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/',
              builder: (context, state) => const HomeScreen(),
              routes: [
                GoRoute(
                  path: 'c/:slug',
                  builder: (context, state) => CategoryListingsScreen(
                    slug: state.pathParameters['slug']!,
                  ),
                ),
                GoRoute(
                  path: 'l/:id',
                  builder: (context, state) => ListingDetailScreen(
                    listingId: state.pathParameters['id']!,
                  ),
                ),
              ],
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/search',
              builder: (context, state) => const SearchResultScreen(),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/post',
              builder: (context, state) => const PostListingScreen(),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/cart',
              builder: (context, state) => const CartScreen(),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/me',
              builder: (context, state) => const MyPageScreen(),
            ),
          ],
        ),
      ],
    ),
  ],
);
