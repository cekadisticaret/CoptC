#!/usr/bin/env python3
"""BIN_XAUUSDT canlıyı tekrar aç — emir basmaz, sonraki cron D104'ü aynalar."""
from __future__ import annotations

import sys
from pathlib import Path

_DIR = Path(__file__).resolve().parent
if str(_DIR) not in sys.path:
    sys.path.insert(0, str(_DIR))

from bin_b103_binance import set_live_mode  # noqa: E402


def main() -> None:
    ctrl = set_live_mode(True, source="at:08:00")
    print(ctrl, flush=True)


if __name__ == "__main__":
    main()
