"""ACE / ENA — sanal Isolated $500 kasa. Canlı emir yok.

ACE  = A1#26 MACD Histogram Diverjansı
ENA  = A1#28 Triple EMA (8-21-55)
Dolum: Binance bid/ask (taker %0.05). GPS / XAU / D104 runner'ına yazmaz.
"""
from __future__ import annotations

import fcntl
import json
import sys
import time
import urllib.request
from datetime import datetime, timezone
from pathlib import Path
from zoneinfo import ZoneInfo

_DIR = Path(__file__).resolve().parent
_ROOT = _DIR.parent
_POLY = str(_ROOT / "temmuzPoly")
for p in (str(_DIR), str(_ROOT), _POLY):
    if p not in sys.path:
        sys.path.insert(0, p)

from algo_signals import macd_histogram_div, triple_ema  # noqa: E402

DATA = _DIR / "data"
_TZ = ZoneInfo("Europe/Istanbul")
INIT_BAL = 500.0
MARGIN = 100.0
LEVERAGE = 20
TAKER = 0.0005
MAX_HOLD_H = 24.0
STOP_ATR = 3.0
TP_MARGIN_PCT = 0.35
HIST_MAX = 200

DESKS = {
    "ace": {
        "id": "ace",
        "symbol": "ACEUSDT",
        "name": "ACEUSDT",
        "short": "A1#26",
        "src": "A1#26 MACD Histogram Diverjansı",
        "title": "ACEUSDT · Isolated $100×20x · A1#26",
        "algo": 26,
        "fn": macd_histogram_div,
        "state": DATA / "forex_aceusdt_state.json",
        "hist": DATA / "forex_aceusdt_history.json",
        "lock": DATA / "forex_aceusdt.lock",
        "dec": 5,
    },
    "ena": {
        "id": "ena",
        "symbol": "ENAUSDT",
        "name": "ENAUSDT",
        "short": "A1#28",
        "src": "A1#28 Triple EMA (8-21-55)",
        "title": "ENAUSDT · Isolated $100×20x · A1#28",
        "algo": 28,
        "fn": triple_ema,
        "state": DATA / "forex_enausdt_state.json",
        "hist": DATA / "forex_enausdt_history.json",
        "lock": DATA / "forex_enausdt.lock",
        "dec": 5,
    },
}


def desk_of(name: str | None) -> dict:
    key = str(name or "").strip().lower()
    if key in DESKS:
        return DESKS[key]
    raise KeyError(key)


def _now() -> str:
    return datetime.now(_TZ).strftime("%Y.%m.%d %H:%M:%S")


def _empty() -> dict:
    return {
        "balance": INIT_BAL,
        "init_balance": INIT_BAL,
        "total_pnl": 0.0,
        "seq": 0,
        "last_dir": "NEUTRAL",
        "last_reject": None,
        "position": None,
        "positions": [],
    }


def _load(desk: dict) -> dict:
    try:
        st = json.loads(desk["state"].read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError):
        st = {}
    base = _empty()
    for k, v in base.items():
        st.setdefault(k, v)
    if st.get("position") and not st.get("positions"):
        st["positions"] = [st["position"]]
    return st


def _save(desk: dict, st: dict) -> None:
    DATA.mkdir(parents=True, exist_ok=True)
    tmp = desk["state"].with_suffix(".tmp")
    tmp.write_text(json.dumps(st, ensure_ascii=False, indent=2), encoding="utf-8")
    tmp.replace(desk["state"])


def _hist(desk: dict) -> list:
    try:
        rows = json.loads(desk["hist"].read_text(encoding="utf-8"))
        return rows if isinstance(rows, list) else []
    except (OSError, json.JSONDecodeError):
        return []


def _save_hist(desk: dict, rows: list) -> None:
    DATA.mkdir(parents=True, exist_ok=True)
    tmp = desk["hist"].with_suffix(".tmp")
    tmp.write_text(json.dumps(rows[-HIST_MAX:], ensure_ascii=False, indent=2), encoding="utf-8")
    tmp.replace(desk["hist"])


def _plist(st: dict) -> list:
    rows = [p for p in (st.get("positions") or []) if isinstance(p, dict)]
    if not rows and isinstance(st.get("position"), dict):
        rows = [st["position"]]
    return rows


