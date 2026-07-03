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

class Provider {
  const Provider({
    required this.kind,
    required this.id,
    required this.name,
    this.isVerified = false,
  });

  factory Provider.fromJson(Map<String, dynamic> json) => Provider(
        kind: json['kind'] as String,
        id: json['id'] as String,
        name: json['name'] as String,
        isVerified: (json['is_verified'] as bool?) ?? false,
      );

  final String kind; // user / shop
  final String id;
  final String name;
  final bool isVerified;
}

class CartLine {
  const CartLine({
    required this.listingId,
    required this.title,
    required this.listingType,
    required this.quantity,
    required this.status,
    this.priceYen,
  });

  factory CartLine.fromJson(Map<String, dynamic> json) => CartLine(
        listingId: json['listing_id'] as String,
        title: json['title'] as String,
        listingType: json['listing_type'] as String,
        priceYen: json['price_yen'] as int?,
        quantity: json['quantity'] as int,
        status: json['status'] as String,
      );

  final String listingId;
  final String title;
  final String listingType;
  final int? priceYen;
  final int quantity;
  final String status; // active 以外は「入手できなくなりました」
}

class CartGroup {
  const CartGroup({
    required this.provider,
    required this.items,
    this.subtotalYen,
  });

  factory CartGroup.fromJson(Map<String, dynamic> json) => CartGroup(
        provider:
            Provider.fromJson(json['provider'] as Map<String, dynamic>),
        items: (json['items'] as List<dynamic>)
            .map((i) => CartLine.fromJson(i as Map<String, dynamic>))
            .toList(),
        subtotalYen: json['subtotal_yen'] as int?,
      );

  final Provider provider;
  final List<CartLine> items;
  final int? subtotalYen; // 販売品の小計(送料別)。null=販売品なし
}

class RequestItem {
  const RequestItem({
    required this.listingId,
    required this.title,
    required this.listingType,
    required this.quantity,
    this.priceYen,
  });

  factory RequestItem.fromJson(Map<String, dynamic> json) => RequestItem(
        listingId: json['listing_id'] as String,
        title: json['title'] as String,
        listingType: json['listing_type'] as String,
        priceYen: json['price_yen'] as int?,
        quantity: json['quantity'] as int,
      );

  final String listingId;
  final String title;
  final String listingType;
  final int? priceYen;
  final int quantity;
}

class TradeRequest {
  const TradeRequest({
    required this.id,
    required this.requestNo,
    required this.requesterId,
    required this.status,
    required this.createdAt,
    this.providerUserId,
    this.providerShopId,
    this.note,
    this.acceptedAt,
    this.completedAt,
    this.items = const [],
  });

  factory TradeRequest.fromJson(Map<String, dynamic> json) => TradeRequest(
        id: json['id'] as String,
        requestNo: json['request_no'] as String,
        requesterId: json['requester_id'] as String,
        providerUserId: json['provider_user_id'] as String?,
        providerShopId: json['provider_shop_id'] as String?,
        status: json['status'] as String,
        note: json['note'] as String?,
        createdAt: json['created_at'] as String,
        acceptedAt: json['accepted_at'] as String?,
        completedAt: json['completed_at'] as String?,
        items: ((json['items'] as List<dynamic>?) ?? [])
            .map((i) => RequestItem.fromJson(i as Map<String, dynamic>))
            .toList(),
      );

  final String id;
  final String requestNo; // 申込番号(年+連番)
  final String requesterId;
  final String? providerUserId;
  final String? providerShopId;
  final String status;
  final String? note;
  final String createdAt;
  final String? acceptedAt;
  final String? completedAt;
  final List<RequestItem> items;
}

class TradeRequestEntry {
  const TradeRequestEntry({
    required this.request,
    required this.role,
    required this.itemCount,
    this.lastMessage,
  });

  factory TradeRequestEntry.fromJson(Map<String, dynamic> json) =>
      TradeRequestEntry(
        request:
            TradeRequest.fromJson(json['request'] as Map<String, dynamic>),
        role: json['role'] as String,
        itemCount: json['item_count'] as int,
        lastMessage: json['last_message'] as String?,
      );

