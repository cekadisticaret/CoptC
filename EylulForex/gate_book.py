"""Gate XAU_USDT defter — CEM01 aynası, $100×30x, taker %0.05, min kâr $9.

Grafik g1 / OPEN API / GPS / BIN defterlerine yazmaz.
"""
from __future__ import annotations

import fcntl
import json
from datetime import datetime
from pathlib import Path
from zoneinfo import ZoneInfo

from gate_api import CONTRACT, TAKER_RATE, contracts_for_notional, oz_of

_DIR = Path(__file__).resolve().parent / "data"
_STATE = _DIR / "gate_g1_state.json"
_HIST = _DIR / "gate_g1_history.json"
_LOCK = _DIR / "gate_g1.lock"
_TZ = ZoneInfo("Europe/Istanbul")

INIT_BAL = 300.0
MARGIN = 100.0
LEVERAGE = 30
NOTIONAL = MARGIN * LEVERAGE
MIN_REWARD_USD = 9.0
HIST_MAX = 400
SYMBOL = "XAUUSDT"


def _now() -> str:
    return datetime.now(_TZ).strftime("%Y.%m.%d %H:%M:%S")


def _empty() -> dict:
    return {
        "balance": INIT_BAL,
        "init_balance": INIT_BAL,
        "total_pnl": 0.0,
        "positions": [],
        "position": None,
        "seq": 0,
        "last_reject": None,
        "last_order": None,
        "last_src_id": None,
        "started_at": _now(),
        "book": "gate",
        "margin": MARGIN,
        "leverage": LEVERAGE,
        "min_reward_usd": MIN_REWARD_USD,
        "taker_rate": TAKER_RATE,
    }


def _atomic(path: Path, data) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    tmp = path.with_suffix(path.suffix + ".tmp")
    tmp.write_text(json.dumps(data, ensure_ascii=False, indent=2), encoding="utf-8")
    tmp.replace(path)


def _load_state() -> dict:
    try:
        st = json.loads(_STATE.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError):
        st = {}
    base = _empty()
    for k, v in base.items():
        st.setdefault(k, v)
    return st


def _load_hist() -> list:
    try:
        h = json.loads(_HIST.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError):
        h = []
    return h if isinstance(h, list) else []


def _plist(st: dict) -> list:
    rows = st.get("positions")
    if isinstance(rows, list):
        return rows
    pos = st.get("position")
    return [pos] if isinstance(pos, dict) else []


def commission_usd(notional: float | None = None) -> float:
    return round(float(notional if notional is not None else NOTIONAL) * TAKER_RATE, 4)


def expected_gross(src: dict, gate_px: float) -> float | None:
    """g1 giriş→hedef mesafesi × Gate adet. Mutlak fiyat kopyalanmaz."""
    try:
        entry = float(src["entry"])
        tgt = src.get("target")
        if tgt is None:
            return None
        move = abs(float(tgt) - entry)
        qty = NOTIONAL / float(gate_px)
        return round(move * qty, 2)
    except (TypeError, ValueError, KeyError, ZeroDivisionError):
        return None


def sltp_from_src(src: dict, gate_entry: float) -> tuple[float | None, float | None]:
    try:
        src_e = float(src["entry"])
        gate_e = float(gate_entry)
    except (TypeError, ValueError, KeyError):
        return None, None
    stop = src.get("stop")
    tgt = src.get("target")
    sl = round(gate_e + (float(stop) - src_e), 2) if stop is not None else None
    tp = round(gate_e + (float(tgt) - src_e), 2) if tgt is not None else None
    return sl, tp


def _exit_px(side: str, bid: float, ask: float) -> float:
    return float(bid if side == "buy" else ask)


def _float_gross(pos: dict, bid: float, ask: float) -> float:
    mark = _exit_px(pos["side"], bid, ask)
    qty = float(pos.get("qty_oz") or pos.get("volume") or 0)
    entry = float(pos["entry"])
    raw = (mark - entry) if pos["side"] == "buy" else (entry - mark)
    return round(raw * qty, 2)


def _hit(pos: dict, mark: float, key: str, side_ge: bool) -> bool:
    lv = pos.get(key)
    if lv is None:
        return False
    px = float(lv)
    if pos["side"] == "buy":
        return mark <= px if side_ge else mark >= px
    return mark >= px if side_ge else mark <= px


def _close(st: dict, hist: list, pos: dict, bid: float, ask: float, reason: str) -> dict:
    exit_px = _exit_px(pos["side"], bid, ask)
    qty = float(pos.get("qty_oz") or pos.get("volume") or 0)
    notional = qty * exit_px
    comm_open = round(float(pos.get("commission_open") or 0), 4)
    comm_close = commission_usd(notional)
    gross = _float_gross(pos, bid, ask)
    net = round(gross - comm_open - comm_close, 2)
    st["balance"] = round(float(st["balance"]) + gross - comm_close, 2)
    st["total_pnl"] = round(float(st["total_pnl"]) + net, 2)
    row = {
        "id": pos.get("id"),
        "src_id": pos.get("src_id"),
        "symbol": SYMBOL,
        "contract": CONTRACT,
        "side": pos["side"],
        "volume": qty,
        "entry": pos["entry"],
        "exit": round(exit_px, 2),
        "open_time": pos.get("open_time"),
        "close_time": _now(),
        "gross": gross,
        "commission": round(comm_open + comm_close, 4),
        "commission_open": comm_open,
        "commission_close": comm_close,
        "pnl": net,
        "balance_after": st["balance"],
        "reason": reason,
        "target": pos.get("target"),
        "stop": pos.get("stop"),
        "expected_usd": pos.get("expected_usd"),
        "margin": MARGIN,
        "leverage": LEVERAGE,
        "fill_src": pos.get("fill_src") or "paper",
        "venue": "gate",
    }
    hist.append(row)
    del hist[:-HIST_MAX]
    st["positions"] = [p for p in _plist(st) if p.get("id") != pos.get("id")]
    st["position"] = st["positions"][0] if st["positions"] else None
    st["last_src_id"] = pos.get("src_id")
    return row


