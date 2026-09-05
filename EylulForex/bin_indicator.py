"""Binance indikatör ekranı — sembol ayarı + mum / fiyat."""
from __future__ import annotations

import json
import re
from pathlib import Path

from coin_kasa import quote

_DIR = Path(__file__).resolve().parent
_CFG = _DIR / "data" / "binance_indicator.json"
_DEFAULT = "BULLAUSDT"
_TF_MAP = {
    "1m": "1m",
    "5m": "5m",
    "15m": "15m",
    "1h": "1h",
    "4h": "4h",
    "1d": "1d",
}


def _norm_symbol(raw: str) -> str:
    s = (raw or "").strip().upper().replace("/", "").replace("-", "")
    if not re.fullmatch(r"[A-Z0-9]{4,20}", s):
        raise ValueError("geçersiz sembol")
    return s


def load_symbol() -> str:
    try:
        if _CFG.exists():
            d = json.loads(_CFG.read_text(encoding="utf-8"))
            sym = _norm_symbol(str(d.get("symbol") or _DEFAULT))
            return sym
    except Exception:
        pass
    return _DEFAULT


def _symbol_trading(sym: str) -> bool:
    """Binance USDT-M perpetual veya spot'ta sembol var mı."""
    try:
        from binance_fapi_guard import um_klines
        if um_klines(sym, "1m", 1):
            return True
    except Exception:
        pass
    try:
        import urllib.request
        url = f"https://fapi.binance.com/fapi/v1/klines?symbol={sym}&interval=1m&limit=1"
        req = urllib.request.Request(url, headers={"User-Agent": "coptc-bin-indicator/1"})
        with urllib.request.urlopen(req, timeout=8) as resp:
            import json as _json
            rows = _json.load(resp)
        if isinstance(rows, list) and rows:
            return True
    except Exception:
        pass
    try:
        import urllib.request
        url = f"https://api.binance.com/api/v3/ticker/bookTicker?symbol={sym}"
        req = urllib.request.Request(url, headers={"User-Agent": "coptc-bin-indicator/1"})
        with urllib.request.urlopen(req, timeout=8) as resp:
            import json as _json
            d = _json.load(resp)
        return bool(d.get("bidPrice") or d.get("askPrice"))
    except Exception:
        return False


def save_symbol(raw: str) -> str:
    sym = _norm_symbol(raw)
    if not _symbol_trading(sym):
        raise ValueError(f"{sym} Binance'de bulunamadı — örn. BULLAUSDT, BTCUSDT")
    _CFG.parent.mkdir(parents=True, exist_ok=True)
    tmp = _CFG.with_suffix(".tmp")
    tmp.write_text(json.dumps({"symbol": sym}, ensure_ascii=False, indent=2), encoding="utf-8")
    tmp.replace(_CFG)
    return sym


def config() -> dict:
    sym = load_symbol()
    return {"ok": True, "symbol": sym, "default": _DEFAULT}


def spot(tf: str = "1h") -> dict:
    sym = load_symbol()
    q = quote(sym)
    kl = _fetch_klines(sym, _TF_MAP.get(tf, "1h"), 80)
    hi = lo = None
    if kl:
        hi = max(b["h"] for b in kl)
        lo = min(b["l"] for b in kl)
    mark = float(q.get("mark") or 0)
    bid = float(q.get("bid") or mark)
    ask = float(q.get("ask") or mark)
    return {
        "ok": True,
        "symbol": sym,
        "timeframe": tf,
        "bid": bid,
        "ask": ask,
        "mark": mark,
        "spread": (ask - bid) if ask and bid else 0,
        "day_high": hi,
        "day_low": lo,
        "src": q.get("src") or "binance",
    }


def _fetch_klines(symbol: str, interval: str, limit: int) -> list:
    raw: list = []
    try:
        from binance_fapi_guard import um_klines
        raw = um_klines(symbol, interval, limit) or []
    except Exception:
        raw = []
    if not raw:
        try:
            from binance_fapi_guard import public_klines
            raw = public_klines(symbol, interval, limit) or []
        except Exception:
            raw = []
    if not raw:
        try:
            import urllib.request
            url = (
                f"https://api.binance.com/api/v3/klines?symbol={symbol}"
                f"&interval={interval}&limit={int(limit)}"
            )
            req = urllib.request.Request(url, headers={"User-Agent": "coptc-bin-indicator/1"})
            with urllib.request.urlopen(req, timeout=10) as resp:
                import json
                raw = json.load(resp) or []
        except Exception:
            raw = []
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


def chart(tf: str = "1h", limit: int = 240) -> dict:
    sym = load_symbol()
    interval = _TF_MAP.get(tf, "1h")
    lim = max(20, min(int(limit or 240), 500))
    rows = _fetch_klines(sym, interval, lim)
    return {
        "ok": True,
        "symbol": sym,
        "timeframe": tf,
        "candles": rows,
        "count": len(rows),
    }


def _json_clean(obj):
    try:
        import numpy as np
        if isinstance(obj, np.bool_):
            return bool(obj)
        if isinstance(obj, np.integer):
            return int(obj)
        if isinstance(obj, np.floating):
            v = float(obj)
            return None if v != v or v in (float("inf"), float("-inf")) else v
    except Exception:
        pass
    if isinstance(obj, dict):
        return {k: _json_clean(v) for k, v in obj.items()}
    if isinstance(obj, list):
        return [_json_clean(v) for v in obj]
    if isinstance(obj, float) and (obj != obj or obj in (float("inf"), float("-inf"))):
        return None
    return obj


def market_snapshot(tf: str = "1m") -> dict:
    import pandas as pd
    from live_indicator_monitor import get_market_snapshot

    sym = load_symbol()
    interval = _TF_MAP.get(tf, "1m")
    rows = _fetch_klines(sym, interval, 250)
    if len(rows) < 30:
        return {
            "ok": False,
            "symbol": sym,
            "timeframe": tf,
            "error": "insufficient_data",
            "count": len(rows),
            "min_bars": 30,
        }
    df = pd.DataFrame({
        "timestamp": pd.to_datetime([r["time"] for r in rows], unit="s", utc=True),
        "open": [r["open"] for r in rows],
        "high": [r["high"] for r in rows],
        "low": [r["low"] for r in rows],
        "close": [r["close"] for r in rows],
        "volume": [float(r.get("volume") or r.get("v") or 0) for r in rows],
    })
    try:
        snap = get_market_snapshot(df)
    except Exception as e:
        return {"ok": False, "symbol": sym, "timeframe": tf, "error": str(e)[:200]}
    snap["ok"] = True
    snap["symbol"] = sym
    snap["timeframe"] = tf
    snap["bars"] = len(rows)
    return _json_clean(snap)


def liquidations(symbol: str | None = None) -> dict:
    from bin_liquidations import feed
    sym = _norm_symbol(symbol) if symbol else load_symbol()
    return feed(sym)
