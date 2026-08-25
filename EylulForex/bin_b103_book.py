"""BIN_XAUUSDT defter — sanal Isolated $100×30x · Kalman+VWAP + S/R.

Grafik (LIV) ile aynı motor; kasa / marj ayrı ($100×30x). Binance XAUUSDT fiyat,
MARKET merdiven dolumu, taker %0.05. new_order yok. A2 / Aktif et sürmez.
GPSUSDT / fx_algo_* / CEM01 dosyalarına yazmaz.
"""
from __future__ import annotations

import fcntl
import json
import math
import sys
import time
from datetime import datetime
from pathlib import Path
from zoneinfo import ZoneInfo

_DIR = Path(__file__).resolve().parent
_ROOT = _DIR.parent
_AGUSTOS = str(_ROOT / "AgustosKripto")
for p in (_AGUSTOS, str(_DIR)):
    if p not in sys.path:
        sys.path.insert(0, p)

from atr_profit_lock import atr_from_klines, init_lock_fields  # noqa: E402
from exit_policy import policy_for  # noqa: E402
DATA = _DIR / "data"
_STATE = DATA / "forex_bin_b103_state.json"
_HIST = DATA / "forex_bin_b103_history.json"
_LOCK = DATA / "forex_bin_b103.lock"
_TZ = ZoneInfo("Europe/Istanbul")

MARGIN = 100.0
LEVERAGE = 30
SYMBOL = "XAUUSDT"
MAX_OPEN = 1
MARGIN_TYPE = "ISOLATED"
PAPER_BAL = 180.0
HIST_MAX = 400
REVERSE_MIN_AGE_MIN = 15.0
BN_FLAT_HOLD_SEC = 30 * 60
POLICY = policy_for("Test")
_PX = 2
LIV_ENG = {"uid": "liv", "name": "Kalman+VWAP", "title": "Kalman+VWAP · S/R"}


def _now_iso() -> str:
    return datetime.now(_TZ).strftime("%Y.%m.%d %H:%M:%S")


def _r(px) -> float:
    try:
        from bin_b103_binance import round_px
        return round_px(float(px))
    except Exception:
        return round(float(px), _PX)


def _paper() -> bool:
    try:
        from bin_b103_binance import paper_mode
        return bool(paper_mode())
    except Exception:
        return False


def _paper_bal() -> float:
    try:
        from bin_b103_binance import paper_balance
        return float(paper_balance())
    except Exception:
        return PAPER_BAL


def _virt() -> bool:
    try:
        from binance_virtual_live import enabled
        return bool(enabled())
    except Exception:
        return False


def _cooling(st: dict, side: str) -> float:
    left = float((st.get("cooldown") or {}).get(side) or 0.0) - time.time()
    return max(0.0, left)


def _empty() -> dict:
    init = _paper_bal() if _paper() else 0.0
    return {
        "balance": init,
        "init_balance": init,
        "total_pnl": 0.0,
        "last_dir": "NEUTRAL",
        "position": None,
        "positions": [],
        "last_reject": None,
        "seq": 0,
        "cooldown": {"buy": 0.0, "sell": 0.0},
        "bn_flat_src_id": None,
        "bn_flat_at": None,
    }


def _atomic(path: Path, data) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    tmp = path.with_suffix(path.suffix + ".tmp")
    tmp.write_text(json.dumps(data, ensure_ascii=False, indent=2), encoding="utf-8")
    tmp.replace(path)


def _load_state() -> dict:
    if not _STATE.exists():
        return _empty()
    try:
        st = json.loads(_STATE.read_text(encoding="utf-8"))
    except (json.JSONDecodeError, OSError):
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


def _load_hist() -> list:
    if not _HIST.exists():
        return []
    try:
        h = json.loads(_HIST.read_text(encoding="utf-8"))
        return h if isinstance(h, list) else []
    except (json.JSONDecodeError, OSError):
        return []


def _taker() -> float:
    if _paper():
        return 0.0004
    try:
        from bin_b103_binance import taker_rate
        return float(taker_rate())
    except Exception:
        return 0.0005


def _qty_for(entry: float) -> float:
    try:
        from bin_b103_binance import size_from_margin
        return float(size_from_margin(MARGIN, LEVERAGE, entry))
    except Exception:
        if entry <= 0:
            return 0.0
        raw = MARGIN * LEVERAGE / float(entry)
        return math.floor(raw / 0.001) * 0.001


def _open_px(side: str, bid: float, ask: float) -> float:
    return float(ask if side == "buy" else bid)