def quote(symbol: str) -> dict:
    try:
        from binance_fapi_guard import get_book, get_mark
        hit = get_book(symbol) or {}
        bid = float(hit.get("bid") or 0)
        ask = float(hit.get("ask") or 0)
        mark = float(hit.get("mark") or get_mark(symbol) or 0)
        if bid or ask or mark:
            if not bid:
                bid = mark or ask
            if not ask:
                ask = mark or bid
            return {"bid": bid, "ask": ask, "mark": mark or ((bid + ask) / 2), "src": "ws"}
    except Exception:
        pass
    try:
        url = f"https://api.binance.com/api/v3/ticker/bookTicker?symbol={symbol}"
        req = urllib.request.Request(url, headers={"User-Agent": "coptc-coin-kasa/1"})
        with urllib.request.urlopen(req, timeout=8) as resp:
            d = json.load(resp)
        bid = float(d.get("bidPrice") or 0)
        ask = float(d.get("askPrice") or 0)
        return {"bid": bid, "ask": ask, "mark": (bid + ask) / 2 if bid and ask else bid or ask, "src": "spot"}
    except Exception:
        return {"bid": 0.0, "ask": 0.0, "mark": 0.0, "src": "none"}


def klines(symbol: str, interval: str = "1h", limit: int = 80) -> list[dict]:
    raw = []
    try:
        from binance_fapi_guard import public_klines
        raw = public_klines(symbol, interval, limit) or []
    except Exception:
        raw = []
    if not raw:
        try:
            url = (
                f"https://api.binance.com/api/v3/klines?symbol={symbol}"
                f"&interval={interval}&limit={int(limit)}"
            )
            req = urllib.request.Request(url, headers={"User-Agent": "coptc-coin-kasa/1"})
            with urllib.request.urlopen(req, timeout=10) as resp:
                raw = json.load(resp)
        except Exception:
            return []
    out = []
    for r in raw:
        if not isinstance(r, (list, tuple)) or len(r) < 6:
            continue
        out.append({
            "time": int(r[0]) // 1000,
            "open": float(r[1]),
            "high": float(r[2]),
            "low": float(r[3]),
            "close": float(r[4]),
            "volume": float(r[5]),
            "o": float(r[1]),
            "h": float(r[2]),
            "l": float(r[3]),
            "c": float(r[4]),
            "v": float(r[5]),
        })
    return out


def signal(desk: dict, kl: list[dict] | None = None) -> dict:
    rows = kl if kl is not None else klines(desk["symbol"], "1h", 80)
    bars = rows[:-1] if len(rows) > 20 else rows
    try:
        direction = desk["fn"](bars)
    except Exception as e:
        return {"direction": "NEUTRAL", "error": str(e)[:120], "engine": f"a1_{desk['algo']}"}
    return {
        "direction": direction or "NEUTRAL",
        "engine": f"a1_{desk['algo']}",
        "name": desk["short"],
        "n": len(bars),
    }


def _atr(kl: list[dict], period: int = 14) -> float:
    if len(kl) < period + 1:
        return 0.0
    trs = []
    for i in range(1, len(kl)):
        h, l, pc = kl[i]["h"], kl[i]["l"], kl[i - 1]["c"]
        trs.append(max(h - l, abs(h - pc), abs(l - pc)))
    w = trs[-period:]
    return sum(w) / len(w) if w else 0.0


def _qty(px: float) -> float:
    if px <= 0:
        return 0.0
    return round((MARGIN * LEVERAGE) / px, 4)


def _pnl(side: str, entry: float, mark: float, qty: float) -> float:
    if side == "buy":
        return (mark - entry) * qty
    return (entry - mark) * qty


def _fee(notional: float) -> float:
    return abs(notional) * TAKER


def _mark_of(side: str, bid: float, ask: float) -> float:
    return bid if side == "buy" else ask


