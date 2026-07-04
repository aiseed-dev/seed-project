// SPDX-License-Identifier: AGPL-3.0-only
import 'dart:async';

import 'package:core/core.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// 検索(docs/04): 品種+出品の横断検索。
class SearchResultScreen extends StatefulWidget {
  const SearchResultScreen({super.key});

  @override
  State<SearchResultScreen> createState() => _SearchResultScreenState();
}

class _SearchResultScreenState extends State<SearchResultScreen> {
  final _query = TextEditingController();
  Timer? _debounce;
  List<Variety> _varieties = [];
  List<Listing> _listings = [];
  bool _searching = false;
  String? _error;

  @override
  void dispose() {
    _debounce?.cancel();
    _query.dispose();
    super.dispose();
  }

  void _onText(String text) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () => _search(text));
  }

  Future<void> _search(String text) async {
    final q = text.trim();
    if (q.isEmpty) {
      setState(() {
        _varieties = [];
        _listings = [];
        _error = null;
      });
      return;
    }
    setState(() {
      _searching = true;
      _error = null;
    });
    try {
      final varieties = await ApiClient.i.searchVarieties(q);
      final listings = await ApiClient.i.fetchListings(q: q);
      if (mounted) {
        setState(() {
          _varieties = varieties;
          _listings = listings;
          _searching = false;
        });
      }
    } on ApiException {
      if (mounted) {
        setState(() {
          _searching = false;
          _error = 'メンテナンス中です';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.of(context).size.width >= 600;
    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _query,
          onChanged: _onText,
          autofocus: false,
          decoration: const InputDecoration(
            hintText: '品種名・キーワードで検索',
            border: InputBorder.none,
          ),
        ),
      ),
      body: _error != null
          ? Center(child: Text(_error!))
          : _searching
              ? const Center(child: CircularProgressIndicator())
              : ListView(
                  padding: const EdgeInsets.all(12),
                  children: [
                    if (_varieties.isNotEmpty) ...[
                      const Text('品種(辞典)',
                          style: TextStyle(fontWeight: FontWeight.bold)),
                      for (final variety in _varieties)
                        ListTile(
                          leading: const Icon(Icons.menu_book,
                              color: SeedColors.green),
                          title: Text(variety.name),
                          subtitle: variety.summary != null
                              ? Text(variety.summary!,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis)
                              : null,
                          onTap: () => context.go('/v/${variety.id}'),
                        ),
                      const Divider(),
                    ],
                    if (_listings.isNotEmpty) ...[
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 8),
                        child: Text('出品',
                            style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                      GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate:
                            SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: wide ? 4 : 2,
                          mainAxisSpacing: 8,
                          crossAxisSpacing: 8,
                          childAspectRatio: 0.62,
                        ),
                        itemCount: _listings.length,
                        itemBuilder: (context, i) => ListingCard(
                          listing: _listings[i],
                          onTap: () => context.go('/l/${_listings[i].id}'),
                        ),
                      ),
                    ],
                    if (_query.text.trim().isNotEmpty &&
                        _varieties.isEmpty &&
                        _listings.isEmpty)
                      const Center(
                        child: Padding(
                          padding: EdgeInsets.all(24),
                          child: Text('見つかりませんでした'),
                        ),
                      ),
                  ],
                ),
    );
  }
}
