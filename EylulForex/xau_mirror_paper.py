"""XAUUSDT_1 / XAUUSDT_2 cron — BIN Isolated ayna, ayrı $500 kasa.

  python3 EylulForex/xau_mirror_paper.py close|open|trail|scan|status

XAUUSDT_1 = a2_12, XAUUSDT_2 = d105. Kaynak runner'lara yazmaz.
"""
from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

from bin_b103_data import live_quote
from xau_mirror import DESKS, apply_liv_signal, snapshot


def _quote() -> dict:
    return live_quote()


def _ba(q: dict | None = None) -> tuple[float, float]:
    q = q or _quote()
    return float(q.get("bid") or 0), float(q.get("ask") or 0)


def _sync(tag: str) -> dict:
    bid, ask = _ba()
    if bid <= 0 or ask <= 0:
        print(f"[xau_mirror {tag}] fiyat yok")
        return {"ok": False, "error": "no_quote"}
    out = {}
    for key, cfg in DESKS.items():
        r = apply_liv_signal(key, bid, ask)
        out[key] = r
        print(
            f"[{cfg['name']} {tag}] mirror action={r.get('action')} "
            f"sig={r.get('signal')} side={r.get('side')} src={r.get('src_id')} "
            f"closed={r.get('closed')} opened={r.get('opened')} held={r.get('held')}"
        )
    return {"ok": True, "desks": out}


def run_close() -> dict:
    return _sync("close")


def run_trail() -> dict:
    return _sync("trail")


def run_open() -> dict:
    return _sync("open")


def run_scan() -> dict:
    return _sync("scan")


def run_status() -> dict:
    bid, ask = _ba()
    return {key: snapshot(key, bid, ask) for key in DESKS}


def main() -> None:
    p = argparse.ArgumentParser()
    p.add_argument("cmd", choices=["close", "open", "trail", "scan", "status"])
    args = p.parse_args()
    fn = {
        "close": run_close,
        "open": run_open,
        "trail": run_trail,
        "scan": run_scan,
        "status": run_status,
    }[args.cmd]
    out = fn()
    print(json.dumps(out, ensure_ascii=False, default=str))


if __name__ == "__main__":
    main()
