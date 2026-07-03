# SPDX-License-Identifier: MIT
"""ユーザー管理: role 変更(editor 付与)・凍結/解除。"""

import flet as ft
from app.models import AppUser
from sqlalchemy import select

import boot

ROLES = ["user", "editor", "moderator", "admin"]


def build(page: ft.Page) -> ft.Control:
    listing = ft.Column(scroll=ft.ScrollMode.AUTO, expand=True)
    query = ft.TextField(label="表示名で検索", width=240)

    def refresh(_: ft.ControlEvent | None = None) -> None:
        listing.controls.clear()
        with boot.session() as db:
            stmt = select(AppUser).order_by(AppUser.created_at.desc()).limit(100)
            if query.value:
                stmt = stmt.where(AppUser.display_name.ilike(f"%{query.value}%"))
            for user in db.scalars(stmt).all():
                listing.controls.append(_row(page, refresh, user.id,
                                             user.display_name, user.role,
                                             user.is_suspended))
        page.update()

    refresh()
    return ft.Column(
        [
            ft.Text("ユーザー管理", size=20, weight=ft.FontWeight.BOLD),
            ft.Row([query, ft.FilledButton("検索", on_click=refresh)]),
            listing,
        ],
        expand=True,
    )


def _row(
    page: ft.Page, refresh, user_id: str, name: str, role: str, suspended: bool
) -> ft.Control:
    role_dd = ft.Dropdown(
        width=140,
        options=[ft.dropdown.Option(r) for r in ROLES],
        value=role,
    )

    def save(_: ft.ControlEvent) -> None:
        with boot.session() as db:
            user = db.get(AppUser, user_id)
            if user is None:
                return
            user.role = role_dd.value or "user"
            db.commit()
        refresh(None)

    def toggle(_: ft.ControlEvent) -> None:
        with boot.session() as db:
            user = db.get(AppUser, user_id)
            if user is None:
                return
            user.is_suspended = not user.is_suspended
            db.commit()
        refresh(None)

    return ft.Row(
        [
            ft.Text(f"{name}({user_id})", width=280),
            role_dd,
            ft.TextButton("役割を保存", on_click=save),
            ft.OutlinedButton("凍結解除" if suspended else "凍結",
                              on_click=toggle),
            ft.Text("停止中", color="#C62828") if suspended else ft.Container(),
        ],
        wrap=True,
    )
