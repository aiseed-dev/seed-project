# SPDX-License-Identifier: AGPL-3.0-only
"""申込み API(docs/03)。カートから提供者ごとに送る取引の単位。

申込番号はデータベース全体の通し番号(年+5桁連番、例 2026-00042)。
採番は advisory lock で直列化し、その年の最大+1 を振る。
"""

import datetime
import uuid

from fastapi import APIRouter, Depends
from sqlalchemy import func, select, text
from sqlalchemy.orm import Session

from app.core.auth import require_user
from app.core.db import get_db
from app.core.errors import ApiError
from app.models import (
    CartItem,
    Listing,
    Message,
    Request,
    RequestItem,
    Review,
    ShopMember,
)
from app.schemas.requests import (
    MessageCreate,
    MessageOut,
    RequestCreate,
    RequestDetailOut,
    RequestItemOut,
    RequestListEntry,
    RequestOut,
    RequestPatch,
    ReviewCreate,
    ReviewOut,
)
from app.services import mail

router = APIRouter(tags=["requests"])

_NUMBERING_LOCK = 4649  # 採番の直列化に使う advisory lock キー


def next_request_no(db: Session, year: int) -> tuple[str, int]:
    """申込番号を採番する(行ロックでその年の最大+1)。"""
    db.execute(text("SELECT pg_advisory_xact_lock(:key)"), {"key": _NUMBERING_LOCK})
    max_seq = db.scalar(
        select(func.max(Request.request_seq)).where(Request.request_year == year)
    )
    seq = (max_seq or 0) + 1
    return f"{year}-{seq:05d}", seq


def _is_provider(db: Session, request: Request, user_id: str) -> bool:
    if request.provider_user_id is not None:
        return request.provider_user_id == user_id
    member = db.get(ShopMember, (request.provider_shop_id, user_id))
    return member is not None


def _party_or_404(db: Session, request_id: uuid.UUID, user_id: str) -> Request:
    request = db.get(Request, request_id)
    if request is None:
        raise ApiError(404, "NOT_FOUND", "申込みが見つかりません")
    if request.requester_id != user_id and not _is_provider(db, request, user_id):
        raise ApiError(404, "NOT_FOUND", "申込みが見つかりません")  # 存在を隠す
    return request


def _items_out(db: Session, request_id: uuid.UUID) -> list[RequestItemOut]:
    rows = db.execute(
        select(RequestItem, Listing)
        .join(Listing, RequestItem.listing_id == Listing.id)
        .where(RequestItem.request_id == request_id)
    ).all()
    return [
        RequestItemOut(
            listing_id=listing.id,
            title=listing.title,
            listing_type=listing.listing_type,
            price_yen=listing.price_yen,
            quantity=item.quantity,
        )
        for item, listing in rows
    ]


@router.post("/requests", status_code=201)
def create_request(
    payload: RequestCreate,
    user_id: str = Depends(require_user),
    db: Session = Depends(get_db),
) -> RequestDetailOut:
    # カート内の該当提供者分を request_items へ移す
    rows = db.execute(
        select(CartItem, Listing)
        .join(Listing, CartItem.listing_id == Listing.id)
        .where(CartItem.user_id == user_id)
    ).all()
    if payload.provider_kind == "shop":
        members = [
            (c, listing)
            for c, listing in rows
            if str(listing.shop_id) == payload.provider_id
        ]
    else:
        members = [
            (c, listing)
            for c, listing in rows
            if listing.shop_id is None and listing.user_id == payload.provider_id
        ]
    if not members:
        raise ApiError(422, "CART_EMPTY", "この提供者のカート品目がありません")
    if any(listing.status != "active" for _, listing in members):
        raise ApiError(409, "NOT_AVAILABLE", "取引中または終了した出品が含まれています")

    year = datetime.datetime.now(datetime.UTC).year
    request_no, seq = next_request_no(db, year)
    request = Request(
        requester_id=user_id,
        provider_user_id=(
            payload.provider_id if payload.provider_kind == "user" else None
        ),
        provider_shop_id=(
            uuid.UUID(payload.provider_id) if payload.provider_kind == "shop" else None
        ),
        request_no=request_no,
        request_year=year,
        request_seq=seq,
        note=payload.note,
    )
    db.add(request)
    db.flush()
    for cart_item, _listing in members:
        db.add(
            RequestItem(
                request_id=request.id,
                listing_id=cart_item.listing_id,
                quantity=cart_item.quantity,
            )
        )
        db.delete(cart_item)
    db.commit()
    db.refresh(request)

    # 提供者への即時メール(店舗宛はスタッフ全員)
    titles = "・".join(listing.title for _, listing in members)
    body = f"申込番号 {request_no}\n品目: {titles}\nアプリからご対応ください。"
    for recipient in _provider_user_ids(db, request):
        mail.send_to_user(
            recipient, f"[種の交換] 申込みが届きました({request_no})", body
        )

    return RequestDetailOut(
        **RequestOut.model_validate(request).model_dump(),
        items=_items_out(db, request.id),
    )


def _provider_user_ids(db: Session, request: Request) -> list[str]:
    if request.provider_user_id is not None:
        return [request.provider_user_id]
    rows = db.scalars(
        select(ShopMember.user_id).where(ShopMember.shop_id == request.provider_shop_id)
    ).all()
    return list(rows)


