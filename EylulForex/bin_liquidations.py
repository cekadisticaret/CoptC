"""Binance piyasa likidasyon özet — /tmp/binance_liq_cache.json."""
from __future__ import annotations

import json
import time
from datetime import datetime, timezone
from pathlib import Path

LIQ_CACHE_FILE = Path("/tmp/binance_liq_cache.json")
_WS_STALE_SEC = 90.0
_WINDOWS = (
    ("5m", 5 * 60),
    ("15m", 15 * 60),
    ("1h", 60 * 60),
)


def _load_cache() -> dict:
    try:
        if LIQ_CACHE_FILE.exists():
            return json.loads(LIQ_CACHE_FILE.read_text(encoding="utf-8"))
    except Exception:
        pass
    return {}


def _sum_window(rows: list[dict], ms: int, now_ms: int) -> dict:
    cut = now_ms - ms * 1000
    long_usd = short_usd = 0.0
    long_n = short_n = 0
    for r in rows:
        ts = int(r.get("ts") or 0)
        if ts < cut:
            continue
        usd = float(r.get("usd") or 0)
        if r.get("side") == "long":
            long_usd += usd
            long_n += 1
        elif r.get("side") == "short":
            short_usd += usd
            short_n += 1
    return {
        "long_usd": round(long_usd, 2),
        "short_usd": round(short_usd, 2),
        "long_n": long_n,
        "short_n": short_n,
        "total_usd": round(long_usd + short_usd, 2),
    }


def _bias(w15: dict) -> tuple[str, str]:
    lu = float(w15.get("long_usd") or 0)
    su = float(w15.get("short_usd") or 0)
    tot = lu + su
    if tot < 50:
        return "sessiz", "Son 15 dk’da belirgin likidasyon yok"
    if lu > su * 1.6:
        return "long_baski", "Long likidasyonları ağır — düşüş baskısı / stop avı"
    if su > lu * 1.6:
        return "short_baski", "Short likidasyonları ağır — yukarı squeeze / short avı"
    if lu > su:
        return "long_hafif", "Long liq biraz fazla — satış tarafı hafif önde"
    if su > lu:
        return "short_hafif", "Short liq biraz fazla — alım tarafı hafif önde"
    return "dengeli", "Long/short likidasyon dengeli"


def _fmt_tr(ms: int) -> str:
    try:
        dt = datetime.fromtimestamp(ms / 1000, tz=timezone.utc).astimezone()
        return dt.strftime("%H:%M:%S")
    except (OSError, ValueError, OverflowError):
        return ""


def feed(symbol: str) -> dict:
    sym = (symbol or "").strip().upper()
    cache = _load_cache()
    updated_at = float(cache.get("updated_at") or 0)
    age = time.time() - updated_at if updated_at else None
    ws_ok = age is not None and age <= _WS_STALE_SEC
    all_ev = cache.get("events") or {}
    rows = list(all_ev.get(sym) or [])
    now_ms = int(time.time() * 1000)
    windows = {label: _sum_window(rows, sec, now_ms) for label, sec in _WINDOWS}
    bias, yorum = _bias(windows.get("15m") or {})
    recent = []
    for r in reversed(rows[-12:]):
        recent.append({
            "ts": int(r.get("ts") or 0),
            "time_tr": _fmt_tr(int(r.get("ts") or 0)),
            "side": r.get("side"),
            "price": r.get("price"),
            "usd": r.get("usd"),
        })
    return {
        "ok": True,
        "symbol": sym,
        "ws_ok": ws_ok,
        "ws_age_sec": round(age, 1) if age is not None else None,
        "windows": windows,
        "bias": bias,
        "yorum": yorum,
        "recent": recent,
        "n_total": len(rows),
    }
