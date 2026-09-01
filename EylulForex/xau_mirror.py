"""XAUUSDT_1 / XAUUSDT_2 — BIN Isolated ayna, ayrı $500 kasa.

XAUUSDT_1 = a2_12 (A2#12), XAUUSDT_2 = d105 (D105).
Aç/kapa kaynak fx_algo defterinden; dolum BIN gibi sanal Isolated $100×30x
(taker %0.05, merdiven VWAP). a2_12 / d105 / d104 runner'ına yazmaz.
"""
from __future__ import annotations

import fcntl
import json
import sys
import time
from datetime import datetime
from functools import wraps
from pathlib import Path
from zoneinfo import ZoneInfo

_DIR = Path(__file__).resolve().parent
_ROOT = _DIR.parent
_AGUSTOS = str(_ROOT / "AgustosKripto")
for p in (_AGUSTOS, str(_DIR)):
    if p not in sys.path:
        sys.path.insert(0, p)

from atr_profit_lock import atr_from_klines, init_lock_fields  # noqa: E402
from bin_b103_book import (  # noqa: E402
    HIST_MAX,
    INIT_BAL,
    LEVERAGE,
    MARGIN,
    MARGIN_TYPE,
    SYMBOL,
    _apply_live_mark,
    _engine_side,
    _exit_px,
    _net_float,
    _open_px,
    _pnl,
    _qty,
    _qty_for,
    _r,
    _taker,
)
from bin_b103_signal import engine_info_for, engine_paper_pos_for  # noqa: E402
from exit_policy import policy_for  # noqa: E402

DATA = _DIR / "data"
_TZ = ZoneInfo("Europe/Istanbul")
POLICY = policy_for("Test")
_PX = 2

DESKS = {
    "xau1": {
        "id": "xau1",
        "virt": "xau1",
        "uid": "a2_12",
        "name": "XAUUSDT_1",
        "short": "A2#12",
        "title": "XAUUSDT_1 · Isolated $100×30x · A2#12 ayna",
        "state": DATA / "forex_xauusdt_1_state.json",
        "hist": DATA / "forex_xauusdt_1_history.json",
        "lock": DATA / "forex_xauusdt_1.lock",
    },
    "xau2": {
        "id": "xau2",
        "virt": "xau2",
        "uid": "d105",
        "name": "XAUUSDT_2",
        "short": "D105",
        "title": "XAUUSDT_2 · Isolated $100×30x · D105 ayna",
        "state": DATA / "forex_xauusdt_2_state.json",
        "hist": DATA / "forex_xauusdt_2_history.json",
        "lock": DATA / "forex_xauusdt_2.lock",
    },
}


def desk_of(name: str | None) -> dict:
    key = str(name or "").strip().lower()
    if key not in DESKS:
        raise KeyError(f"unknown_desk:{key}")
    return DESKS[key]


def _now_iso() -> str:
    return datetime.now(_TZ).strftime("%Y.%m.%d %H:%M:%S")


def _empty() -> dict:
    return {
        "balance": INIT_BAL,
        "init_balance": INIT_BAL,
        "total_pnl": 0.0,
        "last_dir": "NEUTRAL",
        "position": None,
        "positions": [],
        "last_reject": None,
        "seq": 0,
        "cooldown": {"buy": 0.0, "sell": 0.0},
    }


def _atomic(path: Path, data) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    tmp = path.with_suffix(path.suffix + ".tmp")
    tmp.write_text(json.dumps(data, ensure_ascii=False, indent=2), encoding="utf-8")
    tmp.replace(path)


def _load_state(desk: dict) -> dict:
    path = desk["state"]
    if not path.exists():
        return _empty()
    try:
        st = json.loads(path.read_text(encoding="utf-8"))
    except (json.JSONDecodeError, OSError):
        return _empty()
    if not isinstance(st, dict):
        return _empty()
    base = _empty()
    for k, v in base.items():
        st.setdefault(k, v)
    if st.get("position") and not st.get("positions"):
        st["positions"] = [st["position"]]
    if not isinstance(st.get("cooldown"), dict):
        st["cooldown"] = {"buy": 0.0, "sell": 0.0}
    return st


