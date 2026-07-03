// SPDX-License-Identifier: AGPL-3.0-only
import 'dart:convert';

import 'package:core/core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shop/main.dart';

http.Client fakeApi() {
  return MockClient((request) async {
    final path = request.url.path;
    Object body;
    if (path.endsWith('/shop')) {
      body = {
        'id': '22222222-2222-2222-2222-222222222222',
        'slug': 'tanenomori',
        'code': 'TANE',
        'name': 'たねの森',
        'description': null,
        'website_url': null,
        'region': '埼玉県日高市',
        'contact_phone': null,
        'return_policy': null,
        'delivery_time': null,
        'is_verified': true,
        'is_active': true,
      };
    } else if (path.endsWith('/shop/listings')) {
      body = [
        {
          'id': '11111111-1111-1111-1111-111111111111',
          'user_id': 'staff1',
          'shop_id': '22222222-2222-2222-2222-222222222222',
          'variety_id': null,
          'variety_name_free': 'みやま小かぶ',
          'category_id': 3,
          'title': 'みやま小かぶ',
          'description': '',
          'item_kind': 'seed',
          'listing_type': 'sell',
          'price_yen': 360,
          'desired_trade': null,
          'quantity_note': null,
          'harvest_year': null,
          'is_self_saved': false,
          'region': null,
          'cultivation_note': null,
          'no_warranty': false,
          'requires_seed_label': true,
          'label_seller_name': 'たねの森',
          'label_seller_address': '埼玉県日高市',
          'label_production_area': '埼玉県',
          'label_germination_rate': '85%以上',
          'label_seed_treatment': null,
          'delivery_method': 'mail',
          'payment_default': 'later',
          'status': 'active',
          'created_at': '2026-07-03T00:00:00+00:00',
          'photos': <Object>[],
        },
      ];
    } else if (path.endsWith('/shop/requests')) {
      body = [
        {
          'request': {
            'id': '33333333-3333-3333-3333-333333333333',
            'request_no': '2026-00001',
            'requester_id': 'buyer',
            'provider_user_id': null,
            'provider_shop_id': '22222222-2222-2222-2222-222222222222',
            'status': 'requested',
            'note': null,
            'created_at': '2026-07-03T00:00:00+00:00',
            'accepted_at': null,
            'completed_at': null,
          },
          'role': 'provider',
          'item_count': 2,
          'last_message': null,
        },
      ];
    } else if (path.endsWith('/shop/members')) {
      body = [
        {
          'user_id': 'staff1',
          'display_name': 'たねの森スタッフ',
          'role': 'owner',
          'contact_label': null,
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
    Session.instance.setForTest(token: 'tok', userId: 'staff1');
  });

  testWidgets('ダッシュボードに件数と未対応申込みが出る', (WidgetTester tester) async {
    await tester.pumpWidget(const ShopApp());
    await tester.pumpAndSettle();

    expect(find.text('たねの森'), findsOneWidget);
    expect(find.text('1 件'), findsNWidgets(2)); // 公開中1・未対応1
    expect(find.text('2026-00001(2品目)'), findsOneWidget);
    // 担当名未登録の案内
    expect(find.text('担当者名を登録してください'), findsOneWidget);
  });
}
