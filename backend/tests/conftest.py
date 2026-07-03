# SPDX-License-Identifier: AGPL-3.0-only
import sys
from pathlib import Path

import pytest

sys.path.insert(0, str(Path(__file__).parent.parent))


@pytest.fixture
def anyio_backend() -> str:
    return "asyncio"
