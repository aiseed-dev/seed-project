// SPDX-License-Identifier: AGPL-3.0-only
import 'package:core/core.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// 差分レビュー(docs/04 RevisionReviewScreen)。
/// 差分はサーバー計算済み。op=add は緑背景、del は赤背景+取り消し線。
class RevisionReviewScreen extends StatefulWidget {
  const RevisionReviewScreen({super.key, required this.revisionId});

  final String revisionId;

  @override
  State<RevisionReviewScreen> createState() => _RevisionReviewScreenState();
}

class _RevisionReviewScreenState extends State<RevisionReviewScreen> {
  RevisionDetail? _detail; // null=読込中
  String? _error;
  bool _busy = false;

  static const sectionLabels = {
    'history': '歴史',
    'cultivation': '栽培方法',
    'seed_saving': '採種方法',
    'cooking': '料理',
    'sources': '出典',
  };

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final detail = await ApiClient.i.fetchEditorRevision(widget.revisionId);
      if (mounted) setState(() => _detail = detail);
    } on ApiException catch (e) {
      if (mounted) {
        setState(() => _error = e.status == 403 ? 'editor 権限が必要です' : e.message);
      }
    }
  }

  Future<void> _review(String action) async {
    String? note;
    if (action == 'reject') {
      final controller = TextEditingController();
      note = await showDialog<String>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('却下の理由(著者に届きます)'),
          content: TextField(controller: controller, autofocus: true),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('やめる'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, controller.text.trim()),
              child: const Text('却下する'),
            ),
          ],
        ),
      );
      if (note == null || note.isEmpty) return;
    } else {
      final ok = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('この提案を承認して公開しますか?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('やめる'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('承認する'),
            ),
          ],
        ),
      );
      if (ok != true) return;
    }
    if (!mounted) return;
    setState(() => _busy = true);
    try {
      await ApiClient.i.reviewRevision(widget.revisionId, action, note);
      if (mounted) context.go('/editor/revisions');
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final detail = _detail;
    return Scaffold(
      appBar: AppBar(title: Text(detail?.varietyName ?? '差分レビュー')),
      body: _error != null
          ? Center(child: Text(_error!))
          : detail == null
              ? const Center(child: CircularProgressIndicator())
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    Text(
                      detail.revision.editSummary ?? '(変更概要なし)',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    for (final entry in detail.diff.entries)
                      ExpansionTile(
                        tilePadding: EdgeInsets.zero,
                        initiallyExpanded: true,
                        title: Text(
                          sectionLabels[entry.key] ?? entry.key,
                          style: const TextStyle(
                              color: SeedColors.green,
                              fontWeight: FontWeight.bold),
                        ),
                        children: [
                          for (final line in entry.value) _diffLine(line),
                        ],
                      ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: FilledButton(
                            onPressed: _busy ? null : () => _review('approve'),
                            child: const Text('承認する'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton(
                            onPressed: _busy ? null : () => _review('reject'),
                            child: const Text('却下する'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
    );
  }

  Widget _diffLine(DiffLine line) {
    final (color, style) = switch (line.op) {
      'add' => (const Color(0xFFE3F0D8), const TextStyle()),
      'del' => (
          const Color(0xFFF6DEDA),
          const TextStyle(decoration: TextDecoration.lineThrough),
        ),
      _ => (Colors.transparent, const TextStyle()),
    };
    return Container(
      width: double.infinity,
      color: color,
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      child: Text(line.text, style: style),
    );
  }
}
