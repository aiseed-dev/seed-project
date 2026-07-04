# SPDX-License-Identifier: MIT
"""辞典リビジョン承認(difflib の差分表示は backend の services を共有)。"""

import flet as ft
from app.models import Article, Revision, Variety
from app.services import dictionary
from sqlalchemy import select

import boot

ADMIN_ID = "admin"

LABELS = {
    "history": "歴史",
    "cultivation": "栽培方法",
    "natural_farming": "自然農法",
    "seed_saving": "採種方法",
    "cooking": "料理",
    "sources": "出典",
}


def build(page: ft.Page) -> ft.Control:
    listing = ft.Column(scroll=ft.ScrollMode.AUTO, expand=True)

    def refresh() -> None:
        listing.controls.clear()
        with boot.session() as db:
            pending = db.scalars(
                select(Revision)
                .where(Revision.status == "pending")
                .order_by(Revision.created_at)
            ).all()
            if not pending:
                listing.controls.append(ft.Text("承認待ちはありません"))
            for revision in pending:
                article = db.get(Article, revision.article_id)
                variety = (
                    db.get(Variety, article.variety_id) if article else None
                )
                old = (
                    dictionary.current_content(db, article) if article else {}
                )
                diff = dictionary.section_diff(old, dict(revision.content))
                listing.controls.append(
                    _row(page, refresh, revision.id,
                         variety.name if variety else "?",
                         revision.edit_summary or "(概要なし)", diff)
                )
        page.update()

    refresh()
    return ft.Column(
        [ft.Text("リビジョン承認", size=20, weight=ft.FontWeight.BOLD), listing],
        expand=True,
    )


def _diff_text(diff: dict) -> list[ft.Control]:
    controls: list[ft.Control] = []
    for section, lines in diff.items():
        controls.append(
            ft.Text(LABELS.get(section, section), weight=ft.FontWeight.BOLD)
        )
        for line in lines:
            color = {"add": "#E3F0D8", "del": "#F6DEDA"}.get(line["op"])
            controls.append(
                ft.Container(ft.Text(line["text"], size=12), bgcolor=color)
            )
    return controls


def _row(
    page: ft.Page, refresh, revision_id, variety_name: str, summary: str, diff
) -> ft.Control:
    note = ft.TextField(label="却下理由(必須)", width=320)

    def review(approve: bool):
        def handler(_: ft.ControlEvent) -> None:
            with boot.session() as db:
                revision = db.get(Revision, revision_id)
                if revision is None or revision.status != "pending":
                    return
                if approve:
                    dictionary.approve_revision(db, revision, ADMIN_ID)
                else:
                    if not (note.value and note.value.strip()):
                        return
                    dictionary.reject_revision(
                        db, revision, ADMIN_ID, note.value.strip()
                    )
                db.commit()
            refresh()

        return handler

    return ft.Container(
        ft.Column(
            [
                ft.Text(f"{variety_name} — {summary}",
                        weight=ft.FontWeight.BOLD),
                ft.ExpansionTile(
                    title=ft.Text("差分を表示", size=12),
                    controls=_diff_text(diff),
                ),
                ft.Row(
                    [
                        ft.FilledButton("承認", on_click=review(True)),
                        ft.OutlinedButton("却下", on_click=review(False)),
                        note,
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
