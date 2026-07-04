# SPDX-License-Identifier: AGPL-3.0-only
"""通報 API(docs/03)。事後審査方式の入口。対応は admin(DB直結)が行う。"""

from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session

from app.core.auth import require_user
from app.core.db import get_db
from app.models import Report
from app.schemas.requests import ReportCreate

router = APIRouter(tags=["reports"])


@router.post("/reports", status_code=201)
def create_report(
    payload: ReportCreate,
    user_id: str = Depends(require_user),
    db: Session = Depends(get_db),
) -> dict[str, str]:
    report = Report(
        reporter_id=user_id,
        target_type=payload.target_type,
        target_id=payload.target_id,
        reason=payload.reason,
        detail=payload.detail,
    )
    db.add(report)
    db.commit()
    return {"id": str(report.id), "status": report.status}
