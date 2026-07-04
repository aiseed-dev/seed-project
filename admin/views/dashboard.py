# SPDX-License-Identifier: MIT
"""ダッシュボード: 承認待ち・通報・全体の件数。"""

import flet as ft
from app.models import AppUser, Listing, Report, Request, Revision, Variety
from sqlalchemy import func, select

import boot


def build(page: ft.Page) -> ft.Control:
    with boot.session() as db:
        def count(stmt) -> int:
            return db.scalar(stmt) or 0

        cards = [
            ("承認待ちの品種", count(
                select(func.count()).where(Variety.status == "pending"))),
            ("承認待ちのリビジョン", count(
                select(func.count()).where(Revision.status == "pending"))),
            ("未対応の通報", count(
                select(func.count()).where(Report.status == "open"))),
            ("公開中の出品", count(
                select(func.count()).where(
                    Listing.status == "active",
                    Listing.moderation == "approved"))),
            ("申込み(全体)", count(select(func.count(Request.id)))),
            ("ユーザー", count(select(func.count(AppUser.id)))),
        ]
    return ft.Column(
        [
            ft.Text("ダッシュボード", size=20, weight=ft.FontWeight.BOLD),
            ft.Row(
                [
                    ft.Container(
                        ft.Column(
                            [
                                ft.Text(label, size=12),
                                ft.Text(str(value), size=24,
                                        weight=ft.FontWeight.BOLD),
                            ]
                        ),
                        padding=16,
                        border=ft.Border.all(1, "#E3DDCD"),
                        border_radius=6,
                        width=180,
                    )
                    for label, value in cards
                ],
                wrap=True,
            ),
        ],
        scroll=ft.ScrollMode.AUTO,
    )
