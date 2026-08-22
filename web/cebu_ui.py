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


def _slim_pos(row: dict) -> dict:
    return {
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
    }


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

    groups: list[dict] = []
    seen: dict[str, list] = {}
    order: list[str] = []
    for book in books:
        cat = str(book.get("category") or "Diğer")
        if cat not in seen:
            seen[cat] = []
            order.append(cat)
        seen[cat].append({
            "uid": book.get("uid"),
            "name": book.get("name"),
            "title": book.get("title") or book.get("name"),
        })
    for cat in order:
        groups.append({"category": cat, "books": seen[cat]})

    state = _read_json(_STATE, {})
    hist = _read_json(_HIST, [])
    if not isinstance(hist, list):
        hist = []
    ctrl = _read_json(_CTRL, {})

    opens = [_slim_pos(p) for p in (state.get("open_positions") or []) if isinstance(p, dict)]
    recent = [_slim_pos(p) for p in hist[-24:] if isinstance(p, dict)]
    recent.reverse()

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
        "deposit": state.get("deposit"),
        "total_pnl": state.get("total_pnl"),
        "opens": opens,
        "history": recent,
        "mapping": mapping_rows,
        "groups": groups,
    }
