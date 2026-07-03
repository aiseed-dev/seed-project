# SPDX-License-Identifier: AGPL-3.0-only
"""新規ソースの1行目に SPDX ヘッダがあることを検査する(CLAUDE.md)。

CI やコミット前に `python scripts/spdxcheck.py` で実行する。
"""

import sys
from pathlib import Path

HEADER = "# SPDX-License-Identifier: AGPL-3.0-only"
TARGETS = ["app", "scripts", "tests"]


def offenders(root: Path) -> list[Path]:
    bad: list[Path] = []
    for target in TARGETS:
        for path in sorted((root / target).rglob("*.py")):
            first = path.read_text(encoding="utf-8").split("\n", 1)[0]
            if first.strip() != HEADER:
                bad.append(path)
    return bad


def main() -> int:
    root = Path(__file__).parent.parent
    bad = offenders(root)
    for path in bad:
        print(f"SPDX ヘッダがありません: {path.relative_to(root)}")
    if bad:
        print(f'1行目に "{HEADER}" を追加してください', file=sys.stderr)
        return 1
    print("SPDX ヘッダ: OK")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
