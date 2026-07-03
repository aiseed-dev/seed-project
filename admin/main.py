# SPDX-License-Identifier: MIT
"""運営管理アプリ(docs/07)。左ナビ+メインペイン。

起動: flet run --web --port 8550(localhost バインド)
手元から: ssh -L 8550:localhost:8550 サーバー → ブラウザで表示。
"""

import flet as ft

from views import dashboard, reports, revisions, shops, users, varieties

VIEWS = [
    ("ダッシュボード", ft.Icons.DASHBOARD_OUTLINED, dashboard.build),
    ("通報", ft.Icons.FLAG_OUTLINED, reports.build),
    ("品種承認", ft.Icons.SPA_OUTLINED, varieties.build),
    ("リビジョン承認", ft.Icons.FACT_CHECK_OUTLINED, revisions.build),
    ("店舗", ft.Icons.STOREFRONT_OUTLINED, shops.build),
    ("ユーザー", ft.Icons.PERSON_OUTLINED, users.build),
]


def main(page: ft.Page) -> None:
    page.title = "種の交換 運営管理"
    body = ft.Container(expand=True, padding=16)

    def switch(index: int) -> None:
        body.content = VIEWS[index][2](page)
        page.update()

    rail = ft.NavigationRail(
        selected_index=0,
        label_type=ft.NavigationRailLabelType.ALL,
        destinations=[
            ft.NavigationRailDestination(icon=icon, label=label)
            for label, icon, _ in VIEWS
        ],
        on_change=lambda e: switch(e.control.selected_index),
    )
    page.add(
        ft.Row(
            [rail, ft.VerticalDivider(width=1), body],
            expand=True,
        )
    )
    switch(0)


if __name__ == "__main__":
    ft.app(main)
