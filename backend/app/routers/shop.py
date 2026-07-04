# SPDX-License-Identifier: AGPL-3.0-only
"""店舗スタッフ API(docs/03)。shop_members 所属が前提。

在庫は扱わない(在庫の正は店側。店側在庫API連携は Phase 5a)。
"""

import csv
import datetime
import io

from fastapi import APIRouter, Depends, Query, UploadFile
from fastapi import Request as HttpRequest
from fastapi.responses import Response
from sqlalchemy import func, select
from sqlalchemy.orm import Session

from app.core.auth import require_user
from app.core.db import get_db
from app.core.errors import ApiError
from app.models import (
    AppUser,
    Category,
    Listing,
    Request,
    RequestItem,
    Shop,
    ShopMember,
)
from app.schemas.listings import ListingOut
from app.schemas.requests import RequestListEntry, RequestOut
from app.schemas.shop import (
    BulkAction,
    ContactLabelPatch,
    ImportResult,
    ImportRowResult,
    MemberOut,
    ShopOut,
    ShopPatch,
    ShopStatsRow,
)
from app.services import xlsx
from app.services.variety import resolve_free_name

router = APIRouter(tags=["shop"])

CSV_HEADERS = [
    "品種名",
    "分類slug",
    "種苗区分",
    "種別",
    "価格",
    "数量表記",
    "採種年",
    "生産地",
    "発芽率",
    "種子消毒",
    "説明",
    "栽培メモ",
]


def shop_context(
    request: HttpRequest,
    user_id: str = Depends(require_user),
    db: Session = Depends(get_db),
) -> tuple[str, Shop, ShopMember]:
    member = db.scalars(select(ShopMember).where(ShopMember.user_id == user_id)).first()
    if member is None:
        raise ApiError(403, "NOT_SHOP_STAFF", "店舗アカウントが必要です")
    shop = db.get(Shop, member.shop_id)
    if shop is None or not shop.is_active:
        raise ApiError(403, "SHOP_INACTIVE", "店舗が有効ではありません")
    return user_id, shop, member


@router.get("/shop")
def get_shop(
    ctx: tuple[str, Shop, ShopMember] = Depends(shop_context),
) -> ShopOut:
    return ShopOut.model_validate(ctx[1])


@router.patch("/shop")
def patch_shop(
    payload: ShopPatch,
    ctx: tuple[str, Shop, ShopMember] = Depends(shop_context),
    db: Session = Depends(get_db),
) -> ShopOut:
    _, shop, member = ctx
    if member.role != "owner":
        raise ApiError(403, "NOT_OWNER", "店舗オーナーのみ変更できます")
    for field, value in payload.model_dump(exclude_unset=True).items():
        setattr(shop, field, value)
    db.commit()
    db.refresh(shop)
    return ShopOut.model_validate(shop)


@router.get("/shop/members")
def list_members(
    ctx: tuple[str, Shop, ShopMember] = Depends(shop_context),
    db: Session = Depends(get_db),
) -> list[MemberOut]:
    rows = db.execute(
        select(ShopMember, AppUser)
        .join(AppUser, ShopMember.user_id == AppUser.id)
        .where(ShopMember.shop_id == ctx[1].id)
    ).all()
    return [
        MemberOut(
            user_id=member.user_id,
            display_name=user.display_name,
            role=member.role,
            contact_label=member.contact_label,
        )
        for member, user in rows
    ]


@router.patch("/shop/me")
def patch_contact_label(
    payload: ContactLabelPatch,
    ctx: tuple[str, Shop, ShopMember] = Depends(shop_context),
    db: Session = Depends(get_db),
) -> MemberOut:
    user_id, _, member = ctx
    member.contact_label = payload.contact_label
    db.commit()
    user = db.get(AppUser, user_id)
    return MemberOut(
        user_id=user_id,
        display_name=user.display_name if user else "",
        role=member.role,
        contact_label=member.contact_label,
    )


@router.get("/shop/listings")
def shop_listings(
    ctx: tuple[str, Shop, ShopMember] = Depends(shop_context),
    db: Session = Depends(get_db),
) -> list[ListingOut]:
    rows = db.scalars(
        select(Listing)
        .where(Listing.shop_id == ctx[1].id)
        .order_by(Listing.updated_at.desc())
    ).all()
    return [ListingOut.model_validate(row) for row in rows]