@router.get("/requests")
def list_requests(
    user_id: str = Depends(require_user), db: Session = Depends(get_db)
) -> list[RequestListEntry]:
    shop_ids = db.scalars(
        select(ShopMember.shop_id).where(ShopMember.user_id == user_id)
    ).all()
    stmt = (
        select(Request)
        .where(
            (Request.requester_id == user_id)
            | (Request.provider_user_id == user_id)
            | (Request.provider_shop_id.in_(shop_ids) if shop_ids else False)
        )
        .order_by(Request.updated_at.desc())
    )
    entries: list[RequestListEntry] = []
    for request in db.scalars(stmt).all():
        count = db.scalar(
            select(func.count()).where(RequestItem.request_id == request.id)
        )
        last = db.scalars(
            select(Message.body)
            .where(Message.request_id == request.id)
            .order_by(Message.sent_at.desc())
            .limit(1)
        ).first()
        entries.append(
            RequestListEntry(
                request=RequestOut.model_validate(request),
                role=("requester" if request.requester_id == user_id else "provider"),
                item_count=count or 0,
                last_message=last,
            )
        )
    return entries


@router.get("/requests/{request_id}")
def get_request(
    request_id: uuid.UUID,
    user_id: str = Depends(require_user),
    db: Session = Depends(get_db),
) -> RequestDetailOut:
    request = _party_or_404(db, request_id, user_id)
    return RequestDetailOut(
        **RequestOut.model_validate(request).model_dump(),
        items=_items_out(db, request.id),
    )


@router.patch("/requests/{request_id}")
def patch_request(
    request_id: uuid.UUID,
    payload: RequestPatch,
    user_id: str = Depends(require_user),
    db: Session = Depends(get_db),
) -> RequestOut:
    request = _party_or_404(db, request_id, user_id)
    is_provider = _is_provider(db, request, user_id)
    is_requester = request.requester_id == user_id
    now = datetime.datetime.now(datetime.UTC)
    status = payload.status

    allowed = (
        (
            status in ("accepted", "declined")
            and is_provider
            and request.status == "requested"
        )
        or (status == "cancelled" and is_requester and request.status == "requested")
        or (status == "completed" and request.status == "accepted")
    )
    if not allowed:
        raise ApiError(409, "INVALID_TRANSITION", "この操作はできません")

    request.status = status
    if status == "accepted":
        request.accepted_at = now
        request.accepted_by = user_id  # 承諾した担当者(経理・追跡用)
    if status == "completed":
        request.completed_at = now  # 売上計上の基準
    db.commit()
    db.refresh(request)

    if status in ("accepted", "declined"):
        label = "承諾されました" if status == "accepted" else "辞退されました"
        mail.send_to_user(
            request.requester_id,
            f"[種の交換] 申込みが{label}({request.request_no})",
            "アプリでメッセージを確認してください。",
        )
    return RequestOut.model_validate(request)


@router.get("/requests/{request_id}/messages")
def list_messages(
    request_id: uuid.UUID,
    user_id: str = Depends(require_user),
    db: Session = Depends(get_db),
) -> list[MessageOut]:
    request = _party_or_404(db, request_id, user_id)
    messages = db.scalars(
        select(Message)
        .where(Message.request_id == request.id)
        .order_by(Message.sent_at)
    ).all()
    # 開いたら相手のメッセージを既読にする
    now = datetime.datetime.now(datetime.UTC)
    for message in messages:
        if message.sender_id != user_id and message.read_at is None:
            message.read_at = now
    db.commit()
    return [MessageOut.model_validate(m) for m in messages]


@router.post("/requests/{request_id}/messages", status_code=201)
def post_message(
    request_id: uuid.UUID,
    payload: MessageCreate,
    user_id: str = Depends(require_user),
    db: Session = Depends(get_db),
) -> MessageOut:
    request = _party_or_404(db, request_id, user_id)
    message = Message(request_id=request.id, sender_id=user_id, body=payload.body)
    db.add(message)
    db.commit()
    db.refresh(message)
    return MessageOut.model_validate(message)


@router.post("/requests/{request_id}/reviews", status_code=201)
def post_review(
    request_id: uuid.UUID,
    payload: ReviewCreate,
    user_id: str = Depends(require_user),
    db: Session = Depends(get_db),
) -> ReviewOut:
    request = _party_or_404(db, request_id, user_id)
    if request.status != "completed":
        raise ApiError(409, "NOT_COMPLETED", "完了後に評価できます")
    duplicate = db.scalars(
        select(Review).where(
            Review.request_id == request.id, Review.reviewer_id == user_id
        )
    ).first()
    if duplicate is not None:
        raise ApiError(409, "DUPLICATE_REVIEW", "この申込みは評価済みです")
    if request.requester_id == user_id:
        reviewee = request.provider_user_id or request.accepted_by
    else:
        reviewee = request.requester_id
    if reviewee is None:
        raise ApiError(409, "NOT_COMPLETED", "評価先を特定できません")
    review = Review(
        request_id=request.id,
        reviewer_id=user_id,
        reviewee_id=reviewee,
        score=payload.score,
        comment=payload.comment,
    )
    db.add(review)
    db.commit()
    db.refresh(review)
    return ReviewOut.model_validate(review)
