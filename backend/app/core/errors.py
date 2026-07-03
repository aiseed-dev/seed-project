# SPDX-License-Identifier: AGPL-3.0-only
"""エラー形式(docs/03): {"detail": "...", "code": "..."}"""

from fastapi import FastAPI, Request
from fastapi.responses import JSONResponse


class ApiError(Exception):
    """コード付きの業務エラー。"""

    def __init__(self, status: int, code: str, detail: str) -> None:
        self.status = status
        self.code = code
        self.detail = detail


def install_handlers(app: FastAPI) -> None:
    @app.exception_handler(ApiError)
    def _api_error(request: Request, exc: ApiError) -> JSONResponse:
        return JSONResponse(
            status_code=exc.status,
            content={"detail": exc.detail, "code": exc.code},
        )