@router.post("/shop/listings/bulk")
def bulk_action(
    payload: BulkAction,
    ctx: tuple[str, Shop, ShopMember] = Depends(shop_context),
    db: Session = Depends(get_db),
) -> dict[str, int]:
    if payload.action == "price" and payload.price_yen is None:
        raise ApiError(422, "PRICE_REQUIRED", "価格を指定してください")
    rows = db.scalars(
        select(Listing).where(Listing.shop_id == ctx[1].id, Listing.id.in_(payload.ids))
    ).all()
    for listing in rows:
        if payload.action == "publish":
            listing.status = "active"
        elif payload.action == "close":
            listing.status = "closed"
        else:
            listing.price_yen = payload.price_yen
    db.commit()
    return {"updated": len(rows)}


def _import_row(
    db: Session, shop: Shop, user_id: str, record: dict[str, str]
) -> tuple[str, Listing | None, str | None]:
    """1行を出品にする。(status, listing, detail)"""
    name = (record.get("品種名") or "").strip()
    if not name:
        return "error", None, "品種名がありません"
    slug = (record.get("分類slug") or "").strip()
    category = db.scalars(select(Category).where(Category.slug == slug)).first()
    if category is None:
        return "error", None, f"分類slugが不正です: {slug}"
    try:
        price = int(record.get("価格") or "")
    except ValueError:
        return "error", None, "価格が数値ではありません"
    item_kind = "seedling" if (record.get("種苗区分") or "").strip() == "苗" else "seed"
    germination = (record.get("発芽率") or "").strip()
    production_area = (record.get("生産地") or "").strip()
    # 指定種苗の表示義務: 店舗出品は必須(種子は発芽率も)
    if not production_area or (item_kind == "seed" and not germination):
        return "error", None, "指定種苗の表示(生産地、種子は発芽率)が必要です"
    if not shop.region:
        return "error", None, "店舗プロフィールに住所(地域)が未設定です"

    variety = resolve_free_name(db, name, category.id, user_id)
    status = "proposed" if variety.status == "pending" else "created"

    harvest_year: int | None = None
    if (record.get("採種年") or "").strip():
        try:
            harvest_year = int(record["採種年"])
        except ValueError:
            return "error", None, "採種年が数値ではありません"

    listing = Listing(
        user_id=user_id,
        shop_id=shop.id,
        variety_id=variety.id,
        variety_name_free=name,
        category_id=category.id,
        title=name,
        description=(record.get("説明") or "").strip(),
        item_kind=item_kind,
        listing_type="sell",
        price_yen=price,
        quantity_note=(record.get("数量表記") or "").strip() or None,
        harvest_year=harvest_year,
        cultivation_note=(record.get("栽培メモ") or "").strip() or None,
        requires_seed_label=True,  # 店舗出品は固定
        label_seller_name=shop.name,
        label_seller_address=shop.region,  # 店舗プロフィールから補完
        label_production_area=production_area,
        label_germination_rate=germination or None,
        label_seed_treatment=(record.get("種子消毒") or "").strip() or None,
        no_warranty=False,
        non_registered_confirmed=True,
    )
    db.add(listing)
    db.flush()
    return status, listing, None


@router.post("/shop/listings/import")
async def import_csv(
    file: UploadFile,
    ctx: tuple[str, Shop, ShopMember] = Depends(shop_context),
    db: Session = Depends(get_db),
) -> ImportResult:
    user_id, shop, _ = ctx
    text = (await file.read()).decode("utf-8-sig")
    reader = csv.DictReader(io.StringIO(text))
    missing = set(CSV_HEADERS) - set(reader.fieldnames or [])
    if missing:
        raise ApiError(422, "CSV_HEADER", f"ヘッダが不足: {', '.join(sorted(missing))}")

    results: list[ImportRowResult] = []
    counts = {"created": 0, "proposed": 0, "error": 0}
    for index, record in enumerate(reader, start=1):
        try:
            status, listing, detail = _import_row(db, shop, user_id, record)
        except ApiError as e:  # 登録品種は行エラーにする(全体は続行)
            status, listing, detail = "error", None, e.detail
        counts[status] += 1
        results.append(
            ImportRowResult(
                row=index,
                status=status,  # type: ignore[arg-type]
                name=(record.get("品種名") or "").strip(),
                detail=detail,
                listing_id=listing.id if listing else None,
            )
        )
    db.commit()
    return ImportResult(
        created=counts["created"],
        proposed=counts["proposed"],
        errors=counts["error"],
        rows=results,
    )