def _exit_px(side: str, bid: float, ask: float) -> float:
    return float(bid if side == "buy" else ask)


def _pnl(side: str, entry: float, exit_px: float, qty: float) -> float:
    if side == "buy":
        return round((exit_px - entry) * qty, 4)
    return round((entry - exit_px) * qty, 4)


def _qty(pos: dict) -> float:
    return float(pos.get("qty") or pos.get("volume") or 0)


def _net_float(pos: dict, mark: float) -> float:
    entry = float(pos.get("entry") or pos.get("entry_price") or 0)
    qty = _qty(pos)
    gross = _pnl(pos.get("side") or "buy", entry, mark, qty)
    comm_open = float(pos.get("commission_open") or 0)
    rate = float(pos.get("taker_rate") or _taker())
    comm_close = abs(mark * qty) * rate
    return round(gross - comm_open - comm_close, 4)


def _mark_pnl(pos: dict, mark: float) -> float:
    """Binance uygulamasıyla aynı: mark-to-mark, kapanış komisyonu yok."""
    entry = float(pos.get("entry") or pos.get("entry_price") or 0)
    return _pnl(pos.get("side") or "buy", entry, mark, _qty(pos))


def _apply_live_mark(item: dict, live_pos: dict | None, mark_px: float | None) -> dict:
    """Açık kart = borsa satırı (giriş / mark / PnL / marj / liq)."""
    pos = live_pos or {}
    entry = float(pos.get("entry") or item.get("entry") or item.get("entry_price") or 0)
    qty = abs(float(pos.get("amt") or 0)) or _qty(item)
    mark = float(pos.get("mark") or 0) or float(mark_px or 0) or entry
    computed = _mark_pnl({**item, "entry": entry, "qty": qty}, mark) if mark else None
    stale = pos.get("unrealized")
    upnl = computed if computed is not None else stale
    iso = float(pos.get("isolated_wallet") or 0) or float(item.get("margin") or MARGIN)
    notional = float(pos.get("notional") or 0) or abs(qty * (mark or entry))
    item["entry"] = entry
    item["entry_price"] = entry
    item["qty"] = qty
    item["volume"] = qty
    item["mark"] = _r(mark)
    item["float_pnl"] = round(float(upnl or 0), 2)
    item["float_net"] = item["float_pnl"]
    item["pnl"] = item["float_pnl"]
    item["margin"] = round(iso, 2)
    item["margin_usd"] = item["margin"]
    item["notional"] = round(notional, 2)
    item["liq_price"] = float(pos.get("liq") or item.get("liq_price") or 0) or None
    item["roe"] = round(item["float_pnl"] / iso * 100.0, 2) if iso else None
    return _display_levels(item)


def _display_levels(item: dict) -> dict:
    """Kart alt satırı: SL fiyatı + yoksa isolated liq tahmini."""
    entry = float(item.get("entry") or item.get("entry_price") or 0)
    atr = float(item.get("atr") or 0)
    side = item.get("side") or "buy"
    qty = _qty(item)
    lev = float(item.get("leverage") or LEVERAGE)
    if item.get("stop") is None and entry:
        if int(item.get("stop_level") or 0) >= 1 and item.get("stop_upnl") is not None and qty:
            move = float(item["stop_upnl"]) / qty
            item["stop"] = _r(entry + move if side == "buy" else entry - move)
            item["lock_stage"] = int(item.get("stop_level") or 0)
        elif atr:
            n = float(item.get("loss_stop_atr") or 3.0)
            item["stop"] = _r(entry - n * atr if side == "buy" else entry + n * atr)
    if not item.get("liq_price") and entry and lev > 0:
        item["liq_price"] = _r(
            entry * (1.0 - 1.0 / lev) if side == "buy" else entry * (1.0 + 1.0 / lev)
        )
    return item


def _age_min(pos: dict) -> float:
    ts = pos.get("entry_time_tr") or pos.get("open_time")
    if not ts:
        return 0.0
    try:
        opened = datetime.strptime(str(ts)[:19], "%Y.%m.%d %H:%M:%S").replace(tzinfo=_TZ)
        return max(0.0, (datetime.now(_TZ) - opened).total_seconds() / 60.0)
    except Exception:
        return 0.0


def _max_hold_h(pos: dict) -> float:
    if pos.get("max_hold_h") is not None:
        return float(pos["max_hold_h"])
    return float(POLICY.get("max_hold_h") or 24.0)


def _hold_expired(pos: dict) -> bool:
    return _age_min(pos) >= _max_hold_h(pos) * 60.0