def _plist(st: dict) -> list:
    rows = st.get("positions")
    if not isinstance(rows, list):
        rows = []
    if not rows and st.get("position"):
        rows = [st["position"]]
    st["positions"] = rows
    st["position"] = rows[0] if rows else None
    return rows


def _load_hist(desk: dict) -> list:
    path = desk["hist"]
    if not path.exists():
        return []
    try:
        h = json.loads(path.read_text(encoding="utf-8"))
        return h if isinstance(h, list) else []
    except (json.JSONDecodeError, OSError):
        return []


def _locked(desk_key: str):
    def deco(fn):
        @wraps(fn)
        def wrap(*a, **kw):
            desk = desk_of(kw.get("desk") or (a[0] if a and isinstance(a[0], str) else desk_key))
            DATA.mkdir(parents=True, exist_ok=True)
            with open(desk["lock"], "a+", encoding="utf-8") as lk:
                fcntl.flock(lk.fileno(), fcntl.LOCK_EX)
                return fn(*a, **kw)
        return wrap
    return deco


def _close_record(desk: dict, st: dict, hist: list, pos: dict, exit_px: float, reason: str, fee_close: float = 0.0) -> dict:
    entry = float(pos.get("entry") or pos.get("entry_price") or 0)
    qty = _qty(pos)
    side = pos.get("side") or "buy"
    comm_open = float(pos.get("commission_open") or 0)
    comm_close = float(fee_close or 0)
    if comm_close <= 0:
        comm_close = abs(exit_px * qty) * float(pos.get("taker_rate") or _taker())
    gross = _pnl(side, entry, exit_px, qty)
    comm = round(comm_open + comm_close, 6)
    net = round(gross - comm, 4)
    st["balance"] = round(float(st.get("balance") or 0) + gross - comm_close, 6)
    st["total_pnl"] = round(float(st.get("total_pnl") or 0) + net, 4)
    try:
        from binance_virtual_live import apply_close
        apply_close(desk["virt"], gross, comm_close)
    except Exception:
        pass
    rec = {
        **pos,
        "exit": _r(exit_px),
        "exit_price": _r(exit_px),
        "close_time": _now_iso(),
        "exit_time_tr": _now_iso(),
        "gross": gross,
        "commission_open": comm_open,
        "commission_close": comm_close,
        "commission": comm,
        "pnl": net,
        "win": net >= 0,
        "close_reason": reason,
        "balance_after": st["balance"],
    }
    hist.append(rec)
    if len(hist) > HIST_MAX:
        del hist[:-HIST_MAX]
    try:
        from forex_book import COOLDOWN_LOSS, COOLDOWN_WIN
        wait = COOLDOWN_WIN if net >= 0 else COOLDOWN_LOSS
    except Exception:
        wait = 180 if net >= 0 else 600
    cd = st.setdefault("cooldown", {"buy": 0.0, "sell": 0.0})
    if not isinstance(cd, dict):
        cd = {"buy": 0.0, "sell": 0.0}
        st["cooldown"] = cd
    cd[side] = time.time() + wait
    return rec


def _flatten(desk: dict, st: dict, hist: list, pos: dict, bid: float, ask: float, reason: str) -> bool:
    hint = _exit_px(pos.get("side") or "buy", bid, ask)
    fee = abs(hint * _qty(pos)) * float(pos.get("taker_rate") or _taker())
    _close_record(desk, st, hist, pos, hint, reason, fee_close=fee)
    st["positions"] = []
    st["position"] = None
    return True


