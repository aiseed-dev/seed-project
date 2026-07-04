# SPDX-License-Identifier: AGPL-3.0-only
"""自分のプロフィール API(docs/03)。"""

from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session

from app.core.auth import require_user
from app.core.db import get_db
from app.models import AppUser
from app.schemas.articles import MeOut, MePatch

router = APIRouter(tags=["me"])


@router.get("/me")
def get_me(
    user_id: str = Depends(require_user), db: Session = Depends(get_db)
) -> MeOut:
    user = db.get(AppUser, user_id)
    assert user is not None  # require_user が自動作成する
    return MeOut.model_validate(user)


@router.patch("/me")
def patch_me(
    payload: MePatch,
    user_id: str = Depends(require_user),
    db: Session = Depends(get_db),
) -> MeOut:
    user = db.get(AppUser, user_id)
    assert user is not None
    if payload.display_name is not None:
        user.display_name = payload.display_name
    if payload.region is not None:
        user.region = payload.region
    if payload.bio is not None:
        user.bio = payload.bio
    db.commit()
    db.refresh(user)
    return MeOut.model_validate(user)