def _kl_for_lock() -> list:
    try:
        from bin_b103_data import xau_klines
        return xau_klines("5m", 80)
    except Exception:
        return []


def _ensure_lock(pos: dict, mark: float, kl: list | None = None) -> dict:
    if float(pos.get("atr_usd") or 0):
        return pos
    rows = kl if kl else _kl_for_lock()
    return init_lock_fields(
        pos,
        atr=atr_from_klines(rows),
        margin_usd=float(pos.get("margin") or pos.get("margin_usd") or MARGIN),
        leverage=float(pos.get("leverage") or LEVERAGE),
        price=float(pos.get("entry") or pos.get("entry_price") or mark),
    )


def _close_record(st: dict, hist: list, pos: dict, exit_px: float, reason: str, fee_close: float = 0.0) -> dict:
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
        if _virt():
            apply_close("bin", gross, comm_close)
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


def _close_live(pos: dict, fallback_px: float) -> dict:
    from bin_b103_binance import close_live
    close_side = "sell" if (pos.get("side") or "buy") == "buy" else "buy"
    return close_live(fallback_px=fallback_px, qty=_qty(pos), side=close_side)


def _flatten_one(st: dict, hist: list, pos: dict, bid: float, ask: float, reason: str) -> bool:
    hint = _exit_px(pos.get("side") or "buy", bid, ask)
    if _paper() or not pos.get("live"):
        fee = abs(hint * _qty(pos)) * float(pos.get("taker_rate") or _taker())
        _close_record(st, hist, pos, hint, reason, fee_close=fee)
        st["positions"] = []
        st["position"] = None
        return True
    fill = _close_live(pos, hint)
    if not fill.get("ok"):
        st["last_reject"] = {
            "side": pos.get("side"),
            "reason": "live_close_fail",
            "detail": str(fill.get("error") or reason)[:80],
            "at": _now_iso(),
        }
        return False
    px = float(fill.get("price") or hint)
    fee = float(fill.get("fee") or 0)
    _close_record(st, hist, pos, px, reason, fee_close=fee)
    st["positions"] = []
    st["position"] = None
    return True


def _bn_side(row: dict) -> str | None:
    amt = float((row or {}).get("positionAmt") or 0)
    if abs(amt) <= 0:
        return None
    return "buy" if amt > 0 else "sell"


def _um_isolated_empty() -> bool:
    """Tüm USDT-M isolated boş — fapi positionRisk olmasa da hayalet yok."""
    try:
        from binance_um_wallet import fetch
        acc = fetch() or {}
        w = float(acc.get("wallet") or 0)
        a = float(acc.get("available") or 0)
        u = float(acc.get("unrealized") or 0)
        return w > 0 and abs(w - a) < 0.08 and abs(u) < 0.08
    except Exception:
        return False


def _reconcile(st: dict, hist: list, bid: float, ask: float) -> bool:
    try:
        from binance_virtual_live import enabled
        if enabled():
            return False
    except Exception:
        pass
    if _paper():
        return False
    from bin_b103_binance import live_position_state
    state, row = live_position_state()
    rows = _plist(st)
    if state == "unknown" and _um_isolated_empty():
        state = "flat"
        row = None
    if state == "unknown":
        return False
    if state == "flat":
        if not rows:
            return False
        pos = rows[0]
        _close_record(st, hist, pos, _exit_px(pos.get("side") or "buy", bid, ask), "bn_flat")
        st["bn_flat_src_id"] = pos.get("mirror_src_id") or st.get("bn_flat_src_id")
        st["bn_flat_at"] = time.time()
        st["positions"] = []
        st["position"] = None
        return True
    bn_side = _bn_side(row)
    bn_qty = abs(float((row or {}).get("positionAmt") or 0))
    bn_entry = float((row or {}).get("entryPrice") or 0)
    if not rows:
        st["seq"] = int(st.get("seq") or 0) + 1
        pos = {
            "id": f"binb103-{st['seq']}-{int(time.time())}",
            "symbol": SYMBOL,
            "side": bn_side or "buy",
            "volume": bn_qty,
            "qty": bn_qty,
            "entry": bn_entry or _open_px(bn_side or "buy", bid, ask),
            "entry_price": bn_entry or _open_px(bn_side or "buy", bid, ask),
            "open_time": _now_iso(),
            "entry_time_tr": _now_iso(),
            "signal": "ADOPT",
            "margin": MARGIN,
            "margin_usd": MARGIN,
            "leverage": int(float((row or {}).get("leverage") or LEVERAGE) or LEVERAGE),
            "notional": round(bn_qty * (bn_entry or 0), 8),
            "commission_open": 0.0,
            "taker_rate": _taker(),
            "fill_src": "binance_usdm_live",
            "venue": "binance_usdm",
            "margin_type": MARGIN_TYPE,
            "live": True,
            "adopted": True,
            "max_hold_h": float(POLICY.get("max_hold_h") or 24.0),
            "loss_stop_atr": float(POLICY.get("loss_stop_atr") or 3.0),
        }
        pos = _ensure_lock(pos, float(pos["entry"]))
        st["positions"] = [pos]
        st["position"] = pos
        print(f"[BIN_B1#03] ADOPT {pos['side']} qty={bn_qty} @{pos['entry']}", flush=True)
        return True
    pos = rows[0]
    if pos.get("side") != bn_side:
        if _flatten_one(st, hist, pos, bid, ask, "side_mismatch"):
            return True
        return False
    dirty = False
    if abs(_qty(pos) - bn_qty) > 0.0006:
        pos["qty"] = bn_qty
        pos["volume"] = bn_qty
        dirty = True
    if bn_entry:
        pos["entry"] = bn_entry
        pos["entry_price"] = bn_entry
        dirty = True
    return dirty