def _open(desk: dict, st: dict, side: str, bid: float, ask: float, signal: str, tf: str, kl: list, src: dict | None = None) -> dict | None:
    if _plist(st):
        return None
    hint = _open_px(side, bid, ask)
    qty = _qty_for(hint)
    if qty <= 0:
        st["last_reject"] = {"side": side, "reason": "qty_min", "at": _now_iso()}
        return None
    try:
        from binance_virtual_live import available
        avail = available(desk["virt"])
    except Exception:
        avail = float(st.get("balance") or 0)
    if avail is not None and avail < MARGIN:
        st["last_reject"] = {
            "side": side, "reason": "margin_short",
            "detail": f"virt={avail}", "at": _now_iso(),
        }
        return None
    from bin_b103_binance import place_market
    try:
        fill = place_market(side, qty, reduce_only=False, leverage=LEVERAGE, fallback_px=hint)
    except Exception as e:
        st["last_reject"] = {
            "side": side, "reason": "fill_err",
            "detail": str(e)[:80], "at": _now_iso(),
        }
        return None
    if not fill or not fill.get("ok"):
        st["last_reject"] = {
            "side": side,
            "reason": str((fill or {}).get("error") or "open_fail")[:80],
            "detail": str((fill or {}).get("detail") or "")[:80] or None,
            "at": _now_iso(),
        }
        return None
    entry = float(fill["price"])
    qty = float(fill["qty"])
    notional = float(fill["notional"])
    rate = _taker()
    fee = float(fill.get("fee") if fill.get("fee") is not None else abs(notional) * rate)
    st["seq"] = int(st.get("seq") or 0) + 1
    uid = desk["uid"]
    pos = {
        "id": f"{desk['id']}-{st['seq']}-{int(time.time())}",
        "symbol": SYMBOL,
        "side": side,
        "volume": qty,
        "qty": qty,
        "entry": entry,
        "entry_price": entry,
        "open_time": _now_iso(),
        "entry_time_tr": _now_iso(),
        "signal": signal,
        "interval": tf,
        "margin": MARGIN,
        "margin_usd": MARGIN,
        "leverage": LEVERAGE,
        "notional": notional,
        "commission": fee,
        "commission_open": fee,
        "taker_rate": rate,
        "book": desk["id"],
        "engine": uid,
        "fill_src": "binance_usdm_virtual",
        "venue": "binance_usdm",
        "margin_type": MARGIN_TYPE,
        "order_type": "MARKET",
        "order_status": fill.get("status") or "FILLED",
        "order_id": None,
        "live": False,
        "mirror": True,
        "mirror_src_id": (src or {}).get("id"),
        "mirror_uid": uid,
        "max_hold_h": float(POLICY.get("max_hold_h") or 24.0),
        "loss_stop_atr": float(POLICY.get("loss_stop_atr") or 3.0),
    }
    pos = init_lock_fields(pos, atr=atr_from_klines(kl), price=entry)
    print(
        f"[{desk['name']}] VIRT Isolated MARKET {side.upper()} qty={qty} @{entry} "
        f"margin=${MARGIN:.0f} lev={LEVERAGE}x notional=${notional:.2f} "
        f"taker ${fee:.4f} src={uid}",
        flush=True,
    )
    st["balance"] = round(float(st.get("balance") or 0) - fee, 6)
    st["total_pnl"] = round(float(st.get("total_pnl") or 0) - fee, 6)
    try:
        from binance_virtual_live import apply_open
        apply_open(desk["virt"], fee, MARGIN)
    except Exception:
        pass
    st["positions"] = [pos]
    st["position"] = pos
    st["last_reject"] = None
    return pos


def _retag(desk: dict, pos: dict) -> None:
    pos["book"] = desk["id"]
    pos["engine"] = pos.get("mirror_uid") or desk["uid"]
    pos["mirror"] = True
    pos["live"] = False
    pos["fill_src"] = pos.get("fill_src") or "binance_usdm_virtual"
    pos["venue"] = "binance_usdm"