def _open(st: dict, desk: dict, side: str, bid: float, ask: float, direction: str) -> dict | None:
    if _plist(st):
        return None
    if float(st["balance"]) < MARGIN:
        st["last_reject"] = {"side": side, "reason": "margin_short", "at": _now()}
        return None
    px = ask if side == "buy" else bid
    qty = _qty(px)
    if qty <= 0:
        st["last_reject"] = {"side": side, "reason": "qty_min", "at": _now()}
        return None
    notional = qty * px
    fee = _fee(notional)
    st["seq"] = int(st.get("seq") or 0) + 1
    pos = {
        "id": f"{desk['id']}-{st['seq']}-{int(time.time())}",
        "symbol": desk["symbol"],
        "side": side,
        "volume": qty,
        "qty": qty,
        "entry": px,
        "entry_price": px,
        "open_time": _now(),
        "entry_time_tr": _now(),
        "signal": direction,
        "interval": "1h",
        "margin": MARGIN,
        "leverage": LEVERAGE,
        "notional": round(notional, 6),
        "commission": fee,
        "commission_open": fee,
        "taker_rate": TAKER,
        "book": desk["id"],
        "engine": f"a1_{desk['algo']}",
        "fill_src": "binance_book_taker",
        "venue": "binance",
        "margin_type": "ISOLATED",
        "order_type": "MARKET",
        "order_status": "FILLED",
        "live": False,
        "paper": True,
    }
    st["balance"] = round(float(st["balance"]) - fee, 6)
    st["total_pnl"] = round(float(st["total_pnl"]) - fee, 6)
    st["positions"] = [pos]
    st["position"] = pos
    st["last_reject"] = None
    print(
        f"[{desk['name']}] PAPER {desk['short']} {side.upper()} qty={qty} @{px} "
        f"$100×20x fee={fee:.4f}",
        flush=True,
    )
    return pos


def _close(st: dict, hist: list, desk: dict, bid: float, ask: float, reason: str) -> dict | None:
    pos = (_plist(st) or [None])[0]
    if not pos:
        return None
    side = pos["side"]
    px = bid if side == "buy" else ask
    qty = float(pos.get("qty") or pos.get("volume") or 0)
    entry = float(pos.get("entry") or 0)
    gross = _pnl(side, entry, px, qty)
    fee = _fee(qty * px)
    net = gross - fee
    st["balance"] = round(float(st["balance"]) + net, 6)
    st["total_pnl"] = round(float(st["total_pnl"]) + net, 6)
    row = {
        **pos,
        "exit": px,
        "exit_price": px,
        "pnl": round(net, 4),
        "commission_close": fee,
        "close_reason": reason,
        "close_time": _now(),
        "exit_time_tr": _now(),
    }
    hist.append(row)
    st["positions"] = []
    st["position"] = None
    print(f"[{desk['name']}] CLOSE {side} @{px} pnl={net:.2f} {reason}", flush=True)
    return row


def _protect(st: dict, hist: list, desk: dict, bid: float, ask: float, atr: float) -> bool:
    pos = (_plist(st) or [None])[0]
    if not pos:
        return False
    side = pos["side"]
    mark = _mark_of(side, bid, ask)
    qty = float(pos.get("qty") or 0)
    entry = float(pos.get("entry") or 0)
    upnl = _pnl(side, entry, mark, qty)
    if upnl >= MARGIN * TP_MARGIN_PCT:
        _close(st, hist, desk, bid, ask, "tp")
        return True
    if upnl <= -MARGIN:
        _close(st, hist, desk, bid, ask, "stop_margin")
        return True
    if atr > 0 and abs(mark - entry) >= STOP_ATR * atr:
        if (side == "buy" and mark < entry) or (side == "sell" and mark > entry):
            _close(st, hist, desk, bid, ask, "atr_stop")
            return True
    try:
        opened = datetime.strptime(pos.get("open_time") or "", "%Y.%m.%d %H:%M:%S")
        if (datetime.now() - opened).total_seconds() >= MAX_HOLD_H * 3600:
            _close(st, hist, desk, bid, ask, "max_hold")
            return True
    except ValueError:
        pass
    return False


def tick(name: str) -> dict:
    desk = desk_of(name)
    q = quote(desk["symbol"])
    bid, ask = float(q.get("bid") or 0), float(q.get("ask") or 0)
    if bid <= 0 or ask <= 0:
        return {"ok": False, "id": desk["id"], "error": "no_quote"}
    kl = klines(desk["symbol"], "1h", 80)
    sig = signal(desk, kl)
    atr = _atr(kl)
    direction = str(sig.get("direction") or "NEUTRAL").upper()
    want = "buy" if direction == "UP" else "sell" if direction == "DOWN" else None
    desk["lock"].parent.mkdir(parents=True, exist_ok=True)
    with open(desk["lock"], "a+", encoding="utf-8") as lk:
        fcntl.flock(lk.fileno(), fcntl.LOCK_EX)
        st = _load(desk)
        hist = _hist(desk)
        dirty = False
        if _protect(st, hist, desk, bid, ask, atr):
            dirty = True
        pos = (_plist(st) or [None])[0]
        if want and pos and pos.get("side") != want:
            _close(st, hist, desk, bid, ask, "flip")
            pos = None
            dirty = True
        if want and not pos:
            if _open(st, desk, want, bid, ask, direction):
                dirty = True
        if direction != (st.get("last_dir") or ""):
            st["last_dir"] = direction
            dirty = True
        if dirty:
            _save(desk, st)
            _save_hist(desk, hist)
    return snapshot(name, bid, ask, sig=sig)


