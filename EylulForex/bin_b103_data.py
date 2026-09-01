"""BIN_XAUUSDT — Binance XAUUSDT mum / kotasyon / Kalman+VWAP.

Grafik (LIV) ile aynı sinyal ve S/R; dolum kotasyonu XAUUSDT fapi.
Yahoo / A2 / Aktif et burayı sürmez. GPSUSDT / CEM01 dokunulmaz.
"""
from __future__ import annotations

import json
import time
import urllib.request

_UA = {"User-Agent": "Mozilla/5.0"}
_SPOT = "https://api.binance.com"
_FAPI = "https://fapi.binance.com"
SYMBOL = "XAUUSDT"
_BAR_SEC = {
    "1m": 60, "5m": 300, "15m": 900, "30m": 1800,
    "1h": 3600, "4h": 14400, "1d": 86400,
}
_cache: dict[tuple, tuple[float, object]] = {}
_TTL = 8.0


def _get_json(url: str):
    req = urllib.request.Request(url, headers=_UA)
    with urllib.request.urlopen(req, timeout=10) as r:
        return json.load(r)


def bar_remaining(tf: str) -> int:
    sec = _BAR_SEC.get(tf, 60)
    now = int(time.time())
    return max(0, sec - (now % sec))


def _fapi_ok() -> bool:
    try:
        import sys
        from pathlib import Path
        root = str(Path(__file__).resolve().parents[1])
        if root not in sys.path:
            sys.path.insert(0, str(root))
        from binance_fapi_guard import fapi_blocked
        return not fapi_blocked()
    except Exception:
        return True


def _rows_from_raw(raw: list) -> list[dict]:
    out = []
    for r in raw:
        out.append({
            "time": int(r[0]) // 1000,
            "open": float(r[1]),
            "high": float(r[2]),
            "low": float(r[3]),
            "close": float(r[4]),
            "volume": float(r[5] or 0),
        })
    return out


def _klines_raw(tf: str, limit: int) -> tuple[list[dict], str]:
    """Grafik = USDT-M XAUUSDT. Yahoo/PAXG yok — kotasyonla karışır, sahte iğne çizer."""
    iv = tf if tf in _BAR_SEC else "1m"
    lim = max(20, min(int(limit or 240), 500))
    last_err = "yok"
    try:
        import sys
        from pathlib import Path
        root = str(Path(__file__).resolve().parents[1])
        if root not in sys.path:
            sys.path.insert(0, str(root))
        from binance_fapi_guard import um_klines
        raw = um_klines(SYMBOL, iv, lim)
        if isinstance(raw, list) and raw:
            return _rows_from_raw(raw), "um"
    except Exception as e:
        last_err = str(e)[:160]
    return [], last_err


def xau_klines(tf: str, n: int = 120) -> list[dict]:
    key = ("kl", tf, int(n))
    now = time.time()
    hit = _cache.get(key)
    if hit and now - hit[0] < _TTL:
        return list(hit[1])
    rows, _src = _klines_raw(tf, n)
    rows = rows or []
    _cache[key] = (now, rows)
    return list(rows)


def _bn_rows(tf: str, n: int) -> list[dict]:
    return xau_klines(tf, n)


def signal_klines(tf: str, n: int = 180) -> list[dict]:
    """Geriye dönük: sinyal de Binance XAUUSDT."""
    return xau_klines(tf, n)


def _ticker() -> tuple[dict, str]:
    sources = []
    try:
        import sys
        from pathlib import Path
        root = str(Path(__file__).resolve().parents[1])
        if root not in sys.path:
            sys.path.insert(0, str(root))
        from binance_fapi_guard import get_book
        hit = get_book(SYMBOL)
        if hit and (hit.get("bid") or hit.get("ask")):
            return {
                "bidPrice": hit.get("bid"),
                "askPrice": hit.get("ask"),
                "bidQty": hit.get("bid_qty"),
                "askQty": hit.get("ask_qty"),
            }, "ws"
    except Exception:
        pass
    for src, url in sources:
        try:
            d = _get_json(url)
            if isinstance(d, dict) and (d.get("bidPrice") or d.get("askPrice")):
                return d, src
        except Exception:
            pass
    try:
        from forex_data import forex_quote
        q = forex_quote()
        bid, ask = q.get("bid"), q.get("ask")
        if bid or ask:
            return {"bidPrice": bid, "askPrice": ask}, "xau"
    except Exception:
        pass
    try:
        rows = xau_klines("1m", 4)
        if rows:
            px = float(rows[-1].get("close") or 0)
            if px:
                return {"bidPrice": px, "askPrice": px}, "xau_last"
    except Exception:
        pass
    return {"bidPrice": None, "askPrice": None}, "none"


def live_quote() -> dict:
    d, src = _ticker()
    bid = float(d.get("bidPrice") or 0)
    ask = float(d.get("askPrice") or 0)
    mid = (bid + ask) / 2.0 if bid and ask else (bid or ask)
    dec = 2
    mark = None
    funding = None
    try:
        from bin_b103_binance import premium
        pr = premium()
        mark = pr.get("mark")
        funding = pr.get("last_funding_rate")
    except Exception:
        pass
    return {
        "ok": True,
        "symbol": SYMBOL,
        "name": "XAU / USDT",
        "bid": round(bid, dec) if bid else None,
        "ask": round(ask, dec) if ask else None,
        "mid": round(mid, dec) if mid else None,
        "dec": dec,
        "mark": round(mark, dec) if mark else None,
        "funding_rate": funding,
        "spread": round(ask - bid, dec) if bid and ask else None,
        "live_price": round(mid, dec) if mid else None,
        "src": src,
        "venue": "binance_usdm",
        "virtual": True,
        "stale_sec": 0,
    }


