// SPDX-License-Identifier: MIT
// モデル(fromJson 手書き。コード生成は使わない)。API 仕様の正は docs/03。

class Category {
  const Category({
    required this.id,
    required this.slug,
    required this.name,
    this.icon,
    this.sortOrder = 0,
  });

  factory Category.fromJson(Map<String, dynamic> json) => Category(
        id: json['id'] as int,
        slug: json['slug'] as String,
        name: json['name'] as String,
        icon: json['icon'] as String?,
        sortOrder: (json['sort_order'] as int?) ?? 0,
      );

  final int id;
  final String slug;
  final String name;
  final String? icon;
  final int sortOrder;
}

class ListingPhoto {
  const ListingPhoto({required this.id, required this.path});

  factory ListingPhoto.fromJson(Map<String, dynamic> json) => ListingPhoto(
        id: json['id'] as String,
        path: json['path'] as String,
      );

  final String id;
  final String path;
}

class Listing {
  const Listing({
    required this.id,
    required this.userId,
    required this.categoryId,
    required this.title,
    required this.description,
    required this.itemKind,
    required this.listingType,
    required this.noWarranty,
    required this.requiresSeedLabel,
    required this.deliveryMethod,
    required this.paymentDefault,
    required this.status,
    required this.createdAt,
    this.shopId,
    this.varietyId,
    this.varietyNameFree,
    this.priceYen,
    this.desiredTrade,
    this.quantityNote,
    this.harvestYear,
    this.isSelfSaved = false,
    this.region,
    this.cultivationNote,
    this.labelSellerName,
    this.labelSellerAddress,
    this.labelProductionArea,
    this.labelGerminationRate,
    this.labelSeedTreatment,
    this.photos = const [],
  });

  factory Listing.fromJson(Map<String, dynamic> json) => Listing(
        id: json['id'] as String,
        userId: json['user_id'] as String,
        shopId: json['shop_id'] as String?,
        varietyId: json['variety_id'] as String?,
        varietyNameFree: json['variety_name_free'] as String?,
        categoryId: json['category_id'] as int,
        title: json['title'] as String,
        description: (json['description'] as String?) ?? '',
        itemKind: json['item_kind'] as String,
        listingType: json['listing_type'] as String,
        priceYen: json['price_yen'] as int?,
        desiredTrade: json['desired_trade'] as String?,
        quantityNote: json['quantity_note'] as String?,
        harvestYear: json['harvest_year'] as int?,
        isSelfSaved: (json['is_self_saved'] as bool?) ?? false,
        region: json['region'] as String?,
        cultivationNote: json['cultivation_note'] as String?,
        noWarranty: (json['no_warranty'] as bool?) ?? true,
        requiresSeedLabel: (json['requires_seed_label'] as bool?) ?? false,
        labelSellerName: json['label_seller_name'] as String?,
        labelSellerAddress: json['label_seller_address'] as String?,
        labelProductionArea: json['label_production_area'] as String?,
        labelGerminationRate: json['label_germination_rate'] as String?,
        labelSeedTreatment: json['label_seed_treatment'] as String?,
        deliveryMethod: (json['delivery_method'] as String?) ?? 'mail',
        paymentDefault: (json['payment_default'] as String?) ?? 'later',
        status: (json['status'] as String?) ?? 'active',
        createdAt: json['created_at'] as String,
        photos: ((json['photos'] as List<dynamic>?) ?? [])
            .map((p) => ListingPhoto.fromJson(p as Map<String, dynamic>))
            .toList(),
      );

  final String id;
  final String userId;
  final String? shopId;
  final String? varietyId;
  final String? varietyNameFree;
  final int categoryId;
  final String title;
  final String description;
  final String itemKind; // seed / seedling / produce
  final String listingType; // exchange / sell / give
  final int? priceYen;
  final String? desiredTrade;
  final String? quantityNote;
  final int? harvestYear;
  final bool isSelfSaved;
  final String? region;
  final String? cultivationNote;
  final bool noWarranty;
  final bool requiresSeedLabel;
  final String? labelSellerName;
  final String? labelSellerAddress;
  final String? labelProductionArea;
  final String? labelGerminationRate;
  final String? labelSeedTreatment;
  final String deliveryMethod; // direct / mail
  final String paymentDefault; // later / prepay / cod
  final String status;
  final String createdAt; // ISO 8601(ページングのカーソルに使う)
  final List<ListingPhoto> photos;
}

class Variety {
  const Variety({
    required this.id,
    required this.name,
    required this.categoryId,
    required this.seedType,
    required this.status,
    this.kana,
    this.aliases = const [],
    this.cropId,
    this.cropName,
    this.summary,
  });

  factory Variety.fromJson(Map<String, dynamic> json) => Variety(
        id: json['id'] as String,
        name: json['name'] as String,
        kana: json['kana'] as String?,
        aliases: ((json['aliases'] as List<dynamic>?) ?? [])
            .map((a) => a as String)
            .toList(),
        categoryId: json['category_id'] as int,
        cropId: json['crop_id'] as String?,
        cropName: json['crop_name'] as String?,
        seedType: (json['seed_type'] as String?) ?? 'unknown',
        summary: json['summary'] as String?,
        status: (json['status'] as String?) ?? 'approved',
      );

  final String id;
  final String name;
  final String? kana;
  final List<String> aliases;
  final int categoryId;
  final String? cropId;
  final String? cropName;
  final String seedType; // fixed / native / unknown
  final String? summary;
  final String status;
}
