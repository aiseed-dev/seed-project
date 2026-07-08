// SPDX-License-Identifier: AGPL-3.0-only
import 'package:core/core.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// 辞典記事(docs/04 VarietyArticleScreen)。
class VarietyArticleScreen extends StatefulWidget {
  const VarietyArticleScreen({super.key, required this.varietyId});

  final String varietyId;

  @override
  State<VarietyArticleScreen> createState() => _VarietyArticleScreenState();
}

class _VarietyArticleScreenState extends State<VarietyArticleScreen> {
  Article? _article; // null=読込中
  List<Listing> _related = [];
  String? _error;

  static const sectionLabels = {
    'history': '歴史',
    'cultivation': '栽培方法',
    'natural_farming': '自然農法',
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
    setState(() {
      _article = null;
      _error = null;
    });
    try {
      final article = await ApiClient.i.fetchArticle(widget.varietyId);
      // この品種の出品(交換アプリへの逆導線)。品種名の検索で近似
      final related = await ApiClient.i.fetchListings(
        q: article.varietyName,
        limit: 10,
      );
      if (mounted) {
        setState(() {
          _article = article;
          _related = related;
        });
      }
    } on ApiException catch (e) {
      if (mounted) {
        setState(
            () => _error = e.status == 404 ? '品種が見つかりません' : 'メンテナンス中です');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final article = _article;
    return Scaffold(
      appBar: AppBar(title: Text(article?.varietyName ?? '辞典')),
      body: _error != null
          ? Center(
              child: TextButton(onPressed: _load, child: Text('$_error(再試行)')),
            )
          : article == null
              ? const Center(child: CircularProgressIndicator())
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    Text(article.varietyName,
                        style: const TextStyle(
                            fontSize: 20, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    if (article.content.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 24),
                        child: Text('この品種の記事はまだありません。最初の執筆者になりませんか?'),
                      )
                    else
                      for (final entry in sectionLabels.entries)
                        if ((article.content[entry.key] ?? '').isNotEmpty) ...[
                          Padding(
                            padding: const EdgeInsets.only(top: 12, bottom: 4),
                            child: Text(entry.value,
                                style: const TextStyle(
                                    color: SeedColors.green,
                                    fontWeight: FontWeight.bold)),
                          ),
                          Text(article.content[entry.key]!),
                        ],
                    const SizedBox(height: 16),
                    OutlinedButton.icon(
                      icon: const Icon(Icons.edit_outlined),
                      label: const Text('編集を提案'),
                      onPressed: () =>
                          context.go('/v/${widget.varietyId}/edit'),
                    ),
                    if (_related.isNotEmpty) ...[
                      const Padding(
                        padding: EdgeInsets.only(top: 24, bottom: 8),
                        child: Text('この品種の出品',
                            style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                      SizedBox(
                        height: 250,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: _related.length,
                          separatorBuilder: (_, _) => const SizedBox(width: 8),
                          itemBuilder: (context, i) => SizedBox(
                            width: 160,
                            child: ListingCard(
                              listing: _related[i],
                              onTap: () =>
                                  context.go('/l/${_related[i].id}'),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
    );
  }
}