def _open(st: dict, side: str, bid: float, ask: float, signal: str, tf: str, kl: list, plan: dict | None = None) -> dict | None:
    rows = _plist(st)
    if rows or len(rows) >= MAX_OPEN:
        return None
    hint = _open_px(side, bid, ask)
    qty = _qty_for(hint)
    if qty <= 0:
        st["last_reject"] = {"side": side, "reason": "qty_min", "at": _now_iso()}
        return None
    paper = _paper()
    fill = None
    if paper:
        avail = float(st.get("balance") or 0)
        if avail < MARGIN:
            st["last_reject"] = {
                "side": side, "reason": "margin_short",
                "detail": f"paper={avail}", "at": _now_iso(),
            }
            return None
        entry = hint
        notional = round(qty * entry, 8)
        rate = _taker()
        fee = abs(notional) * rate
    else:
        from bin_b103_binance import (
            configured,
            live_enabled,
            live_paused,
            live_position_state,
            place_market,
            usdt_available,
        )
        if not configured():
            st["last_reject"] = {"side": side, "reason": "keys_missing", "at": _now_iso()}
            return None
        if live_paused() or not live_enabled():
            st["last_reject"] = {"side": side, "reason": "live_paused", "at": _now_iso()}
            return None
        virt = _virt()
        if not virt:
            bn_state, _ = live_position_state()
            if bn_state == "open":
                st["last_reject"] = {"side": side, "reason": "binance_already_open", "at": _now_iso()}
                return None
            if bn_state == "unknown":
                st["last_reject"] = {"side": side, "reason": "bn_status_unknown", "at": _now_iso()}
                return None
        avail = usdt_available()
        if avail is not None and avail < MARGIN:
            st["last_reject"] = {
                "side": side, "reason": "margin_short",
                "detail": f"usdt={avail}", "at": _now_iso(),
            }
            return None
        try:
            fill = place_market(side, qty, reduce_only=False, leverage=LEVERAGE, fallback_px=hint)
        except Exception as e:
            st["last_reject"] = {
                "side": side, "reason": "fill_err",
                "detail": str(e)[:80], "at": _now_iso(),
            }
            return None
        if not fill.get("ok"):
            err = str(fill.get("error") or "live_open_fail")
            if err == "tradfi_unsigned" or "-4411" in err or "TradFi" in err:
                err = "tradfi_unsigned"
            st["last_reject"] = {
                "side": side,
                "reason": err,
                "detail": str(fill.get("detail") or "")[:80] or None,
                "at": _now_iso(),
            }
            return None
        entry = float(fill["price"])
        qty = float(fill["qty"])
        notional = float(fill["notional"])
        rate = _taker()
        fee = float(fill.get("fee") if fill.get("fee") is not None else abs(notional) * rate)
    virt = paper or _virt()
    st["seq"] = int(st.get("seq") or 0) + 1
    pos = {
        "id": f"binb103-{st['seq']}-{int(time.time())}",
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
        "book": "binb103",
        "engine": "kalman_vwap",
        "fill_src": "paper" if paper else ("binance_usdm_virtual" if virt else "binance_usdm_live"),
        "venue": "paper" if paper else "binance_usdm",
        "margin_type": MARGIN_TYPE,
        "order_type": "MARKET",
        "order_status": (fill or {}).get("status") or "FILLED",
        "order_id": None if paper else (fill or {}).get("order_id"),
        "live": bool(not paper and not virt),
        "mirror": False,
        "max_hold_h": float(POLICY.get("max_hold_h") or 24.0),
        "loss_stop_atr": float(POLICY.get("loss_stop_atr") or 3.0),
    }
    pos = init_lock_fields(pos, atr=atr_from_klines(kl), price=entry)
    if plan:
        from forex_book import _apply_plan
        _apply_plan(pos, plan)
    tag = "PAPER" if paper else ("VIRT Isolated" if virt else f"LIVE {MARGIN_TYPE}")
    print(
        f"[BIN_B1#03] {tag} MARKET {side.upper()} qty={qty} @{entry} "
        f"margin=${MARGIN:.0f} lev={LEVERAGE}x notional=${notional:.2f} "
        f"taker ${fee:.4f} orderId={pos['order_id']}",
        flush=True,
    )
    st["balance"] = round(float(st.get("balance") or 0) - fee, 6)
    st["total_pnl"] = round(float(st.get("total_pnl") or 0) - fee, 6)
    try:
        from binance_virtual_live import apply_open
        if _virt() and not paper:
            apply_open("bin", fee, MARGIN)
    except Exception:
        pass
    st["positions"] = [pos]
    st["position"] = pos
    st["last_reject"] = None
    return pos