  final TradeRequest request;
  final String role; // requester / provider
  final int itemCount;
  final String? lastMessage;
}

class Message {
  const Message({
    required this.id,
    required this.senderId,
    required this.body,
    required this.sentAt,
    this.readAt,
  });

  factory Message.fromJson(Map<String, dynamic> json) => Message(
        id: json['id'] as String,
        senderId: json['sender_id'] as String,
        body: json['body'] as String,
        sentAt: json['sent_at'] as String,
        readAt: json['read_at'] as String?,
      );

  final String id;
  final String senderId;
  final String body;
  final String sentAt;
  final String? readAt;
}

class Article {
  const Article({
    required this.varietyId,
    required this.varietyName,
    required this.content,
    this.updatedAt,
  });

  factory Article.fromJson(Map<String, dynamic> json) => Article(
        varietyId: json['variety_id'] as String,
        varietyName: json['variety_name'] as String,
        content: ((json['content'] as Map<String, dynamic>?) ?? {})
            .map((k, v) => MapEntry(k, v as String)),
        updatedAt: json['updated_at'] as String?,
      );

  final String varietyId;
  final String varietyName;

  /// セクション構造: history / cultivation / seed_saving / cooking / sources
  final Map<String, String> content;
  final String? updatedAt;
}

class RevisionSummary {
  const RevisionSummary({
    required this.id,
    required this.status,
    required this.createdAt,
    this.editSummary,
    this.reviewNote,
  });

  factory RevisionSummary.fromJson(Map<String, dynamic> json) =>
      RevisionSummary(
        id: json['id'] as String,
        status: json['status'] as String,
        createdAt: json['created_at'] as String,
        editSummary: json['edit_summary'] as String?,
        reviewNote: json['review_note'] as String?,
      );

  final String id;
  final String status; // pending / approved / rejected
  final String createdAt;
  final String? editSummary;
  final String? reviewNote;
}

class RevisionQueueEntry {
  const RevisionQueueEntry({
    required this.revision,
    required this.varietyName,
    required this.authorName,
  });

  factory RevisionQueueEntry.fromJson(Map<String, dynamic> json) =>
      RevisionQueueEntry(
        revision: RevisionSummary.fromJson(
            json['revision'] as Map<String, dynamic>),
        varietyName: json['variety_name'] as String,
        authorName: json['author_name'] as String,
      );

  final RevisionSummary revision;
  final String varietyName;
  final String authorName;
}

class DiffLine {
  const DiffLine({required this.text, required this.op});

  factory DiffLine.fromJson(Map<String, dynamic> json) =>
      DiffLine(text: json['text'] as String, op: json['op'] as String);

  final String text;
  final String op; // keep / add / del
}

class RevisionDetail {
  const RevisionDetail({
    required this.revision,
    required this.varietyName,
    required this.content,
    required this.diff,
  });

  factory RevisionDetail.fromJson(Map<String, dynamic> json) => RevisionDetail(
        revision: RevisionSummary.fromJson(
            json['revision'] as Map<String, dynamic>),
        varietyName: json['variety_name'] as String,
        content: ((json['content'] as Map<String, dynamic>?) ?? {})
            .map((k, v) => MapEntry(k, v as String)),
        diff: ((json['diff'] as Map<String, dynamic>?) ?? {}).map(
          (k, v) => MapEntry(
            k,
            (v as List<dynamic>)
                .map((l) => DiffLine.fromJson(l as Map<String, dynamic>))
                .toList(),
          ),
        ),
      );

  final RevisionSummary revision;
  final String varietyName;
  final Map<String, String> content;
  final Map<String, List<DiffLine>> diff;
}

class Me {
  const Me({
    required this.id,
    required this.displayName,
    required this.role,
    this.region,
    this.bio,
  });

  factory Me.fromJson(Map<String, dynamic> json) => Me(
        id: json['id'] as String,
        displayName: json['display_name'] as String,
        region: json['region'] as String?,
        bio: json['bio'] as String?,
        role: json['role'] as String,
      );

  final String id;
  final String displayName;
  final String? region;
  final String? bio;
  final String role; // user / editor / moderator / admin

  bool get isEditor => role != 'user';
}
