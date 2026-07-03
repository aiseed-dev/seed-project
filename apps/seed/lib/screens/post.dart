// SPDX-License-Identifier: AGPL-3.0-only
import 'package:core/core.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../widgets/seed_label_fields.dart';

/// 出品(docs/04 PostListingScreen・ステップ形式1画面)。
/// 写真アップロード(image_picker)は投稿後の詳細画面から行う形で Phase 2 では省略。
class PostListingScreen extends StatefulWidget {
  const PostListingScreen({super.key});

  @override
  State<PostListingScreen> createState() => _PostListingScreenState();
}

class _PostListingScreenState extends State<PostListingScreen> {
  List<Category>? _categories;
  int? _categoryId;
  String _varietyName = '';
  Variety? _variety;
  String _itemKind = 'seed';
  String _listingType = 'exchange';
  String _delivery = 'mail';
  String _payment = 'later';
  final _title = TextEditingController();
  final _desired = TextEditingController();
  final _price = TextEditingController();
  final _harvestYear = TextEditingController();
  final _region = TextEditingController();
  final _note = TextEditingController();
  bool _selfSaved = false;
  bool _confirmed = false; // 種苗法の確認チェック
  bool _seedLabel = false;
  final _labelName = TextEditingController();
  final _labelAddress = TextEditingController();
  final _labelArea = TextEditingController();
  final _labelGermination = TextEditingController();
  final _labelTreatment = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadCategories();
  }

  @override
  void dispose() {
    for (final c in [
      _title, _desired, _price, _harvestYear, _region, _note,
      _labelName, _labelAddress, _labelArea, _labelGermination,
      _labelTreatment,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _loadCategories() async {
    try {
      final rows = await ApiClient.i.fetchCategories();
      if (mounted) setState(() => _categories = rows);
    } on ApiException {
      if (mounted) setState(() => _error = '分類を読み込めませんでした');
    }
  }

  bool get _canSubmit =>
      _confirmed &&
      !_busy &&
      _categoryId != null &&
      _varietyName.trim().isNotEmpty &&
      _title.text.trim().isNotEmpty;

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
      final listing = await ApiClient.i.createListing({
        if (_variety != null) 'variety_id': _variety!.id,
        if (_variety == null) 'variety_name_free': _varietyName.trim(),
        'category_id': _categoryId,
        'title': _title.text.trim(),
        'description': _note.text.trim(),
        'item_kind': _itemKind,
        'listing_type': _listingType,
        if (_listingType == 'sell')
          'price_yen': int.tryParse(_price.text.trim()),
        if (_listingType == 'exchange')
          'desired_trade': _desired.text.trim(),
        if (_harvestYear.text.trim().isNotEmpty)
          'harvest_year': int.tryParse(_harvestYear.text.trim()),
        'is_self_saved': _selfSaved,
        if (_region.text.trim().isNotEmpty) 'region': _region.text.trim(),
        'delivery_method': _delivery,
        'payment_default': _payment,
        'requires_seed_label': _seedLabel,
        if (_seedLabel) ...{
          'label_seller_name': _labelName.text.trim(),
          'label_seller_address': _labelAddress.text.trim(),
          'label_production_area': _labelArea.text.trim(),
          'label_germination_rate': _labelGermination.text.trim(),
          if (_labelTreatment.text.trim().isNotEmpty)
            'label_seed_treatment': _labelTreatment.text.trim(),
        },
        'non_registered_confirmed': _confirmed,
      });
      if (mounted) context.go('/l/${listing.id}');
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
      appBar: AppBar(title: const Text('出品する')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _categoryChips(),
          const SizedBox(height: 12),
          VarietySuggestField(
            onChanged: (name, selected) => setState(() {
              _varietyName = name;
              _variety = selected;
            }),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _title,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(
                labelText: 'タイトル', border: OutlineInputBorder()),
          ),
          const SizedBox(height: 12),
          _choice('品目', ['seed', 'seedling'], {
            'seed': '種',
            'seedling': '苗',
          }, _itemKind, (v) => setState(() => _itemKind = v)),
          _choice('取引', ['exchange', 'sell', 'give'], {
            'exchange': '交換',
            'sell': '販売',
            'give': '譲渡',
          }, _listingType, (v) => setState(() => _listingType = v)),
          _choice('受け渡し', ['mail', 'direct'], {
            'mail': '郵送',
            'direct': '直接',
          }, _delivery, (v) => setState(() => _delivery = v)),
          _choice('支払い', ['later', 'prepay', 'cod'], {
            'later': '後払い(既定)',
            'prepay': '前払い',
            'cod': '着払い',
          }, _payment, (v) => setState(() => _payment = v)),
          const SizedBox(height: 12),
          if (_listingType == 'exchange')
            TextField(
              controller: _desired,
              decoration: const InputDecoration(
                  labelText: '希望する品', border: OutlineInputBorder()),
            ),
          if (_listingType == 'sell')
            TextField(
              controller: _price,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                  labelText: '価格(円)', border: OutlineInputBorder()),
            ),
          const SizedBox(height: 12),
          TextField(
            controller: _harvestYear,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
                labelText: '採種年(任意)', border: OutlineInputBorder()),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('自家採種'),
            value: _selfSaved,
            onChanged: (v) => setState(() => _selfSaved = v),
          ),
          TextField(
            controller: _region,
            decoration: const InputDecoration(
                labelText: '地域(都道府県・任意)', border: OutlineInputBorder()),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _note,
            maxLines: 3,
            decoration: const InputDecoration(
                labelText: '説明・栽培メモ(任意)', border: OutlineInputBorder()),
          ),
          const Divider(height: 32),
          SeedLabelFields(
            enabled: _seedLabel,
            onToggle: (v) => setState(() => _seedLabel = v),
            sellerName: _labelName,
            sellerAddress: _labelAddress,
            productionArea: _labelArea,
            germinationRate: _labelGermination,
            seedTreatment: _labelTreatment,
            isSeed: _itemKind == 'seed',
          ),
          const Divider(height: 32),
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('品種登録されていない一般品種(固定種・在来種)です'),
            subtitle: const Text(
              '登録品種の種苗を無断で譲渡・販売することは種苗法で禁じられています',
              style: TextStyle(fontSize: 11),
            ),
            value: _confirmed,
            onChanged: (v) => setState(() => _confirmed = v ?? false),
          ),
          if (_error != null)
            Text(_error!,
                style: const TextStyle(color: Colors.red, fontSize: 12)),
          const SizedBox(height: 8),
          FilledButton(
            onPressed: _canSubmit ? _submit : null,
            child: Text(_busy ? '送信中…' : '出品する'),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _categoryChips() {
    final categories = _categories;
    if (categories == null) {
      return const Center(child: CircularProgressIndicator());
    }
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        for (final c in categories)
          ChoiceChip(
            label: Text(c.name),
            selected: _categoryId == c.id,
            onSelected: (_) => setState(() => _categoryId = c.id),
          ),
      ],
    );
  }

  Widget _choice(
    String label,
    List<String> values,
    Map<String, String> names,
    String current,
    ValueChanged<String> onChanged,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          SizedBox(
              width: 72,
              child: Text(label, style: const TextStyle(fontSize: 12))),
          Expanded(
            child: Wrap(
              spacing: 6,
              children: [
                for (final v in values)
                  ChoiceChip(
                    label: Text(names[v]!),
                    selected: current == v,
                    onSelected: (_) => onChanged(v),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