def live_signal_now() -> dict:
    from forex_data import BOOK_SIGNAL_TF
    from forex_signal import live_signal
    return live_signal(
        BOOK_SIGNAL_TF,
        candles=_bn_rows(BOOK_SIGNAL_TF, 120),
        klines_fn=_bn_rows,
        use_tick=False,
    )


def _attach_book(q: dict, book: str, bid, ask, *, apply_bin: bool = False) -> None:
    """BIN sayfası d104 defteri; XAUUSDT_1/2 kendi aynası. Karışmaz."""
    key = str(book or "binb103").strip().lower()
    q["algo"] = key
    if key in ("xau1", "xau2"):
        from xau_mirror import snapshot as xau_snap
        q["book"] = xau_snap(key, bid, ask)
        return
    from bin_b103_book import apply_liv_signal, snapshot
    if apply_bin and bid and ask:
        apply_liv_signal(float(bid), float(ask))
    q["book"] = snapshot(bid, ask)


def live_spot(timeframe: str = "1m", book: str = "binb103") -> dict:
    from forex_data import BOOK_LEVEL_TF, BOOK_SIGNAL_TF

    tf = timeframe if timeframe in _BAR_SEC else "1m"
    q = live_quote()
    q["timeframe"] = tf
    q["bar_sec"] = _BAR_SEC[tf]
    q["bar_left"] = bar_remaining(tf)
    q["tick"] = {"score": 0.0, "n": 0}
    q["signal_tf"] = BOOK_SIGNAL_TF
    q["level_tf"] = BOOK_LEVEL_TF
    try:
        from forex_signal import rail_signals
        q["rail"] = rail_signals(klines_fn=_bn_rows)
    except Exception:
        q["rail"] = {}
    try:
        q["signal"] = live_signal_now()
    except Exception as e:
        q["signal"] = {
            "direction": "NEUTRAL", "confidence": 0.0, "is_stable": False,
            "engine": "kalman_vwap", "error": str(e)[:160],
        }
    try:
        from forex_signal import sr_levels
        levels = sr_levels(_bn_rows(BOOK_LEVEL_TF, 120))
    except Exception:
        levels = {}
    q["book_levels"] = {
        "support": (levels or {}).get("nearest_support"),
        "resistance": (levels or {}).get("nearest_resistance"),
        "tf": BOOK_LEVEL_TF,
    }
    try:
        bid, ask = q.get("bid"), q.get("ask")
        _attach_book(q, book, bid, ask, apply_bin=(str(book or "") == "binb103"))
    except Exception as e:
        q["book"] = {"ok": False, "error": str(e)[:160]}
    return q


def live_chart(timeframe: str = "1m", limit: int = 240, book: str = "binb103") -> dict:
    tf = timeframe if timeframe in _BAR_SEC else "1m"
    n = max(20, min(int(limit or 240), 500))
    try:
        rows = xau_klines(tf, n)
        q = live_quote()
    except Exception as e:
        return {
            "ok": False, "symbol": SYMBOL, "name": "XAU / USDT",
            "timeframe": tf, "algo": "binb103", "error": str(e)[:200],
            "candles": [], "bid": None, "ask": None, "mid": None,
        }
    dec = 2
    candles = [
        {
            "time": c["time"],
            "open": round(c["open"], dec),
            "high": round(c["high"], dec),
            "low": round(c["low"], dec),
            "close": round(c["close"], dec),
            "volume": round(c["volume"], 2),
        }
        for c in rows
    ]
    day = [c for c in candles if time.time() - c["time"] <= 86400] or candles
    hi = max(c["high"] for c in day) if day else None
    lo = min(c["low"] for c in day) if day else None
    out = {
        "ok": True,
        "symbol": SYMBOL,
        "name": "XAU / USDT",
        "timeframe": tf,
        "price_tf": tf,
        "dec": dec,
        "candles": candles,
        "source": q.get("src") or "binance_usdm",
        "bar_sec": _BAR_SEC[tf],
        "bar_left": bar_remaining(tf),
        "algo": str(book or "binb103"),
        "virtual": True,
        "venue": "binance_usdm",
        "day_high": round(hi, dec) if hi else None,
        "day_low": round(lo, dec) if lo else None,
        **{k: q.get(k) for k in ("mid", "bid", "ask", "spread", "live_price", "mark")},
    }
    out["tick"] = {"score": 0.0, "n": 0}
    try:
        from forex_signal import overlay_signals
        sig, marks = overlay_signals(tf, candles, klines_fn=_bn_rows, use_tick=False)
        out["signal"] = sig
        out["signal_markers"] = marks
        out["rail"] = sig.get("rail") or {}
    except Exception as e:
        out["signal"] = {
            "direction": "NEUTRAL", "confidence": 0.0, "is_stable": False,
            "engine": "kalman_vwap", "error": str(e)[:160],
        }
        out["signal_markers"] = []
        out["rail"] = {}
    if not out.get("rail"):
        try:
            from forex_signal import rail_signals
            out["rail"] = rail_signals(klines_fn=_bn_rows)
        except Exception:
            out["rail"] = {}
    try:
        from forex_signal import sr_levels
        out["levels"] = sr_levels(candles)
    except Exception as e:
        out["levels"] = {"ok": False, "error": str(e)[:160]}
    try:
        _attach_book(out, book, out.get("bid"), out.get("ask"), apply_bin=False)
    except Exception:
        out["book"] = None
    return out