def snapshot(
    name: str,
    bid: float | None = None,
    ask: float | None = None,
    sig: dict | None = None,
) -> dict:
    desk = desk_of(name)
    if bid is None or ask is None:
        q = quote(desk["symbol"])
        bid = float(q.get("bid") or 0)
        ask = float(q.get("ask") or 0)
    st = _load(desk)
    hist = _hist(desk)
    rows = []
    float_sum = 0.0
    for pos in _plist(st):
        item = dict(pos)
        mark = _mark_of(pos["side"], bid, ask) if bid and ask else float(pos.get("entry") or 0)
        fp = _pnl(pos["side"], float(pos.get("entry") or 0), mark, float(pos.get("qty") or 0))
        item["mark"] = mark
        item["float_pnl"] = round(fp, 2)
        item["float_net"] = item["float_pnl"]
        item["pnl"] = item["float_pnl"]
        rows.append(item)
        float_sum += fp
    return {
        "ok": True,
        "book": desk["id"],
        "id": desk["id"],
        "name": desk["name"],
        "title": desk["title"],
        "src": desk["src"],
        "symbol": desk["symbol"],
        "dec": desk["dec"],
        "balance": round(float(st["balance"]), 2),
        "wallet": round(float(st["balance"]), 2),
        "equity": round(float(st["balance"]) + float_sum, 2) if rows else round(float(st["balance"]), 2),
        "init_balance": INIT_BAL,
        "unrealized_pnl": round(float_sum, 2) if rows else 0.0,
        "float_pnl": round(float_sum, 2) if rows else None,
        "total_pnl": round(float(st.get("total_pnl") or 0), 2),
        "open_count": len(rows),
        "trade_count": int(st.get("seq") or 0),
        "position": rows[0] if rows else None,
        "positions": rows,
        "history": list(reversed(hist[-200:])),
        "margin": MARGIN,
        "leverage": LEVERAGE,
        "margin_type": "ISOLATED",
        "last_dir": st.get("last_dir"),
        "last_reject": st.get("last_reject"),
        "paper": True,
        "live": False,
        "signal": sig,
        "engine": {"uid": f"a1_{desk['algo']}", "name": desk["short"], "title": desk["src"]},
        "ts": datetime.now(timezone.utc).isoformat(),
    }


def spot(name: str, timeframe: str = "1h") -> dict:
    desk = desk_of(name)
    q = quote(desk["symbol"])
    book = tick(name)
    return {
        "ok": True,
        "symbol": desk["symbol"],
        "algo": desk["id"],
        "bid": q.get("bid"),
        "ask": q.get("ask"),
        "mid": q.get("mark"),
        "timeframe": timeframe,
        "signal": book.get("signal") or {},
        "book": book,
        "src": q.get("src"),
    }


def chart(name: str, timeframe: str = "1h", limit: int = 240) -> dict:
    desk = desk_of(name)
    tf = timeframe if timeframe in ("1m", "5m", "15m", "1h", "4h", "1d") else "1h"
    rows = klines(desk["symbol"], tf, max(20, min(int(limit or 240), 500)))
    q = quote(desk["symbol"])
    dec = desk["dec"]
    candles = [
        {
            "time": c["time"],
            "open": round(c["open"], dec),
            "high": round(c["high"], dec),
            "low": round(c["low"], dec),
            "close": round(c["close"], dec),
            "volume": round(c["volume"], 4),
        }
        for c in rows
    ]
    return {
        "ok": True,
        "symbol": desk["symbol"],
        "name": desk["name"],
        "timeframe": tf,
        "algo": desk["id"],
        "dec": dec,
        "candles": candles,
        "bid": q.get("bid"),
        "ask": q.get("ask"),
        "mid": q.get("mark"),
        "source": q.get("src") or "binance",
    }
