"""CoptC /admin/cebu — Test CEBU menü + eşleme + sanal defter."""
from __future__ import annotations

import datetime
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
_LIVE_STATE = os.path.join(_AGUSTOS, "crypto_futures_b1_mum_state.json")
_LIVE_HIST = os.path.join(_AGUSTOS, "crypto_futures_b1_mum_history.json")
_CTRL = os.path.join(_AGUSTOS, "crypto_futures_b1_mum_control.json")

_TR = datetime.timezone(datetime.timedelta(hours=3))
# runner girişte notional×0.0005 yazıyor; çıkış da taker sayılır.
_FEE_RATE = 0.0005


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
    try:
        return cebu.resolve_motor_uid(base)
    except Exception:
        return pin if pin not in ("jarvis_v1", "cebu") else None


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


def _parse_tr(stamp: Any):
    if not stamp:
        return None
    try:
        dt = datetime.datetime.fromisoformat(str(stamp))
    except (TypeError, ValueError):
        return None
    if dt.tzinfo is None:
        dt = dt.replace(tzinfo=_TR)
    return dt


def _age_h(stamp: Any) -> float | None:
    started = _parse_tr(stamp)
    if started is None:
        return None
    return round((datetime.datetime.now(_TR) - started).total_seconds() / 3600.0, 2)


def _started_at(state: dict, hist: list) -> str:
    stamps = []
    for p in hist:
        if isinstance(p, dict) and p.get("entry_time_tr"):
            stamps.append(str(p["entry_time_tr"]))
    for p in state.get("open_positions") or []:
        if isinstance(p, dict) and p.get("entry_time_tr"):
            stamps.append(str(p["entry_time_tr"]))
    return min(stamps) if stamps else ""


def _policy() -> dict:
    """Çıkış rejimi — snapshot başına bir kez okunur."""
    if _AGUSTOS not in sys.path:
        sys.path.insert(0, _AGUSTOS)
    try:
        import exit_policy  # noqa: WPS433

        return exit_policy.policy_for("Test")
    except Exception:
        return {"max_hold_h": 24.0, "loss_stop_atr": 3.0}


def _slim_pos(row: dict, *, live: bool = False, policy: dict | None = None) -> dict:
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
        "slot": row.get("slot"),
        "atr_usd": row.get("atr_usd"),
        "virtual": row.get("virtual"),
        "commission": row.get("commission"),
        "close_reason": row.get("close_reason") or row.get("reason"),
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
        out.update(_live_extras(row, mark, upnl, margin, policy or _policy()))
    return out


def _live_extras(
    row: dict, mark: float | None, gross: float | None, margin: float, pol: dict,
) -> dict:
    """Kartın alt satırları — komisyon, net kapatma, ATR zarar stopu."""
    try:
        qty = float(row.get("qty") or 0)
        entry_fee = float(row.get("entry_fee") or 0)
        atr_usd = float(row.get("atr_usd") or 0)
    except (TypeError, ValueError):
        return {}
    exit_fee = round(abs(qty * float(mark or 0)) * _FEE_RATE, 6) if mark else None
    commission = round(entry_fee + exit_fee, 4) if exit_fee is not None else None
    net = round(gross - commission, 4) if (gross is not None and commission is not None) else None
    stop_atr = pol.get("loss_stop_atr")
    max_hold = pol.get("max_hold_h")
    age = _age_h(row.get("entry_time_tr"))
    return {
        "spot_diff": round(float(mark) - float(row.get("entry_price") or 0), 8) if mark else None,
        "exit_fee": exit_fee,
        "commission": commission,
        "net_pnl": net,
        "net_pct": round(net / margin * 100.0, 2) if (net is not None and margin) else None,
        "close_value": round(margin + net, 4) if net is not None else None,
        "loss_stop": round(-float(stop_atr) * atr_usd, 4) if (stop_atr and atr_usd) else None,
        "loss_stop_atr": stop_atr,
        "age_h": age,
        "max_hold_h": max_hold,
        "over_cap": bool(age is not None and max_hold and age > float(max_hold)),
    }


def snapshot() -> dict:
    cebu = _cebu()
    books = _books()
    book_by_uid = {b["uid"]: b for b in books}
    mapping_rows = []
    for base, pin in cebu.MAPPING.items():
        off = base in cebu.DISABLED_SYMBOLS
        resolved = None if off else _resolve(base, pin, cebu)
        pin_name = "LİDER" if not off else "PASİF"
        mapping_rows.append({
            "symbol": base,
            "pin_uid": resolved or pin,
            "pin_name": pin_name,
            "uid": resolved,
            "algo": "PASİF" if off else (_label(resolved, book_by_uid) if resolved else pin_name),
            "disabled": off,
            "jarvis_live": False,
            "lider": not off,
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
    live_state = _read_json(_LIVE_STATE, {})
    live_hist = _read_json(_LIVE_HIST, [])
    if not isinstance(live_hist, list):
        live_hist = []

    pol = _policy()
    opens = [_slim_pos(p, live=True, policy=pol) for p in (state.get("open_positions") or []) if isinstance(p, dict)]
    opens.sort(key=lambda p: (p.get("upnl") is None, -(p.get("upnl") or 0)))
    live_opens = [_slim_pos(p, live=True, policy=pol) for p in (live_state.get("open_positions") or []) if isinstance(p, dict)]
    for p in live_opens:
        p["virtual"] = False
        p["live"] = True
        p["algo"] = p.get("algo") or "CEBU"
    live_opens.sort(key=lambda p: (p.get("upnl") is None, -(p.get("upnl") or 0)))
    closed_hist = [p for p in hist if isinstance(p, dict)]
    recent = [_slim_pos(p) for p in closed_hist[-80:]]
    recent.reverse()
    live_recent = [_slim_pos(p) for p in live_hist[-20:] if isinstance(p, dict)]
    live_recent.reverse()
    wins = sum(1 for p in hist if isinstance(p, dict) and p.get("win") is True)
    losses = sum(1 for p in hist if isinstance(p, dict) and p.get("win") is False)
    closed = wins + losses
    realized = float(state.get("total_pnl") or 0)
    floating = round(sum(p["upnl"] for p in opens if p.get("upnl") is not None), 4)
    deposit = float(state.get("deposit") or 0)
    now_pnl = round(realized + floating, 4)
    live_realized = float(live_state.get("total_pnl") or 0)
    live_floating = round(sum(p["upnl"] for p in live_opens if p.get("upnl") is not None), 4)

    started = _started_at(state, hist)
    engine_age = _age_h(state.get("updated_at_tr"))
    run_age = _age_h(started)
    # Motor her dakika trail atar; 15 dk'yı geçen sessizlik cron'un durduğunu gösterir.
    engine_stale = bool(engine_age is not None and engine_age > 0.25)

    return {
        "ok": True,
        "uid": cebu.CEBU_UID,
        "max_opens": cebu.MAX_OPENS,
        "started_at_tr": started,
        "run_age_h": run_age,
        "engine_age_h": engine_age,
        "engine_stale": engine_stale,
        "over_cap": sum(1 for p in opens if p.get("over_cap")),
        "max_hold_h": pol.get("max_hold_h"),
        "loss_stop_atr": pol.get("loss_stop_atr"),
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
        "live_opens": live_opens,
        "live_pnl": live_realized,
        "live_upnl": live_floating,
        "live_closed": len(live_hist),
        "history": recent,
        "history_total": len(closed_hist),
        "history_shown": len(recent),
        "live_history": live_recent,
        "mapping": mapping_rows,
        "groups": groups,
    }