def _locked(fn):
    def wrap(*a, **kw):
        DATA.mkdir(parents=True, exist_ok=True)
        with open(_LOCK, "a+", encoding="utf-8") as lk:
            fcntl.flock(lk.fileno(), fcntl.LOCK_EX)
            return fn(*a, **kw)
    return wrap


def _engine_side(src: dict | None) -> str | None:
    if not src:
        return None
    raw = str(src.get("side") or "").strip().upper()
    if raw in ("LONG", "BUY", "UP"):
        return "buy"
    if raw in ("SHORT", "SELL", "DOWN"):
        return "sell"
    sig = str(src.get("signal") or "").strip().upper()
    if sig == "UP":
        return "buy"
    if sig == "DOWN":
        return "sell"
    return None


def _wait_live_flat(*, tries: int = 8) -> bool:
    try:
        from binance_virtual_live import enabled
        if enabled():
            return True
    except Exception:
        pass
    if _paper():
        return True
    from bin_b103_binance import live_position_state
    for _ in range(max(1, tries)):
        state, _row = live_position_state()
        if state == "flat":
            return True
        time.sleep(0.35)
    return False


def _flat_hold_blocks(st: dict, src_id) -> bool:
    """Elle kapanış: aynı src_id yalnız BN_FLAT_HOLD_SEC boyunca bloklanır."""
    skip = str(st.get("bn_flat_src_id") or "")
    if not skip or not src_id or skip != str(src_id):
        return False
    try:
        age = time.time() - float(st.get("bn_flat_at") or 0)
    except (TypeError, ValueError):
        age = BN_FLAT_HOLD_SEC + 1
    if age < BN_FLAT_HOLD_SEC:
        return True
    st["bn_flat_src_id"] = None
    st["bn_flat_at"] = None
    return False


def _retag_liv(pos: dict) -> None:
    pos["book"] = "binb103"
    pos["engine"] = "kalman_vwap"
    pos["mirror"] = False
    if _virt():
        pos["live"] = False
        if pos.get("fill_src") in (None, "", "binance_usdm_live"):
            pos["fill_src"] = "binance_usdm_virtual"
        pos["venue"] = "binance_usdm"


def _liv_ctx() -> tuple:
    from forex_data import BOOK_LEVEL_TF, BOOK_SIGNAL_TF
    from forex_signal import live_signal, rail_signals, sr_levels
    from bin_b103_data import xau_klines

    def rows(tf: str, n: int):
        return xau_klines(tf, n)

    signal = live_signal(
        BOOK_SIGNAL_TF,
        candles=rows(BOOK_SIGNAL_TF, 120),
        klines_fn=rows,
        use_tick=False,
    )
    levels = sr_levels(rows(BOOK_LEVEL_TF, 120))
    rail = rail_signals(klines_fn=rows)
    return signal, levels, rail, BOOK_SIGNAL_TF


def _plan_would_stop(pos: dict, plan: dict, mark: float) -> bool:
    """Açık lota yeni S/R stopu hemen basmasın — mevcut lot korunur."""
    stop = plan.get("stop")
    if stop is None or not mark:
        return False
    stop = float(stop)
    if pos["side"] == "buy":
        return mark <= stop + 2.0
    return mark >= stop - 2.0


