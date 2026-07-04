// SPDX-License-Identifier: AGPL-3.0-only
import 'package:core/core.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// 辞典の編集提案(docs/04 ArticleEditScreen)。セクションごとのテキストエリア。
class ArticleEditScreen extends StatefulWidget {
  const ArticleEditScreen({super.key, required this.varietyId});

  final String varietyId;

  @override
  State<ArticleEditScreen> createState() => _ArticleEditScreenState();
}

class _ArticleEditScreenState extends State<ArticleEditScreen> {
  static const sections = [
    ('history', '歴史'),
    ('cultivation', '栽培方法'),
    ('natural_farming', '自然農法(不耕起・無肥料などの実践のコツ)'),
    ('seed_saving', '採種方法'),
    ('cooking', '料理'),
    ('sources', '出典'),
  ];

  final Map<String, TextEditingController> _fields = {
    for (final (key, _) in sections) key: TextEditingController(),
  };
  final _summary = TextEditingController();
  bool _loaded = false;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    for (final controller in _fields.values) {
      controller.dispose();
    }
    _summary.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final article = await ApiClient.i.fetchArticle(widget.varietyId);
      if (!mounted) return;
      for (final entry in article.content.entries) {
        _fields[entry.key]?.text = entry.value;
      }
      setState(() => _loaded = true);
    } on ApiException {
      if (mounted) setState(() => _error = '読み込めませんでした');
    }
  }

  Future<void> _submit() async {
    if (!Session.instance.isLoggedIn) {
      context.go('/login');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ApiClient.i.postRevision(
        widget.varietyId,
        {
          for (final entry in _fields.entries)
            if (entry.value.text.trim().isNotEmpty)
              entry.key: entry.value.text.trim(),
        },
        _summary.text.trim(),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('提案を送りました。承認後に公開されます')),
      );
      context.go('/v/${widget.varietyId}');
    } on ApiException catch (e) {
      if (mounted) {
        setState(() => _error = e.status == 401 ? 'ログインが必要です' : e.message);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('編集を提案')),
      body: !_loaded
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                for (final (key, label) in sections) ...[
                  Text(label,
                      style: const TextStyle(
                          color: SeedColors.green,
                          fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  TextField(
                    controller: _fields[key],
                    maxLines: 5,
                    minLines: 2,
                    decoration:
                        const InputDecoration(border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 12),
                ],
                TextField(
                  controller: _summary,
                  decoration: const InputDecoration(
                    labelText: '変更内容の一言(履歴に表示)',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  '投稿した内容は CC BY-SA 4.0 で公開されることに同意したものとします。',
                  style: TextStyle(fontSize: 11, color: SeedColors.disabled),
                ),
                if (_error != null)
                  Text(_error!,
                      style:
                          const TextStyle(color: Colors.red, fontSize: 12)),
                const SizedBox(height: 8),
                FilledButton(
                  onPressed: _busy ? null : _submit,
                  child: Text(_busy ? '送信中…' : '提案を送る'),
                ),
              ],
            ),
    );
  }
}
