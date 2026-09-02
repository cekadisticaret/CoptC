"""BIN Isolated (bin-b103 / D104) → cTrader DEMO ayna.

Kaynak deftere yazmaz. Yalnız okur: aynı yönü $100×100x MARKET açar/kapatır.
Grafik (g1) aynasına dokunmaz.
"""
from __future__ import annotations

import fcntl
import json
from datetime import datetime
from pathlib import Path
from zoneinfo import ZoneInfo

from ctrader_api import close_position, orders_allowed, place_market, quote, snapshot_book

_DIR = Path(__file__).resolve().parent / "data"
_STATE = _DIR / "oapi_bin_state.json"
_LOCK = _DIR / "oapi_bin.lock"
_TZ = ZoneInfo("Europe/Istanbul")
MARGIN = 100.0
LEVERAGE = 100
OZ_PER_LOT = 100.0


def _now() -> str:
    return datetime.now(_TZ).strftime("%Y.%m.%d %H:%M:%S")


def _empty() -> dict:
    return {
        "last_reject": None,
        "last_order": None,
        "seq": 0,
        "mirror_src": "binb103",
        "margin": MARGIN,
        "leverage": LEVERAGE,
    }


def _load() -> dict:
    try:
        st = json.loads(_STATE.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError):
        st = {}
    base = _empty()
    for k, v in base.items():
        st.setdefault(k, v)
    return st


def _save(st: dict) -> None:
    _DIR.mkdir(parents=True, exist_ok=True)
    tmp = _STATE.with_suffix(".tmp")
    tmp.write_text(json.dumps(st, ensure_ascii=False, indent=2), encoding="utf-8")
    tmp.replace(_STATE)


def _side(pos: dict | None) -> str:
    raw = str((pos or {}).get("side") or "").lower()
    if raw in ("buy", "long", "al"):
        return "buy"
    if raw in ("sell", "short", "sat"):
        return "sell"
    return ""


def _bin_book() -> dict:
    from bin_b103_book import snapshot
    from bin_b103_data import live_quote

    q = live_quote()
    return snapshot(q.get("bid"), q.get("ask"))


def _lots(mark: float | None = None) -> float:
    px = mark
    if not px:
        try:
            q = quote()
            px = q.get("ask") or q.get("mid") or q.get("bid")
        except Exception:
            px = None
    if not px:
        return 0.02
    lots = (MARGIN * LEVERAGE) / (float(px) * OZ_PER_LOT)
    lots = max(0.01, min(1.0, round(lots + 1e-9, 2)))
    return lots


def tick() -> dict:
    if not orders_allowed(mirror="bin"):
        return {"ok": False, "trade": False, "reason": "demo_kapali"}

    src = _bin_book()
    want = [_side(p) for p in (src.get("positions") or []) if _side(p) in ("buy", "sell")]
    want_pos = {_side(p): p for p in (src.get("positions") or []) if _side(p) in ("buy", "sell")}

    book = snapshot_book()
    live = list(book.get("positions") or [])
    live_by: dict[str, list] = {}
    for p in live:
        s = _side(p)
        if s:
            live_by.setdefault(s, []).append(p)

    _DIR.mkdir(parents=True, exist_ok=True)
    with open(_LOCK, "a+", encoding="utf-8") as lk:
        fcntl.flock(lk.fileno(), fcntl.LOCK_EX)
        st = _load()
        closed, opened = [], []

        for side, rows in list(live_by.items()):
            if side in want_pos:
                continue
            for pos in rows:
                try:
                    close_position(
                        pos.get("id"),
                        volume_raw=pos.get("volume_raw"),
                        lots=pos.get("volume"),
                        mirror="bin",
                    )
                    closed.append({"id": pos.get("id"), "side": side, "reason": "bin_flat"})
                except Exception as e:
                    st["last_reject"] = {
                        "side": side,
                        "reason": f"close {type(e).__name__}: {str(e)[:120]}",
                        "at": _now(),
                    }
                    _save(st)
                    return {
                        "ok": False,
                        "trade": True,
                        "error": f"close {type(e).__name__}: {e}"[:200],
                        "balance": book.get("balance"),
                    }

        if closed:
            book = snapshot_book()
            live = list(book.get("positions") or [])
            live_by = {}
            for p in live:
                s = _side(p)
                if s:
                    live_by.setdefault(s, []).append(p)

        prev = str((st.get("last_reject") or {}).get("reason") or "")
        if "TRADE permission" in prev and want_pos:
            _save(st)
            return {
                "ok": False,
                "trade": False,
                "error": "TRADE permission required",
                "want": want,
                "balance": book.get("balance"),
                "equity": book.get("equity"),
            }

        lots = None
        src_px = None
        for _src in want_pos.values():
            src_px = _src.get("mark") or _src.get("entry") or src_px
        for side, _src in want_pos.items():
            if live_by.get(side):
                continue
            if lots is None:
                lots = _lots(float(src_px) if src_px else None)
            try:
                out = place_market(
                    side,
                    lots=lots,
                    comment="binb103",
                    mirror="bin",
                    mark=float(src_px) if src_px else None,
                )
                opened.append(out)
                st["seq"] = int(st.get("seq") or 0) + 1
                st["last_order"] = {
                    "side": side,
                    "at": _now(),
                    "lots": lots,
                    "position_id": (out or {}).get("position_id"),
                    "price": (out or {}).get("price"),
                    "src_id": _src.get("id"),
                }
                st["last_reject"] = None
            except Exception as e:
                err = str(e)[:160]
                st["last_reject"] = {
                    "side": side,
                    "reason": f"emir {type(e).__name__}: {err}",
                    "at": _now(),
                }
                if "TRADE permission" in err:
                    from ctrader_api import mark_trade_denied
                    mark_trade_denied()
                _save(st)
                return {
                    "ok": False,
                    "trade": True,
                    "error": str(e)[:200],
                    "balance": book.get("balance"),
                }
        _save(st)

    return {
        "ok": True,
        "trade": True,
        "demo": True,
        "mirror": "binb103",
        "want": want,
        "lots": lots,
        "opened": opened,
        "closed": closed,
        "reject": (st.get("last_reject") or {}).get("reason"),
        "open_count": len(live) + len(opened) - len(closed),
        "balance": book.get("balance"),
        "equity": book.get("equity"),
    }
