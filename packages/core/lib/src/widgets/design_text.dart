// SPDX-License-Identifier: MIT
import 'package:flutter/material.dart';

import '../constants.dart';

/// 「デザインの文字」(価格・バッジ・チップ・スペック行・統計数値など、
/// 意図してサイズを決めている文字)専用のテキスト。
///
/// - OS の文字サイズ設定(textScaler)の影響を受けない
/// - 周囲の DefaultTextStyle・太字設定の影響を受けない(inherit: false)
///
/// 説明文・記事・メッセージなどの「読む文字」には使わないこと
/// (そちらはユーザー設定に追従させる。詳細は .claude/skills/design)。
class DesignText extends StatelessWidget {
  const DesignText(
    this.text, {
    super.key,
    required this.size,
    this.color = SeedColors.ink,
    this.bold = false,
    this.maxLines,
    this.overflow,
    this.decoration,
  });

  final String text;
  final double size;
  final Color color;
  final bool bold;
  final int? maxLines;
  final TextOverflow? overflow;
  final TextDecoration? decoration;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      maxLines: maxLines,
      overflow: overflow,
      textScaler: TextScaler.noScaling,
      style: TextStyle(
        inherit: false,
        fontSize: size,
        color: color,
        fontWeight: bold ? FontWeight.bold : FontWeight.normal,
        decoration: decoration ?? TextDecoration.none,
        fontFamily: DefaultTextStyle.of(context).style.fontFamily,
      ),
    );
  }
}
