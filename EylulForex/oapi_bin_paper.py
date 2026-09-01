"""Cron — BIN Isolated açık/kapalıyı cTrader DEMO'ya kopyala. Diğer defterlere yazmaz."""
from __future__ import annotations

import fcntl
import json
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

from ctrader_api import configured, orders_allowed

_LOCK = Path(__file__).resolve().parent / "data" / "oapi_bin_cron.lock"


def run() -> dict:
    if not configured() or not orders_allowed(mirror="bin"):
        print("ctrader bin-mirror atlandı — demo bağlı değil veya emir kapalı")
        return {"ok": False, "skipped": True}
    _LOCK.parent.mkdir(parents=True, exist_ok=True)
    with open(_LOCK, "a+", encoding="utf-8") as lk:
        try:
            fcntl.flock(lk.fileno(), fcntl.LOCK_EX | fcntl.LOCK_NB)
        except BlockingIOError:
            print("ctrader bin-mirror — önceki tur bitmedi")
            return {"ok": True, "skipped": True, "reason": "busy"}
        from oapi_bin_mirror import tick

        out = tick()
        print(
            f"ctrader bin-mirror ok={out.get('ok')} want={out.get('want')} "
            f"lots={out.get('lots')} opened={bool(out.get('opened'))} "
            f"closed={len(out.get('closed') or [])} "
            f"reject={out.get('reject')} bal={out.get('balance')} "
            f"err={out.get('error')}"
        )
        return out


if __name__ == "__main__":
    out = run()
    if "--json" in sys.argv:
        print(json.dumps(out, ensure_ascii=False))
