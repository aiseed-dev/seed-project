# SPDX-License-Identifier: AGPL-3.0-only
"""定期ジョブの実行入口。cron で毎分: python scripts/jobs.py"""

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent.parent))

from sqlalchemy.orm import sessionmaker  # noqa: E402

from app.core.db import engine  # noqa: E402
from app.services import jobs  # noqa: E402


def main() -> int:
    maker = sessionmaker(bind=engine())
    with maker() as db:
        expired = jobs.expire_requests(db)
        notified = jobs.notify_unread(db)
    print(f"expired={expired} notified={notified}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
