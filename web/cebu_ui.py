"""CoptC /admin/cebu — Test CEBU menü + eşleme + sanal defter."""
from __future__ import annotations

import json
import os
import sys
from typing import Any

_ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
_TEST = os.path.join(_ROOT, "AgustosKripto", "Test")
_AGUSTOS = os.path.join(_ROOT, "AgustosKripto")
if _TEST not in sys.path:
    sys.path.insert(0, _TEST)

_STATE = os.path.join(_TEST, "data", "test_cebu_state.json")
_HIST = os.path.join(_TEST, "data", "test_cebu_history.json")
_CTRL = os.path.join(_AGUSTOS, "crypto_futures_b1_mum_control.json")


def _read_json(path: str, default: Any):
    try:
        with open(path, encoding="utf-8") as f:
            return json.load(f)
    except (OSError, json.JSONDecodeError):
        return default


def _books():
    import catalog  # noqa: WPS433

    return list(catalog.ALL_BOOKS)


def _cebu():
    import cebu  # noqa: WPS433

    return cebu


def _label(uid: str, book_by_uid: dict[str, dict]) -> str:
    row = book_by_uid.get(uid) or {}
    return str(row.get("name") or uid)


def _resolve(base: str, pin: str, cebu) -> str | None:
    if base in cebu.DISABLED_SYMBOLS:
        return None
    if pin == "jarvis_v1":
        try:
            return cebu.resolve_motor_uid(base)
        except Exception:
            return None
    return pin


def _mark(symbol: str) -> float | None:
    if str(_ROOT) not in sys.path:
        sys.path.insert(0, str(_ROOT))
    try:
        from binance_fapi_guard import get_last, get_mark
        px = get_mark(symbol) or get_last(symbol)
        return float(px) if px else None
    except Exception:
        return None


def _upnl(row: dict, mark: float | None) -> float | None:
    if not mark:
        return None
    try:
        entry = float(row.get("entry_price") or 0)
        qty = float(row.get("qty") or 0)
    except (TypeError, ValueError):
        return None
    if entry <= 0 or qty <= 0:
        return None
    side = str(row.get("side") or "LONG").upper()
    signed = (mark - entry) if side == "LONG" else (entry - mark)
    return round(signed * qty, 4)


def _slim_pos(row: dict, *, live: bool = False) -> dict:
    out = {
        "symbol": row.get("symbol"),
        "side": row.get("side"),
        "signal": row.get("signal"),
        "algo": row.get("algo"),
        "interval": row.get("interval"),
        "margin_usd": row.get("margin_usd"),
        "entry_price": row.get("entry_price"),
        "entry_time_tr": row.get("entry_time_tr"),
        "score": row.get("score"),
        "qty": row.get("qty"),
        "pnl": row.get("pnl"),
        "win": row.get("win"),
        "exit_time_tr": row.get("exit_time_tr"),
        "exit_price": row.get("exit_price"),
        "notional": row.get("notional"),
        "leverage": row.get("leverage"),
        "peak_upnl": row.get("peak_upnl"),
        "lock_armed": row.get("lock_armed"),
    }
    if live:
        mark = _mark(str(row.get("symbol") or ""))
        upnl = _upnl(row, mark)
        out["mark"] = mark
        out["upnl"] = upnl
        try:
            margin = float(row.get("margin_usd") or 0)
        except (TypeError, ValueError):
            margin = 0.0
        out["upnl_pct"] = round(upnl / margin * 100.0, 2) if upnl is not None and margin else None
    return out


def snapshot() -> dict:
    cebu = _cebu()
    books = _books()
    book_by_uid = {b["uid"]: b for b in books}
    mapping_rows = []
    for base, pin in cebu.MAPPING.items():
        off = base in cebu.DISABLED_SYMBOLS
        resolved = None if off else _resolve(base, pin, cebu)
        pin_name = "JARVIS_V1" if pin == "jarvis_v1" else _label(pin, book_by_uid)
        mapping_rows.append({
            "symbol": base,
            "pin_uid": pin,
            "pin_name": pin_name,
            "uid": resolved,
            "algo": "PASİF" if off else (_label(resolved, book_by_uid) if resolved else pin_name),
            "disabled": off,
            "jarvis_live": (not off) and pin == "jarvis_v1",
        })

    linked: set[str] = set()
    for row in mapping_rows:
        if row.get("disabled"):
            continue
        if row.get("uid"):
            linked.add(str(row["uid"]))
        pin = str(row.get("pin_uid") or "")
        if pin and pin not in ("jarvis_v1", cebu.CEBU_UID):
            linked.add(pin)

    groups: list[dict] = []
    seen: dict[str, list] = {}
    order: list[str] = []
    for book in books:
        uid = str(book.get("uid") or "")
        if uid not in linked:
            continue
        cat = str(book.get("category") or "Diğer")
        if cat not in seen:
            seen[cat] = []
            order.append(cat)
        seen[cat].append({
            "uid": book.get("uid"),
            "name": book.get("name"),
            "title": book.get("title") or book.get("name"),
            "coins": sum(1 for r in mapping_rows if (not r.get("disabled")) and (r.get("uid") == uid or r.get("pin_uid") == uid)),
        })
    for cat in order:
        groups.append({"category": cat, "books": seen[cat]})

    state = _read_json(_STATE, {})
    hist = _read_json(_HIST, [])
    if not isinstance(hist, list):
        hist = []
    ctrl = _read_json(_CTRL, {})

    opens = [_slim_pos(p, live=True) for p in (state.get("open_positions") or []) if isinstance(p, dict)]
    opens.sort(key=lambda p: (p.get("upnl") is None, -(p.get("upnl") or 0)))
    recent = [_slim_pos(p) for p in hist[-40:] if isinstance(p, dict)]
    recent.reverse()
    wins = sum(1 for p in hist if isinstance(p, dict) and p.get("win") is True)
    losses = sum(1 for p in hist if isinstance(p, dict) and p.get("win") is False)
    closed = wins + losses
    realized = float(state.get("total_pnl") or 0)
    floating = round(sum(p["upnl"] for p in opens if p.get("upnl") is not None), 4)
    deposit = float(state.get("deposit") or 0)
    now_pnl = round(realized + floating, 4)

    return {
        "ok": True,
        "uid": cebu.CEBU_UID,
        "max_opens": cebu.MAX_OPENS,
        "mapped_coins": len(cebu.MAPPING) - len(cebu.DISABLED_SYMBOLS),
        "disabled": sorted(cebu.DISABLED_SYMBOLS),
        "live_paused": bool(ctrl.get("live_paused", True)),
        "live_reason": ctrl.get("reason") or "",
        "updated_at_tr": state.get("updated_at_tr") or ctrl.get("updated_at_tr") or "",
        "balance": state.get("balance"),
        "deposit": deposit,
        "total_pnl": realized,
        "open_upnl": floating,
        "now_pnl": now_pnl,
        "in_profit": now_pnl > 0,
        "wins": wins,
        "losses": losses,
        "closed": closed,
        "win_rate": round(wins / closed * 100.0, 1) if closed else None,
        "opens": opens,
        "history": recent,
        "mapping": mapping_rows,
        "groups": groups,
    }
