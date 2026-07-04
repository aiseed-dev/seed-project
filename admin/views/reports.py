# SPDX-License-Identifier: MIT
"""通報キュー。registered_variety は最上部固定+赤ラベル。"""

import uuid

import flet as ft
from app.models import AppUser, Listing, Report
from app.services import moderation
from sqlalchemy import select

import boot

ADMIN_ID = "admin"


def build(page: ft.Page) -> ft.Control:
    listing = ft.Column(scroll=ft.ScrollMode.AUTO, expand=True)

    def refresh() -> None:
        listing.controls.clear()
        with boot.session() as db:
            reports = db.scalars(
                select(Report)
                .where(Report.status == "open")
                .order_by(
                    Report.reason != "registered_variety", Report.created_at
                )
            ).all()
            if not reports:
                listing.controls.append(ft.Text("未対応の通報はありません"))
            for report in reports:
                preview = _preview(db, report)
                listing.controls.append(
                    _row(page, refresh, report.id, report.reason,
                         report.target_type, preview, report.detail or "")
                )
        page.update()

    refresh()
    return ft.Column(
        [ft.Text("通報キュー", size=20, weight=ft.FontWeight.BOLD), listing],
        expand=True,
    )


def _preview(db, report: Report) -> str:
    if report.target_type == "listing":
        try:
            target = db.get(Listing, uuid.UUID(report.target_id))
        except ValueError:
            return report.target_id
        return target.title if target else "(削除済み)"
    if report.target_type == "user":
        target = db.get(AppUser, report.target_id)
        return target.display_name if target else "(不明)"
    return report.target_id


def _row(
    page: ft.Page, refresh, report_id, reason: str, target_type: str,
    preview: str, detail: str,
) -> ft.Control:
    note = ft.TextField(label="対応メモ(必須)", width=320)
    is_registered = reason == "registered_variety"

    def act(action: str):
        def handler(_: ft.ControlEvent) -> None:
            if action != "dismiss" and not (note.value and note.value.strip()):
                return
            with boot.session() as db:
                report = db.get(Report, report_id)
                if report is None or report.status != "open":
                    return
                memo = (note.value or "").strip()
                if action in ("flag", "remove") and (
                    report.target_type == "listing"
                ):
                    target = db.get(Listing, uuid.UUID(report.target_id))
                    if target is not None:
                        moderation.flag_listing(
                            db, target, removed=action == "remove", note=memo
                        )
                if action == "suspend" and report.target_type == "user":
                    user = db.get(AppUser, report.target_id)
                    if user is not None:
                        moderation.suspend_user(db, user, note=memo)
                moderation.close_report(
                    db, report, ADMIN_ID, dismissed=action == "dismiss"
                )
                db.commit()
            refresh()

        return handler

    return ft.Container(
        ft.Column(
            [
                ft.Row(
                    [
                        ft.Container(
                            ft.Text(reason,
                                    color="#FFFFFF", size=11),
                            bgcolor="#C62828" if is_registered else "#A9A297",
                            padding=4,
                            border_radius=4,
                        ),
                        ft.Text(f"[{target_type}] {preview}",
                                weight=ft.FontWeight.BOLD),
                    ]
                ),
                if_detail(detail),
                ft.Row(
                    [
                        note,
                        ft.OutlinedButton("出品を停止", on_click=act("flag")),
                        ft.OutlinedButton("削除", on_click=act("remove")),
                        ft.OutlinedButton("ユーザー凍結", on_click=act("suspend")),
                        ft.TextButton("却下", on_click=act("dismiss")),
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


def if_detail(detail: str) -> ft.Control:
    return ft.Text(detail, size=12) if detail else ft.Container()
