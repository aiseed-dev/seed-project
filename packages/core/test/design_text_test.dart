// SPDX-License-Identifier: MIT
import 'package:core/core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const listing = Listing(
  id: 'x',
  userId: 'u1',
  categoryId: 1,
  title: 'みやま小かぶの種(自家採種)',
  description: '',
  itemKind: 'seed',
  listingType: 'sell',
  priceYen: 360,
  quantityNote: '小袋約30粒',
  harvestYear: 2025,
  isSelfSaved: true,
  region: '徳島県',
  noWarranty: true,
  requiresSeedLabel: false,
  deliveryMethod: 'mail',
  paymentDefault: 'later',
  status: 'active',
  createdAt: '2026-07-03T00:00:00+00:00',
);

Widget wrap(Widget child, {double scale = 1.0}) {
  return MaterialApp(
    home: MediaQuery(
      data: MediaQueryData(textScaler: TextScaler.linear(scale)),
      child: Scaffold(
        body: Center(child: SizedBox(width: 160, height: 258, child: child)),
      ),
    ),
  );
}

void main() {
  testWidgets('デザインの文字は textScaler 2.0 でも拡大されない', (tester) async {
    await tester.pumpWidget(wrap(const ListingCard(listing: listing), scale: 2.0));

    // 価格(DesignText)は固定サイズのまま
    final price = tester.widget<Text>(
      find.descendant(
        of: find.byType(DesignText),
        matching: find.text('360円'),
      ),
    );
    expect(price.textScaler, TextScaler.noScaling);

    // タイトル(読む文字)は追従する(textScaler 指定なし=環境に従う)
    final title = tester.widget<Text>(find.text('みやま小かぶの種(自家採種)'));
    expect(title.textScaler, isNull);
  });

  testWidgets('textScaler 2.0 の固定高さカードでオーバーフローしない', (tester) async {
    await tester.pumpWidget(wrap(const ListingCard(listing: listing), scale: 2.0));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull); // RenderFlex overflow なし
  });
}