def _isolated_liq(desk: dict, st: dict, hist: list, bid: float, ask: float) -> bool:
    try:
        from forex_book import STOPOUT_RATIO
        ratio = float(STOPOUT_RATIO)
    except Exception:
        ratio = 1.0
    stopout = -MARGIN * ratio
    closed = False
    for pos in list(_plist(st)):
        mark = _exit_px(pos["side"], bid, ask)
        net = _net_float(pos, mark)
        if net is not None and net <= stopout:
            if _flatten(desk, st, hist, pos, bid, ask, "isolated_liq"):
                closed = True
    return closed


def _apply(desk: dict, st: dict, hist: list, bid: float, ask: float, kl: list) -> dict:
    src = engine_paper_pos_for(desk["uid"])
    uid = desk["uid"]
    want = _engine_side(src)
    src_id = src.get("id") if src else None
    closed = 0
    opened = 0
    action = "hold"
    for pos in _plist(st):
        _retag(desk, pos)
    if _isolated_liq(desk, st, hist, bid, ask):
        closed = 1
        action = "close"
    have = _plist(st)
    pos = have[0] if have else None
    if want is None:
        if pos and _flatten(desk, st, hist, pos, bid, ask, "mirror_flat"):
            closed = 1
            action = "close"
        st["last_dir"] = "NEUTRAL"
        return {
            "ok": True,
            "closed": closed,
            "opened": 0,
            "held": len(_plist(st)),
            "updated": 0,
            "engine": engine_info_for(uid),
            "side": None,
            "action": action,
            "mirror": True,
            "signal": "NEUTRAL",
            "src_id": src_id,
            "uid": uid,
            "desk": desk["id"],
        }
    same = bool(
        pos
        and pos.get("side") == want
        and str(pos.get("mirror_src_id") or "") == str(src_id or "")
    )
    if pos and not same:
        if _flatten(desk, st, hist, pos, bid, ask, "mirror_reverse"):
            closed = 1
            action = "reverse"
        pos = _plist(st)[0] if _plist(st) else None
    if want and not _plist(st):
        tf = str((src or {}).get("interval") or "1h")
        sig = str((src or {}).get("signal") or ("UP" if want == "buy" else "DOWN"))
        new = _open(desk, st, want, bid, ask, sig, tf, kl or [], src=src)
        if new:
            opened = 1
            action = "open"
        else:
            action = "open_fail"
    direction = "UP" if want == "buy" else "DOWN"
    st["last_dir"] = direction
    return {
        "ok": True,
        "closed": closed,
        "opened": opened,
        "held": len(_plist(st)),
        "updated": 0,
        "engine": engine_info_for(uid),
        "side": want,
        "action": action,
        "mirror": True,
        "signal": direction,
        "src_id": src_id,
        "uid": uid,
        "desk": desk["id"],
    }


@_locked("xau1")
def apply_liv_signal(desk: str, bid: float, ask: float, kl: list | None = None) -> dict:
    if bid <= 0 or ask <= 0:
        return {"ok": False, "error": "no_quote"}
    cfg = desk_of(desk)
    st = _load_state(cfg)
    hist = _load_hist(cfg)
    out = _apply(cfg, st, hist, bid, ask, kl or [])
    _atomic(cfg["state"], st)
    _atomic(cfg["hist"], hist)
    return out


def apply_all(bid: float, ask: float, kl: list | None = None) -> dict:
    out = {}
    for key in DESKS:
        out[key] = apply_liv_signal(key, bid, ask, kl)
    return out


