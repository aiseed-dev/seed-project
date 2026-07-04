# SPDX-License-Identifier: MIT
"""品種マスタ承認。登録品種チェック(種苗法の法的判断)は運営者のみ。"""

import flet as ft
from app.models import Category, Crop, Variety
from app.services.variety import approve_variety, reject_variety
from sqlalchemy import select

import boot

ADMIN_ID = "admin"  # 運営アカウントの app_users.id(環境に合わせる)


def build(page: ft.Page) -> ft.Control:
    listing = ft.Column(scroll=ft.ScrollMode.AUTO, expand=True)

    def refresh() -> None:
        listing.controls.clear()
        with boot.session() as db:
            pending = db.scalars(
                select(Variety)
                .where(Variety.status == "pending")
                .order_by(Variety.created_at)
            ).all()
            categories = {
                c.id: c.name for c in db.scalars(select(Category)).all()
            }
            if not pending:
                listing.controls.append(ft.Text("承認待ちはありません"))
            for variety in pending:
                listing.controls.append(
                    _row(page, refresh, variety.id, variety.name,
                         categories.get(variety.category_id, ""),
                         variety.proposed_by or "-")
                )
        page.update()

    refresh()
    return ft.Column(
        [ft.Text("品種マスタ承認", size=20, weight=ft.FontWeight.BOLD), listing],
        expand=True,
    )


def _row(
    page: ft.Page, refresh, variety_id, name: str, category: str, proposer: str
) -> ft.Control:
    kana = ft.TextField(label="かな", width=160)
    seed_type = ft.Dropdown(
        label="種別",
        width=140,
        options=[
            ft.dropdown.Option("fixed", "固定種"),
            ft.dropdown.Option("native", "在来種"),
            ft.dropdown.Option("unknown", "不明"),
        ],
        value="unknown",
    )
    crop = ft.TextField(label="品目(例: ダイコン。無ければ新規作成)", width=220)
    note = ft.TextField(label="却下理由 / 登録品種の確認メモ", width=320)
    registered = ft.Checkbox(label="登録品種と確認した(出品をブロック)")

    def approve(_: ft.ControlEvent) -> None:
        with boot.session() as db:
            variety = db.get(Variety, variety_id)
            if variety is None:
                return
            crop_id = None
            crop_name = crop.value.strip() if crop.value else ""
            if crop_name:
                found = db.scalars(
                    select(Crop).where(Crop.name == crop_name)
                ).first()
                if found is None:
                    found = Crop(
                        name=crop_name, category_id=variety.category_id
                    )
                    db.add(found)
                    db.flush()
                crop_id = found.id
            approve_variety(
                db, variety, ADMIN_ID,
                crop_id=crop_id,
                kana=kana.value or None,
                seed_type=seed_type.value or None,
            )
            db.commit()
        refresh()

    def reject(_: ft.ControlEvent) -> None:
        with boot.session() as db:
            variety = db.get(Variety, variety_id)
            if variety is None:
                return
            reject_variety(
                db, variety, ADMIN_ID,
                is_registered=bool(registered.value),
                note=note.value or None,
            )
            db.commit()
        refresh()

    return ft.Container(
        ft.Column(
            [
                ft.Text(f"{name}({category}) 提案: {proposer}",
                        weight=ft.FontWeight.BOLD),
                ft.Row([kana, seed_type, crop], wrap=True),
                ft.Row(
                    [
                        registered,
                        note,
                        ft.FilledButton("承認", on_click=approve),
                        ft.OutlinedButton("却下", on_click=reject),
                    ],
                    wrap=True,
                ),
                ft.Text(
                    "承認前に品種登録データベース(農水省)で登録品種でないことを確認する",
                    size=11,
                ),
            ]
        ),
        padding=12,
        border=ft.Border.all(1, "#E3DDCD"),
        border_radius=6,
        margin=ft.Margin.only(bottom=8),
    )
