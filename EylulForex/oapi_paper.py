"""OPEN API cron — cTrader DEMO emir + oturum. CAPITAL / CEM01'e dokunmaz."""
from __future__ import annotations

import fcntl
import json
import sys
import time
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

from ctrader_api import configured, orders_allowed, ping, status
from oapi_book import snapshot
from oapi_data import forex_spot

_LOCK = Path(__file__).resolve().parent / "data" / "oapi_cron.lock"
_TICK_SEC = 4
_LOOP_SEC = 56


def _log_tick(out: dict) -> None:
    print(
        f"ctrader g1-mirror ok={out.get('ok')} want={out.get('want')} "
        f"opened={bool(out.get('opened'))} "
        f"closed={len(out.get('closed') or [])} "
        f"skip={len(out.get('skipped') or [])} "
        f"sltp={len(out.get('amended') or [])} "
        f"reject={out.get('reject')} "
        f"bal={out.get('balance')} err={out.get('error')}"
    )


def run() -> dict:
    print("ctrader g1-mirror durduruldu — emir yok")
    return {"ok": True, "paused": True}


def _run_live() -> dict:
    if configured() and orders_allowed():
        from oapi_trader import tick
        _LOCK.parent.mkdir(parents=True, exist_ok=True)
        with open(_LOCK, "a+", encoding="utf-8") as lk:
            try:
                fcntl.flock(lk.fileno(), fcntl.LOCK_EX | fcntl.LOCK_NB)
            except BlockingIOError:
                print("ctrader g1-mirror — önceki tur bitmedi, atlandı")
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
                    _log_tick(out)
                if time.time() + _TICK_SEC >= deadline:
                    break
                time.sleep(_TICK_SEC)
            if last:
                if acts:
                    print(
                        f"ctrader g1-mirror loop ticks={n} acts={acts} "
                        f"want={last.get('want')} bal={last.get('balance')}"
                    )
                else:
                    _log_tick(last)
            return last or {"ok": True}
    if configured():
        st = status()
        print(
            f"ctrader ok={st.get('ok')} demo={st.get('demo')} "
            f"trade=0 need_grant={st.get('need_trade_grant')} "
            f"bal={st.get('balance')} eq={st.get('equity')} "
            f"open={st.get('open_count')} epic={st.get('epic')} "
            f"err={st.get('error')}"
        )
        ping()
        return st
    q = forex_spot("1m")
    book = q.get("book") or snapshot(q.get("bid"), q.get("ask"))
    sig = q.get("signal") or {}
    print(
        f"oapi dir={sig.get('direction')} bal={book.get('balance')} "
        f"eq={book.get('equity')} open={book.get('open_count')} "
        f"pos={[p.get('side') for p in (book.get('positions') or [])]}"
    )
    return book


if __name__ == "__main__":
    out = run()
    if "--json" in sys.argv:
        print(json.dumps(out, ensure_ascii=False))
