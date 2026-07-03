# SPDX-License-Identifier: MIT
"""店舗管理: 店舗の作成・スタッフ追加・有効/無効。契約と請求はアプリ外。"""

import flet as ft
from app.models import AppUser, Shop, ShopMember
from sqlalchemy import select

import boot


def build(page: ft.Page) -> ft.Control:
    listing = ft.Column(scroll=ft.ScrollMode.AUTO, expand=True)
    slug = ft.TextField(label="slug", width=140)
    code = ft.TextField(label="店舗コード", width=120)
    name = ft.TextField(label="店名", width=200)

    def refresh(_: ft.ControlEvent | None = None) -> None:
        listing.controls.clear()
        with boot.session() as db:
            for shop in db.scalars(select(Shop).order_by(Shop.created_at)).all():
                members = db.execute(
                    select(ShopMember, AppUser)
                    .join(AppUser, ShopMember.user_id == AppUser.id)
                    .where(ShopMember.shop_id == shop.id)
                ).all()
                listing.controls.append(
                    _row(page, refresh, shop.id, shop.name, shop.code,
                         shop.is_active, shop.is_verified,
                         [f"{u.display_name}({m.role})" for m, u in members])
                )
        page.update()

    def create(_: ft.ControlEvent) -> None:
        if not (slug.value and code.value and name.value):
            return
        with boot.session() as db:
            db.add(Shop(slug=slug.value.strip(), code=code.value.strip(),
                        name=name.value.strip()))
            db.commit()
        slug.value = code.value = name.value = ""
        refresh(None)

    refresh()
    return ft.Column(
        [
            ft.Text("店舗管理", size=20, weight=ft.FontWeight.BOLD),
            ft.Row([slug, code, name,
                    ft.FilledButton("店舗を作成", on_click=create)], wrap=True),
            listing,
        ],
        expand=True,
    )


def _row(
    page: ft.Page, refresh, shop_id, name: str, code: str,
    active: bool, verified: bool, members: list[str],
) -> ft.Control:
    member_id = ft.TextField(label="ユーザーID(PocketBase)", width=220)
    role = ft.Dropdown(
        width=110,
        options=[ft.dropdown.Option("owner"), ft.dropdown.Option("staff")],
        value="staff",
    )

    def add_member(_: ft.ControlEvent) -> None:
        if not member_id.value:
            return
        with boot.session() as db:
            user = db.get(AppUser, member_id.value.strip())
            if user is None:
                return  # 先にアプリへ一度ログインしてもらう(自動作成)
            db.add(ShopMember(shop_id=shop_id, user_id=user.id,
                              role=role.value or "staff"))
            db.commit()
        refresh(None)

    def toggle(field: str):
        def handler(_: ft.ControlEvent) -> None:
            with boot.session() as db:
                shop = db.get(Shop, shop_id)
                if shop is None:
                    return
                setattr(shop, field, not getattr(shop, field))
                db.commit()
            refresh(None)

        return handler

    return ft.Container(
        ft.Column(
            [
                ft.Text(
                    f"{name}(コード: {code})"
                    f"{' ✓認証店' if verified else ''}"
                    f"{'' if active else ' [無効]'}",
                    weight=ft.FontWeight.BOLD,
                ),
                ft.Text("スタッフ: " + ("、".join(members) or "なし"), size=12),
                ft.Row(
                    [
                        member_id,
                        role,
                        ft.TextButton("スタッフ追加", on_click=add_member),
                        ft.OutlinedButton("認証切替",
                                          on_click=toggle("is_verified")),
                        ft.OutlinedButton("有効/無効",
                                          on_click=toggle("is_active")),
                    ],
                    wrap=True,
                ),
            ]
        ),
        padding=12,
        border=ft.Border.all(1, "#E3DDCD"),
        border_radius=6,
        margin=ft.Margin.only(bottom=8),
    )
