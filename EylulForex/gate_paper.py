"""GATE cron — CEM01 g1 → Gate XAU_USDT. CEM01 / OPEN / GPS / BIN'e dokunmaz."""
from __future__ import annotations

import fcntl
import json
import sys
import time
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

from gate_book import snapshot
from gate_data import forex_quote
from gate_g1 import tick

_LOCK = Path(__file__).resolve().parent / "data" / "gate_cron.lock"
_TICK_SEC = 4
_LOOP_SEC = 56


def _log(out: dict) -> None:
    print(
        f"gate g1-mirror ok={out.get('ok')} want={out.get('want')} "
        f"opened={bool(out.get('opened'))} "
        f"closed={len(out.get('closed') or [])} "
        f"skip={len(out.get('skipped') or [])} "
        f"sltp={len(out.get('amended') or [])} "
        f"reject={out.get('reject')} "
        f"live={out.get('live')} "
        f"bal={out.get('balance')} err={out.get('error')}"
    )


def run() -> dict:
    _LOCK.parent.mkdir(parents=True, exist_ok=True)
    with open(_LOCK, "a+", encoding="utf-8") as lk:
        try:
            fcntl.flock(lk.fileno(), fcntl.LOCK_EX | fcntl.LOCK_NB)
        except BlockingIOError:
            print("gate g1-mirror — önceki tur bitmedi, atlandı")
            return {"ok": True, "skipped": True, "reason": "busy"}
        last = None
        n = acts = 0
        deadline = time.time() + _LOOP_SEC
        while True:
            n += 1
            out = tick()
            last = out
            if (
                out.get("opened") or out.get("closed")
                or out.get("skipped") or out.get("amended")
                or out.get("error")
            ):
                acts += 1
                _log(out)
            if time.time() + _TICK_SEC >= deadline:
                break
            time.sleep(_TICK_SEC)
        if last:
            if acts:
                print(
                    f"gate g1-mirror loop ticks={n} acts={acts} "
                    f"want={last.get('want')} bal={last.get('balance')}"
                )
            else:
                _log(last)
            return last
        q = forex_quote()
        return snapshot(q.get("bid"), q.get("ask"))


if __name__ == "__main__":
    out = run()
    if "--json" in sys.argv:
        print(json.dumps(out, ensure_ascii=False))
