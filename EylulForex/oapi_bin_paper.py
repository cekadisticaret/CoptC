"""BIN Isolated açık/kapalıyı cTrader DEMO'ya kopyala. Diğer defterlere yazmaz.

Tek tur veya --loop (10 sn). Cron dakikalık değil; systemd coptc-oapi-bin.
"""
from __future__ import annotations

import fcntl
import json
import sys
import time
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

from ctrader_api import configured, orders_allowed

_LOCK = Path(__file__).resolve().parent / "data" / "oapi_bin_cron.lock"
INTERVAL = 10.0


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
            f"ctrader bin-mirror check/10s src={out.get('want') or 'flat'} "
            f"ok={out.get('ok')} lots={out.get('lots')} "
            f"opened={len(out.get('opened') or [])} "
            f"closed={len(out.get('closed') or [])} "
            f"reject={out.get('reject')} bal={out.get('balance')} "
            f"err={out.get('error')}",
            flush=True,
        )
        return out


def loop() -> None:
    while True:
        t0 = time.monotonic()
        try:
            run()
        except Exception as e:
            print(f"ctrader bin-mirror loop {type(e).__name__}: {e}"[:240], flush=True)
        wait = INTERVAL - (time.monotonic() - t0)
        if wait > 0:
            time.sleep(wait)


if __name__ == "__main__":
    if "--loop" in sys.argv:
        loop()
    else:
        out = run()
        if "--json" in sys.argv:
            print(json.dumps(out, ensure_ascii=False))