def _protect_liv(st: dict, hist: list, bid: float, ask: float, rail, levels) -> bool:
    from forex_book import (
        STOPOUT_RATIO,
        TP_MARGIN_PCT,
        _apply_plan,
        _hit_stop,
        _hit_target,
        _m5_against,
        _plan,
        _update_lock,
    )

    closed = False
    stopout = -MARGIN * STOPOUT_RATIO
    for pos in list(_plist(st)):
        _retag_liv(pos)
        if (pos.get("target") is None or pos.get("stop") is None) and levels:
            plan = _plan(pos["side"], float(pos["entry"]), levels, book="binb103")
            mark0 = _exit_px(pos["side"], bid, ask)
            if plan and not _plan_would_stop(pos, plan, mark0):
                _apply_plan(pos, plan)
        mark = _exit_px(pos["side"], bid, ask)
        _update_lock(pos, mark)
        net = _net_float(pos, mark)
        gross = _mark_pnl(pos, mark)
        if net is not None and net <= stopout:
            reason = "stopout"
        elif _hit_stop(pos, mark):
            reason = "lock" if int(pos.get("lock_stage") or 0) else "stop"
        elif gross is not None and gross >= MARGIN * TP_MARGIN_PCT:
            reason = "tp35"
        elif _hit_target(pos, mark):
            reason = "sr"
        elif _m5_against(pos, rail):
            if pos.get("target") is None and pos.get("stop") is None:
                continue
            reason = "m5"
        else:
            continue
        if _flatten_one(st, hist, pos, bid, ask, reason):
            closed = True
    return closed


def _apply_liv_unlocked(st: dict, hist: list, bid: float, ask: float, kl: list) -> dict:
    from forex_book import _plan, _plan_reject

    if not _virt():
        _reconcile(st, hist, bid, ask)
    signal, levels, rail, sig_tf = _liv_ctx()
    direction = str((signal or {}).get("direction") or "NEUTRAL").upper()
    want = "buy" if direction == "UP" else "sell" if direction == "DOWN" else None
    closed = 0
    opened = 0
    action = "hold"
    for pos in _plist(st):
        _retag_liv(pos)
    if _protect_liv(st, hist, bid, ask, rail, levels):
        closed = 1
        action = "close"
    if want and not _plist(st):
        wait = _cooling(st, want)
        hint = _open_px(want, bid, ask)
        plan = None if wait else _plan(want, hint, levels, book="binb103")
        why = "bekleme" if wait else _plan_reject(plan, MARGIN)
        if why:
            prev = st.get("last_reject") or {}
            st["last_reject"] = {
                "side": want,
                "reason": why,
                "wait": int(wait),
                "rr": (plan or {}).get("rr"),
                "risk_usd": (plan or {}).get("risk_usd"),
                "reward_usd": (plan or {}).get("reward_usd"),
                "at": _now_iso(),
            }
            if prev.get("reason") != why or prev.get("side") != want:
                action = action if action in ("close", "reverse") else "reject"
        else:
            pos = _open(st, want, bid, ask, direction, sig_tf, kl or [], plan=plan)
            if pos:
                opened = 1
                action = "open"
                st["last_reject"] = None
            else:
                action = "open_fail"
    if direction != (st.get("last_dir") or "NEUTRAL"):
        st["last_dir"] = direction
    return {
        "ok": True,
        "closed": closed,
        "opened": opened,
        "held": len(_plist(st)),
        "updated": 0,
        "engine": dict(LIV_ENG),
        "side": want,
        "action": action,
        "mirror": False,
        "signal": direction,
    }


def _sync_unlocked(st: dict, hist: list, bid: float, ask: float, kl: list) -> dict:
    return _apply_liv_unlocked(st, hist, bid, ask, kl)


@_locked
def apply_liv_signal(bid: float, ask: float, kl: list | None = None) -> dict:
    """Kalman+VWAP + S/R — LIV ile aynı motor, $100×30x sanal Isolated."""
    if bid <= 0 or ask <= 0:
        return {"ok": False, "error": "no_quote"}
    st = _load_state()
    hist = _load_hist()
    out = _apply_liv_unlocked(st, hist, bid, ask, kl or [])
    _atomic(_STATE, st)
    _atomic(_HIST, hist)
    return out


def sync_from_engine(bid: float, ask: float, kl: list | None = None) -> dict:
    return apply_liv_signal(bid, ask, kl)


