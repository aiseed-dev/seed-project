// SPDX-License-Identifier: AGPL-3.0-only
import 'dart:convert';

import 'package:core/core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:seed/main.dart';

const _listing = {
  'id': '11111111-1111-1111-1111-111111111111',
  'user_id': 'u1',
  'shop_id': null,
  'variety_id': null,
  'variety_name_free': 'みやま小かぶ',
  'category_id': 3,
  'title': 'みやま小かぶの種',
  'description': '',
  'item_kind': 'seed',
  'listing_type': 'exchange',
  'price_yen': null,
  'desired_trade': '在来種の葉物',
  'quantity_note': '小袋約30粒',
  'harvest_year': 2025,
  'is_self_saved': true,
  'region': '徳島県',
  'cultivation_note': null,
  'no_warranty': true,
  'requires_seed_label': false,
  'label_seller_name': null,
  'label_seller_address': null,
  'label_production_area': null,
  'label_germination_rate': null,
  'label_seed_treatment': null,
  'delivery_method': 'mail',
  'payment_default': 'later',
  'status': 'active',
  'created_at': '2026-07-03T00:00:00+00:00',
  'photos': <Object>[],
};

http.Client fakeApi() {
  return MockClient((request) async {
    final path = request.url.path;
    Object body;
    if (path.endsWith('/categories')) {
      body = [
        {'id': 1, 'slug': 'fruit-veg', 'name': '果菜', 'icon': null,
          'sort_order': 1},
        {'id': 3, 'slug': 'root-veg', 'name': '根菜', 'icon': null,
          'sort_order': 3},
      ];
    } else if (path.endsWith('/listings')) {
      body = {'items': [_listing], 'next_cursor': null};
    } else if (path.contains('/listings/')) {
      body = _listing;
    } else if (path.endsWith('/cart')) {
      body = [
        {
          'provider': {
            'kind': 'user',
            'id': 'prov1',
            'name': '種子 太郎',
            'is_verified': false,
          },
          'items': [
            {
              'listing_id': _listing['id'],
              'title': 'みやま小かぶの種',
              'listing_type': 'sell',
              'price_yen': 360,
              'quantity': 2,
              'status': 'active',
            },
          ],
          'subtotal_yen': 720,
        },
      ];
    } else {
      body = <Object>[];
    }
    return http.Response(
      jsonEncode(body),
      200,
      headers: {'content-type': 'application/json'},
    );
  });
}

void main() {
  setUp(() {
    ApiClient.init('http://test/api/v1', client: fakeApi());
    Session.instance.setForTest(token: 'tok', userId: 'buyer');
  });

  testWidgets('ホームに分類グリッドと新着が表示される', (WidgetTester tester) async {
    await tester.pumpWidget(const SeedApp());
    await tester.pumpAndSettle();

    expect(find.text('果菜'), findsOneWidget);
    expect(find.text('根菜'), findsOneWidget);
    expect(find.text('みやま小かぶの種'), findsOneWidget);
    // 個人品の無保証注記(docs/10 の対照表示)
    expect(find.text('家庭採種・発芽保証なし'), findsOneWidget);
    // 下部ナビ
    expect(find.text('出品'), findsOneWidget);
    expect(find.text('カート'), findsOneWidget);
  });

  testWidgets('出品フォームは確認チェックまで投稿ボタンが無効', (WidgetTester tester) async {
    await tester.pumpWidget(const SeedApp());
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.add_circle_outline));
    await tester.pumpAndSettle();

    expect(find.text('品種名'), findsOneWidget); // サジェスト入力欄
    await tester.scrollUntilVisible(
      find.text('品種登録されていない一般品種(固定種・在来種)です'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('品種登録されていない一般品種(固定種・在来種)です'),
        findsOneWidget);
  });

  testWidgets('カートは提供者ごとにグループ表示され小計が出る', (WidgetTester tester) async {
    await tester.pumpWidget(const SeedApp());
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.shopping_cart_outlined));
    await tester.pumpAndSettle();

    expect(find.text('種子 太郎'), findsOneWidget);
    expect(find.text('みやま小かぶの種'), findsOneWidget);
    expect(find.text('小計 ¥720(送料別)'), findsOneWidget);
    expect(find.text('申込みを送る'), findsOneWidget);
  });
}