def snapshot(desk: str, bid: float | None = None, ask: float | None = None) -> dict:
    cfg = desk_of(desk)
    st = _load_state(cfg)
    hist = _load_hist(cfg)
    rows = []
    float_sum = 0.0
    mark_px = None
    if bid and ask:
        mark_px = (float(bid) + float(ask)) / 2.0
        try:
            from bin_b103_binance import premium
            pr = premium()
            if pr.get("mark"):
                mark_px = float(pr["mark"])
        except Exception:
            pass
    if not mark_px:
        try:
            from bin_b103_data import live_quote
            q = live_quote()
            bq, aq = float(q.get("bid") or 0), float(q.get("ask") or 0)
            mark_px = (bq + aq) / 2.0 if bq and aq else (bq or aq or None)
        except Exception:
            mark_px = None
    for pos in _plist(st):
        _retag(cfg, pos)
        item = dict(pos)
        if mark_px:
            item = _apply_live_mark(item, None, mark_px)
            float_sum += item.get("float_pnl") or 0
        rows.append(item)
    eng = engine_info_for(cfg["uid"])
    bal = float(st.get("balance") or 0)
    init = float(st.get("init_balance") or INIT_BAL)
    live = {
        "enabled": False,
        "paused": True,
        "paper": True,
        "configured": False,
        "venue": "binance_usdm",
        "virtual": True,
        "margin": MARGIN,
        "leverage": LEVERAGE,
        "margin_type": MARGIN_TYPE,
        "symbol": SYMBOL,
    }
    out = {
        "ok": True,
        "book": cfg["id"],
        "id": cfg["id"],
        "name": cfg["name"],
        "title": cfg["title"],
        "engine": eng,
        "symbol": SYMBOL,
        "dec": _PX,
        "balance": round(bal, 2),
        "wallet": round(bal, 2),
        "used_margin": round(MARGIN * len(rows), 2),
        "available": round(bal - MARGIN * len(rows), 2),
        "equity": round(bal + float_sum, 2) if rows else round(bal, 2),
        "init_balance": init,
        "margin_type": MARGIN_TYPE,
        "total_pnl": round(float(st.get("total_pnl") or 0), 2),
        "unrealized_pnl": round(float_sum, 2) if rows else 0.0,
        "float_pnl": round(float_sum, 2) if rows else None,
        "open_count": len(rows),
        "trade_count": int(st.get("seq") or 0) or (len(hist) + len(rows)),
        "position": rows[0] if rows else None,
        "positions": rows,
        "history": list(reversed(hist[-200:])),
        "history_n": len(hist),
        "margin": MARGIN,
        "leverage": LEVERAGE,
        "last_dir": st.get("last_dir"),
        "last_reject": st.get("last_reject"),
        "night_quiet": False,
        "night_window": None,
        "mirror": True,
        "virtual": True,
        "live": live,
        "venue": "binance_usdm",
        "costs": {
            "fee_model": "binance_taker",
            "note": f"{cfg['name']} sanal Isolated $100×30x · {cfg['short']} ayna · taker %0.05 · emir yok",
            "venue": "binance_usdm",
            "virtual": True,
            "taker_rate": 0.0005,
            "dec": _PX,
        },
    }
    out["total_pnl"] = round(out["equity"] - init, 2)
    try:
        from desk_meta import attach
        attach(out, cfg["id"], hist=hist, positions=rows, state_path=cfg["state"], init=init)
    except Exception:
        pass
    out["init_balance"] = round(float(out.get("init_balance") or init), 2)
    out["total_pnl"] = round(float(out.get("equity") or 0) - out["init_balance"], 2)
    try:
        from binance_virtual_live import INIT as _VINIT, account as _vacc
        acc = _vacc(cfg["virt"])
        out["balance"] = round(float(acc["wallet"]), 2)
        out["wallet"] = out["balance"]
        out["available"] = round(float(acc["available"]), 2)
        out["equity"] = round(float(acc["equity"]), 2)
        out["init_balance"] = float(acc.get("init") or _VINIT)
        out["total_pnl"] = round(out["equity"] - out["init_balance"], 2)
        live["usdt_wallet"] = acc["wallet"]
        live["usdt_available"] = acc["available"]
        live["usdt_equity"] = out["equity"]
        out["um_wallet"] = out["balance"]
        out["um_available"] = out["available"]
        out["um_equity"] = out["equity"]
    except Exception:
        pass
    return out