@_locked
def open_position(side: str, bid: float, ask: float, *, signal: str, tf: str, kl: list) -> dict | None:
    if bid <= 0 or ask <= 0:
        return None
    st = _load_state()
    hist = _load_hist()
    out = _sync_unlocked(st, hist, bid, ask, kl or [])
    _atomic(_STATE, st)
    _atomic(_HIST, hist)
    return st.get("position") if out.get("opened") else None


@_locked
def close_expired(bid: float, ask: float, kl: list) -> dict:
    if bid <= 0 or ask <= 0:
        return {"ok": False, "error": "no_quote"}
    st = _load_state()
    hist = _load_hist()
    out = _sync_unlocked(st, hist, bid, ask, kl or [])
    _atomic(_STATE, st)
    _atomic(_HIST, hist)
    return out


@_locked
def close_if_reverse(new_side: str, bid: float, ask: float, kl: list) -> dict:
    if bid <= 0 or ask <= 0:
        return {"ok": False, "error": "no_quote"}
    st = _load_state()
    hist = _load_hist()
    out = _sync_unlocked(st, hist, bid, ask, kl or [])
    _atomic(_STATE, st)
    _atomic(_HIST, hist)
    return out


@_locked
def trail(bid: float, ask: float, kl: list) -> dict:
    if bid <= 0 or ask <= 0:
        return {"ok": False, "error": "no_quote"}
    st = _load_state()
    hist = _load_hist()
    out = _sync_unlocked(st, hist, bid, ask, kl or [])
    _atomic(_STATE, st)
    _atomic(_HIST, hist)
    return out


@_locked
def switch_live(want_live: bool) -> dict:
    """Buton: canlı aç/kapa. Yeni open yok — yalnız kontrol + açık defter satırını kapatır."""
    from bin_b103_binance import close_live, live_position_state, set_live_mode
    from bin_b103_data import live_quote
    q = live_quote()
    bid = float(q.get("bid") or 0)
    ask = float(q.get("ask") or 0)
    st = _load_state()
    hist = _load_hist()
    closed = 0
    bn_closed = False
    if want_live:
        for pos in list(_plist(st)):
            px = _exit_px(pos.get("side") or "buy", bid, ask) if bid and ask else float(pos.get("entry") or 0)
            fee = abs(px * _qty(pos)) * float(pos.get("taker_rate") or _taker())
            _close_record(st, hist, pos, px or float(pos.get("entry") or 0), "switch_live", fee_close=fee)
            closed += 1
        st["positions"] = []
        st["position"] = None
        ctrl = set_live_mode(True, source="dashboard:CANLI")
    else:
        state, _ = live_position_state()
        if state == "open" and (bid or ask):
            fill = close_live(fallback_px=ask or bid)
            bn_closed = bool(fill.get("ok"))
        for pos in list(_plist(st)):
            px = _exit_px(pos.get("side") or "buy", bid, ask) if bid and ask else float(pos.get("entry") or 0)
            fee = abs(px * _qty(pos)) * float(pos.get("taker_rate") or _taker())
            _close_record(st, hist, pos, px or float(pos.get("entry") or 0), "switch_paper", fee_close=fee)
            closed += 1
        st["positions"] = []
        st["position"] = None
        ctrl = set_live_mode(False, source="dashboard:sanal")
    _atomic(_STATE, st)
    _atomic(_HIST, hist)
    return {
        "ok": True,
        "live": bool(want_live),
        "paper": not bool(want_live),
        "closed": closed,
        "bn_closed": bn_closed,
        "control": ctrl,
    }


@_locked
def switch_engine(uid: str) -> dict:
    """Aktif et kaydı — BIN artık Kalman+VWAP; açık lot kapanmaz."""
    from bin_b103_signal import current_uid, set_engine_uid

    info = set_engine_uid(uid)
    if not info.get("ok"):
        return info
    info.update({
        "closed": 0,
        "bn_closed": False,
        "engine": current_uid(),
        "opened": False,
        "liv": True,
    })
    return info


def _live_snap() -> dict:
    out = {
        "enabled": False,
        "paused": True,
        "paper": True,
        "configured": False,
        "venue": "binance_usdm",
        "margin": MARGIN,
        "leverage": LEVERAGE,
        "margin_type": MARGIN_TYPE,
        "symbol": SYMBOL,
    }
    try:
        from bin_b103_binance import live_status
        st = live_status()
        out.update(st)
        out["margin"] = MARGIN
        out["leverage"] = LEVERAGE
        out["margin_type"] = MARGIN_TYPE
        out["symbol"] = SYMBOL
    except Exception as e:
        out["error"] = str(e)[:80]
    if _virt():
        out["virtual"] = True
        out["enabled"] = False
        out["paper"] = True
        out["error"] = None
    return out


