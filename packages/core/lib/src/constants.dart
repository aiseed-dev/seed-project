// SPDX-License-Identifier: MIT
import 'package:flutter/material.dart';

/// docs/10 の配色。Widget での直接色指定は禁止し、必ずここを参照する。
abstract final class SeedColors {
  /// 背景(生成り)
  static const background = Color(0xFFF5F1E6);

  /// 面(カード)
  static const surface = Color(0xFFFFFFFF);

  /// 文字(主)
  static const ink = Color(0xFF33302A);

  /// 緑(基調): キャッチコピー・チップ・「交換」バッジ
  static const green = Color(0xFF5A7A2E);

  /// 橙(強調): 価格・主ボタン。1画面に1種類の強調
  static const orange = Color(0xFFC0761A);

  /// 青(補助): 「譲渡」バッジ
  static const blue = Color(0xFF3A6B8A);

  /// 無効: 取引中・品切れ状態のボタン
  static const disabled = Color(0xFFA9A297);
}

/// docs/10 を Material 3 の ColorScheme にマッピングしたテーマ。
ThemeData seedTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: SeedColors.green,
  ).copyWith(
    primary: SeedColors.orange,
    onPrimary: SeedColors.surface,
    secondary: SeedColors.green,
    onSecondary: SeedColors.surface,
    tertiary: SeedColors.blue,
    surface: SeedColors.surface,
    onSurface: SeedColors.ink,
    outline: SeedColors.disabled,
  );
  return ThemeData(
    colorScheme: scheme,
    scaffoldBackgroundColor: SeedColors.background,
    useMaterial3: true,
  );
}