def _protect(st: dict, hist: list, bid: float, ask: float) -> list:
    closed = []
    for pos in list(_plist(st)):
        mark = _exit_px(pos["side"], bid, ask)
        if _hit(pos, mark, "stop", True):
            closed.append(_close(st, hist, pos, bid, ask, "stop"))
        elif _hit(pos, mark, "target", False):
            closed.append(_close(st, hist, pos, bid, ask, "tp"))
    return closed


def open_paper(st: dict, side: str, bid: float, ask: float, src: dict, expected: float) -> dict:
    entry = float(ask if side == "buy" else bid)
    contracts = contracts_for_notional(NOTIONAL, entry)
    qty = oz_of(contracts)
    sl, tp = sltp_from_src(src, entry)
    comm = commission_usd(qty * entry)
    st["seq"] = int(st.get("seq") or 0) + 1
    st["balance"] = round(float(st["balance"]) - comm, 2)
    pos = {
        "id": f"g{st['seq']}",
        "src_id": src.get("id"),
        "symbol": SYMBOL,
        "contract": CONTRACT,
        "side": side,
        "volume": round(qty, 4),
        "qty_oz": round(qty, 4),
        "contracts": contracts,
        "entry": round(entry, 2),
        "stop": sl,
        "target": tp,
        "expected_usd": expected,
        "commission_open": comm,
        "commission": comm,
        "open_time": _now(),
        "margin": MARGIN,
        "leverage": LEVERAGE,
        "fill_src": "paper",
        "live": False,
    }
    st["positions"] = _plist(st) + [pos]
    st["position"] = pos
    st["last_order"] = {"side": side, "at": _now(), "id": pos["id"], "src_id": src.get("id")}
    st["last_reject"] = None
    return pos


def amend_from_src(pos: dict, src: dict) -> bool:
    sl, tp = sltp_from_src(src, pos.get("entry"))
    changed = False
    if sl is not None and sl != pos.get("stop"):
        pos["stop"] = sl
        changed = True
    if tp is not None and tp != pos.get("target"):
        pos["target"] = tp
        changed = True
    return changed


def snapshot(bid: float | None, ask: float | None) -> dict:
    if bid is None or ask is None:
        st = _load_state()
        return _view(st, None, None, [])
    _DIR.mkdir(parents=True, exist_ok=True)
    with open(_LOCK, "a+", encoding="utf-8") as lk:
        fcntl.flock(lk.fileno(), fcntl.LOCK_EX)
        st = _load_state()
        hist = _load_hist()
        closed = _protect(st, hist, float(bid), float(ask))
        _atomic(_STATE, st)
        _atomic(_HIST, hist)
        return _view(st, float(bid), float(ask), hist, closed)


def with_lock(fn):
    _DIR.mkdir(parents=True, exist_ok=True)
    with open(_LOCK, "a+", encoding="utf-8") as lk:
        fcntl.flock(lk.fileno(), fcntl.LOCK_EX)
        st = _load_state()
        hist = _load_hist()
        out = fn(st, hist)
        _atomic(_STATE, st)
        _atomic(_HIST, hist)
        return out


def _view(st: dict, bid, ask, hist: list, closed: list | None = None) -> dict:
    from gate_api import configured, live_allowed

    rows = []
    equity = float(st.get("balance") or 0)
    for p in _plist(st):
        item = dict(p)
        if bid is not None and ask is not None:
            fg = _float_gross(p, bid, ask)
            item["mark"] = _exit_px(p["side"], bid, ask)
            item["float_pnl"] = round(fg - float(p.get("commission_open") or 0) - commission_usd(), 2)
            item["float_net"] = item["float_pnl"]
            equity += fg
        rows.append(item)
    return {
        "ok": True,
        "book": "gate",
        "venue": "gate",
        "symbol": SYMBOL,
        "contract": CONTRACT,
        "margin": MARGIN,
        "leverage": LEVERAGE,
        "notional": NOTIONAL,
        "min_reward_usd": MIN_REWARD_USD,
        "taker_rate": TAKER_RATE,
        "round_fee": round(commission_usd() * 2, 2),
        "balance": round(float(st.get("balance") or 0), 2),
        "equity": round(equity, 2),
        "init_balance": st.get("init_balance") or INIT_BAL,
        "total_pnl": st.get("total_pnl") or 0,
        "open_count": len(rows),
        "positions": rows,
        "position": rows[0] if rows else None,
        "history": list(reversed(hist[-80:])),
        "trade_count": len(hist) + len(rows),
        "last_reject": st.get("last_reject"),
        "last_order": st.get("last_order"),
        "started_at": st.get("started_at"),
        "closed": closed or [],
        "keys": configured(),
        "live": live_allowed(),
        "paper": not live_allowed(),
        "costs": {
            "commission_open": commission_usd(),
            "commission_close": commission_usd(),
            "taker": TAKER_RATE,
        },
    }
