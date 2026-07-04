// SPDX-License-Identifier: AGPL-3.0-only
import 'package:core/core.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';

import '../config.dart';

/// CSV一括出品(docs/05・ワイドのみ)。
/// 緑=作成 / 黄=作成+品種マスタ提案 / 赤=エラー(理由列)。
class ImportScreen extends StatefulWidget {
  const ImportScreen({super.key});

  @override
  State<ImportScreen> createState() => _ImportScreenState();
}

class _ImportScreenState extends State<ImportScreen> {
  ImportSummary? _result;
  bool _busy = false;
  String? _error;

  static const _template =
      '品種名,分類slug,種苗区分,種別,価格,数量表記,採種年,生産地,発芽率,種子消毒,説明,栽培メモ';

  Future<void> _pick() async {
    const group = XTypeGroup(label: 'CSV', extensions: ['csv']);
    final file = await openFile(acceptedTypeGroups: [group]);
    if (file == null) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final bytes = await file.readAsBytes();
      final result =
          await ApiClient.i.importShopCsv(bytes, filename: file.name);
      if (mounted) setState(() => _result = result);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < wideBreakpoint) {
          return Scaffold(
            appBar: AppBar(title: const Text('CSV取込')),
            body: const Center(child: Text('CSV取込はWeb版(広い画面)で利用できます')),
          );
        }
        final result = _result;
        return Scaffold(
          appBar: AppBar(title: const Text('CSV一括出品')),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              const Text('テンプレートのヘッダ(1行目):'),
              const SelectableText(_template,
                  style: TextStyle(fontSize: 12, fontFamily: 'monospace')),
              const SizedBox(height: 4),
              const Text(
                '店舗出品は指定種苗表示が必須です(生産地、種子は発芽率)。'
                '表示者の氏名・住所は店舗プロフィールから自動補完されます。',
                style: TextStyle(fontSize: 12, color: SeedColors.disabled),
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: _busy ? null : _pick,
                icon: const Icon(Icons.upload_file),
                label: Text(_busy ? '取込中…' : 'CSVファイルを選ぶ'),
              ),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(_error!,
                      style: const TextStyle(color: Colors.red)),
                ),
              if (result != null) ...[
                const SizedBox(height: 16),
                DesignText(
                  '作成 ${result.created} / 提案つき ${result.proposed} / '
                  'エラー ${result.errors}',
                  size: 14,
                  bold: true,
                ),
                const Text(
                  '「提案つき」(黄)は運営の承認後に辞典と紐づきます',
                  style: TextStyle(fontSize: 12, color: SeedColors.disabled),
                ),
                const SizedBox(height: 8),
                DataTable(
                  columns: const [
                    DataColumn(label: Text('行')),
                    DataColumn(label: Text('品種名')),
                    DataColumn(label: Text('結果')),
                    DataColumn(label: Text('理由')),
                  ],
                  rows: [
                    for (final row in result.rows)
                      DataRow(
                        color: WidgetStatePropertyAll(switch (row.status) {
                          'created' => const Color(0xFFE3F0D8),
                          'proposed' => const Color(0xFFFFF4D6),
                          _ => const Color(0xFFF6DEDA),
                        }),
                        cells: [
                          DataCell(Text('${row.row}')),
                          DataCell(Text(row.name)),
                          DataCell(Text(switch (row.status) {
                            'created' => '作成',
                            'proposed' => '作成+提案',
                            _ => 'エラー',
                          })),
                          DataCell(Text(row.detail ?? '')),
                        ],
                      ),
                  ],
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}
