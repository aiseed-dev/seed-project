// SPDX-License-Identifier: AGPL-3.0-only
import 'package:core/core.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// 分類別一覧(docs/04 CategoryListingsScreen)。カーソル方式の無限スクロール。
class CategoryListingsScreen extends StatefulWidget {
  const CategoryListingsScreen({super.key, required this.slug});

  final String slug;

  @override
  State<CategoryListingsScreen> createState() => _CategoryListingsScreenState();
}

class _CategoryListingsScreenState extends State<CategoryListingsScreen> {
  final _scroll = ScrollController();
  final List<Listing> _items = [];
  String? _cursor;
  bool _loading = false;
  bool _done = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
    _load();
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scroll.position.pixels > _scroll.position.maxScrollExtent - 300) {
      _load();
    }
  }

  Future<void> _load() async {
    if (_loading || _done) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final page = await ApiClient.i.fetchListings(
        category: widget.slug,
        cursor: _cursor,
        limit: 20,
      );
      if (!mounted) return;
      setState(() {
        _items.addAll(page);
        _loading = false;
        if (page.length < 20) {
          _done = true;
        } else {
          _cursor = page.last.createdAt;
        }
      });
    } on ApiException {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = '読み込めませんでした';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.of(context).size.width >= 600;
    return Scaffold(
      appBar: AppBar(title: Text(widget.slug)),
      body: _items.isEmpty && _loading
          ? const Center(child: CircularProgressIndicator())
          : _items.isEmpty && _error != null
              ? Center(
                  child: TextButton(
                      onPressed: _load, child: Text('$_error(再試行)')),
                )
              : _items.isEmpty
                  ? const Center(child: Text('この分類の出品はまだありません'))
                  : GridView.builder(
                      controller: _scroll,
                      padding: const EdgeInsets.all(12),
                      gridDelegate:
                          SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: wide ? 4 : 2,
                        mainAxisSpacing: 8,
                        crossAxisSpacing: 8,
                        childAspectRatio: 0.62,
                      ),
                      itemCount: _items.length,
                      itemBuilder: (context, i) => ListingCard(
                        listing: _items[i],
                        onTap: () => context.go('/l/${_items[i].id}'),
                      ),
                    ),
    );
  }
}
