"""Gate XAU_USDT kotasyon / mum. Sinyal CEM01 (g1); fiyat Gate."""
from __future__ import annotations

import time

from gate_api import CONTRACT, klines, ticker
from gate_book import snapshot

_BAR = {
    "1m": 60, "5m": 300, "15m": 900, "30m": 1800,
    "1h": 3600, "4h": 14400, "1d": 86400,
}
_kl_cache: dict[str, tuple[float, list]] = {}
_KL_TTL = 8.0


def forex_quote() -> dict:
    q = ticker()
    bid, ask = q.get("bid"), q.get("ask")
    mid = q.get("mid") or q.get("last")
    return {
        "symbol": "XAUUSDT",
        "contract": CONTRACT,
        "bid": bid,
        "ask": ask,
        "mid": mid,
        "last": q.get("last"),
        "mark": q.get("mark"),
        "spread": round(float(ask) - float(bid), 2) if bid and ask else None,
        "live_price": mid,
        "src": "gate",
    }


def _cached_klines(tf: str, n: int) -> list[dict]:
    now = time.time()
    hit = _kl_cache.get(tf)
    if hit and now - hit[0] < _KL_TTL and len(hit[1]) >= n:
        return hit[1][-n:]
    rows = klines(tf, n)
    _kl_cache[tf] = (now, rows)
    return rows[-n:]


def forex_spot(timeframe: str = "1m") -> dict:
    q = forex_quote()
    q["book"] = snapshot(q.get("bid"), q.get("ask"))
    try:
        from forex_data import forex_rail as g1_rail
        q["rail"] = g1_rail()
    except Exception:
        q["rail"] = {}
    try:
        from forex_signal import live_signal
        q["signal"] = live_signal("1m")
    except Exception as e:
        q["signal"] = {
            "direction": "NEUTRAL", "confidence": 0.0, "is_stable": False,
            "error": str(e)[:160],
        }
    q["signal_tf"] = "1m"
    q["level_tf"] = "5m"
    q["tick"] = {"score": 0.0, "n": 0}
    q["book_levels"] = {}
    return q


def forex_chart(timeframe: str = "1m", limit: int | None = None, plain: bool = False) -> dict:
    tf = (timeframe or "1m").lower()
    if tf not in _BAR:
        tf = "1m"
    n = 240 if limit is None else max(20, min(500, int(limit)))
    rows = _cached_klines(tf, n)
    q = forex_quote()
    candles = [
        {
            "time": c["time"],
            "open": round(c["open"], 2),
            "high": round(c["high"], 2),
            "low": round(c["low"], 2),
            "close": round(c["close"], 2),
            "volume": round(c["volume"], 2),
        }
        for c in rows
    ]
    out = {
        "symbol": "XAUUSDT",
        "name": "XAUUSDT",
        "timeframe": tf,
        "price_tf": tf,
        "dec": 2,
        "candles": candles,
        "source": "gate",
        "bar_sec": _BAR[tf],
        "bar_left": _BAR[tf],
        "mid": q.get("mid"),
        "bid": q.get("bid"),
        "ask": q.get("ask"),
        "spread": q.get("spread"),
        "live_price": q.get("mid"),
        "tick": {"score": 0.0, "n": 0},
        "levels": {},
        "algo": "gate",
    }
    if candles:
        out["day_high"] = max(c["high"] for c in candles)
        out["day_low"] = min(c["low"] for c in candles)
    try:
        from forex_signal import live_signal
        out["signal"] = live_signal("1m")
    except Exception:
        out["signal"] = {
            "direction": "NEUTRAL", "confidence": 0.0, "is_stable": False,
        }
    out["signal_markers"] = []
    try:
        from forex_data import forex_rail
        out["rail"] = forex_rail()
    except Exception:
        out["rail"] = {}
    return out