def snapshot(bid: float | None = None, ask: float | None = None) -> dict:
    st = _load_state()
    hist = _load_hist()
    rows = []
    float_sum = 0.0
    live = _live_snap()
    virt_book = _virt()
    live_pos = None if virt_book else (live.get("position") if isinstance(live.get("position"), dict) else None)
    mark_px = None
    if live_pos and live_pos.get("mark"):
        mark_px = float(live_pos["mark"])
    elif bid and ask:
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
            from forex_data import forex_quote
            q = forex_quote()
            bq, aq = float(q.get("bid") or 0), float(q.get("ask") or 0)
            mark_px = (bq + aq) / 2.0 if bq and aq else (bq or aq or None)
        except Exception:
            mark_px = None
    ghost = False
    virt = virt_book
    if not virt:
        ghost = bool(live.get("enabled") and not live.get("paper") and _um_isolated_empty())
    if ghost:
        live_pos = None
    for pos in _plist(st):
        if ghost:
            break
        item = dict(pos)
        _retag_liv(item)
        if mark_px or live_pos:
            item = _apply_live_mark(item, live_pos, mark_px)
            float_sum += item.get("float_pnl") or 0
        else:
            item = _display_levels(item)
        rows.append(item)
    virt_um = virt
    if not virt_um:
        try:
            from binance_um_wallet import fetch as _um
            acc = _um()
            if acc and acc.get("wallet") is not None:
                live["usdt_wallet"] = acc.get("wallet")
                live["usdt_available"] = acc.get("available")
                live["usdt_equity"] = acc.get("equity")
                live["usdt_unrealized"] = acc.get("unrealized")
        except Exception:
            pass
    eng = dict(LIV_ENG)
    bal = float(st.get("balance") or 0)
    init = float(st.get("init_balance") or 0)
    out = {
        "ok": True,
        "book": "binb103",
        "id": "binb103",
        "name": "BIN_XAUUSDT",
        "title": "BIN_XAUUSDT · Isolated $100×30x · Kalman+VWAP",
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
        "mirror": False,
        "virtual": True,
        "live": live,
        "venue": "binance_usdm",
        "costs": {
            "fee_model": "binance_taker",
            "note": "BIN_XAUUSDT sanal Isolated $100×30x · Kalman+VWAP · taker %0.05 · emir yok",
            "venue": "binance_usdm",
            "virtual": True,
            "taker_rate": 0.0005,
            "dec": _PX,
        },
    }
    if live.get("usdt_wallet") is not None:
        out["um_wallet"] = round(float(live["usdt_wallet"]), 2)
        out["wallet"] = out["um_wallet"]
        if live.get("usdt_available") is not None:
            out["um_available"] = round(float(live["usdt_available"]), 2)
            out["available"] = out["um_available"]
        if live.get("usdt_equity") is not None:
            out["um_equity"] = round(float(live["usdt_equity"]), 2)
            out["equity"] = out["um_equity"]
    if rows and live_pos and live_pos.get("unrealized") is not None:
        out["unrealized_pnl"] = round(float(live_pos["unrealized"]), 2)
        out["float_pnl"] = out["unrealized_pnl"]
        if out.get("um_equity") is None:
            out["equity"] = round(bal + out["unrealized_pnl"], 2)
    out["total_pnl"] = round(out["equity"] - init, 2)
    try:
        from desk_meta import attach
        attach(out, "binb103", hist=hist, positions=rows, state_path=_STATE, init=init)
    except Exception:
        pass
    out["init_balance"] = round(init, 2)
    out["total_pnl"] = round(float(out.get("equity") or 0) - out["init_balance"], 2)
    try:
        from binance_virtual_live import INIT as _VINIT, account as _vacc
        if _virt():
            acc = _vacc()
            out["balance"] = round(float(acc["wallet"]), 2)
            out["wallet"] = out["balance"]
            out["available"] = round(float(acc["available"]), 2)
            out["equity"] = round(float(acc["equity"]), 2)
            out["init_balance"] = float(_VINIT)
            out["total_pnl"] = round(out["equity"] - out["init_balance"], 2)
            live["usdt_wallet"] = acc["wallet"]
            live["usdt_available"] = acc["available"]
            live["usdt_equity"] = acc["equity"]
            out["um_wallet"] = out["balance"]
            out["um_available"] = out["available"]
            out["um_equity"] = out["equity"]
    except Exception:
        pass
    return out
