// SPDX-License-Identifier: AGPL-3.0-only
import 'package:flutter_test/flutter_test.dart';
import 'package:seed/main.dart';

void main() {
  testWidgets('下部ナビの5項目が表示される', (WidgetTester tester) async {
    await tester.pumpWidget(const SeedApp());
    await tester.pumpAndSettle();

    expect(find.text('ホーム'), findsOneWidget);
    expect(find.text('検索'), findsOneWidget);
    expect(find.text('出品'), findsOneWidget);
    expect(find.text('カート'), findsOneWidget);
    expect(find.text('マイページ'), findsOneWidget);
    expect(find.text('ホーム(準備中)'), findsOneWidget);
  });
}