@router.get("/shop/requests")
def shop_requests(
    ctx: tuple[str, Shop, ShopMember] = Depends(shop_context),
    db: Session = Depends(get_db),
) -> list[RequestListEntry]:
    rows = db.scalars(
        select(Request)
        .where(Request.provider_shop_id == ctx[1].id)
        .order_by(Request.status != "requested", Request.created_at.desc())
    ).all()
    entries = []
    for request in rows:
        count = db.scalar(
            select(func.count()).where(RequestItem.request_id == request.id)
        )
        entries.append(
            RequestListEntry(
                request=RequestOut.model_validate(request),
                role="provider",
                item_count=count or 0,
                last_message=None,
            )
        )
    return entries


@router.get("/shop/stats")
def shop_stats(
    ctx: tuple[str, Shop, ShopMember] = Depends(shop_context),
    db: Session = Depends(get_db),
) -> list[ShopStatsRow]:
    """出品ごとの申込み数(閲覧数はスキーマに無いため対象外)。"""
    rows = db.execute(
        select(Listing, func.count(RequestItem.listing_id))
        .outerjoin(RequestItem, RequestItem.listing_id == Listing.id)
        .where(Listing.shop_id == ctx[1].id)
        .group_by(Listing.id)
        .order_by(Listing.updated_at.desc())
    ).all()
    return [
        ShopStatsRow(
            listing_id=listing.id,
            title=listing.title,
            status=listing.status,
            request_count=count,
        )
        for listing, count in rows
    ]


@router.get("/shop/export")
def shop_export(
    kind: str = Query(pattern="^(listings|deals)$"),
    format: str = Query(default="xlsx", pattern="^(xlsx|csv)$"),
    ctx: tuple[str, Shop, ShopMember] = Depends(shop_context),
    db: Session = Depends(get_db),
) -> Response:
    _, shop, _ = ctx
    if kind == "listings":
        headers = xlsx.LISTING_HEADERS
        rows = [
            [
                listing.variety_name_free or "",
                listing.title,
                listing.listing_type,
                listing.price_yen,
                listing.status,
                listing.created_at.date().isoformat(),
            ]
            for listing in db.scalars(
                select(Listing).where(Listing.shop_id == shop.id)
            ).all()
        ]
    else:
        # 成約台帳(経理向け)。自店分のみ
        headers = xlsx.DEAL_HEADERS
        rows = []
        deals = db.scalars(
            select(Request)
            .where(
                Request.provider_shop_id == shop.id,
                Request.status == "completed",
            )
            .order_by(Request.completed_at)
        ).all()
        for request in deals:
            requester = db.get(AppUser, request.requester_id)
            accepted_by = (
                db.scalars(
                    select(ShopMember.contact_label).where(
                        ShopMember.shop_id == shop.id,
                        ShopMember.user_id == request.accepted_by,
                    )
                ).first()
                or request.accepted_by
                or ""
            )
            items = db.execute(
                select(RequestItem, Listing)
                .join(Listing, RequestItem.listing_id == Listing.id)
                .where(RequestItem.request_id == request.id)
            ).all()
            for item, listing in items:
                rows.append(
                    [
                        request.request_no,
                        shop.code,
                        request.created_at.date().isoformat(),
                        request.accepted_at.date().isoformat()
                        if request.accepted_at
                        else "",
                        accepted_by,
                        request.completed_at.date().isoformat()
                        if request.completed_at
                        else "",
                        requester.display_name if requester else "",
                        listing.title,
                        item.quantity,
                        (listing.price_yen or 0) * item.quantity,
                    ]
                )
    stamp = datetime.date.today().isoformat()
    if format == "xlsx":
        payload = xlsx.to_xlsx(headers, rows, kind)
        media = "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"
        filename = f"{kind}-{stamp}.xlsx"
    else:
        payload = xlsx.to_csv(headers, rows)
        media = "text/csv"
        filename = f"{kind}-{stamp}.csv"
    return Response(
        content=payload,
        media_type=media,
        headers={"Content-Disposition": f'attachment; filename="{filename}"'},
    )
