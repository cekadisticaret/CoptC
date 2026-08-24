"""GATE ekranı — mum/sinyal/seviye CEM01 ile aynı (Yahoo+PAXG).

Gate kotasyonu yalnız defter dolumu ve canlı emir için. Grafik g1'den.
"""
from __future__ import annotations

from gate_book import snapshot


def _gate_ticker() -> dict:
    try:
        from gate_api import ticker
        return ticker()
    except Exception:
        return {}


def forex_quote() -> dict:
    """Ekran fiyatı = CEM01. Gate mid ayrı alanda."""
    from forex_data import forex_quote as g1_quote
    q = g1_quote()
    g = _gate_ticker()
    q["symbol"] = "XAUUSD"
    q["gate"] = {
        "bid": g.get("bid"),
        "ask": g.get("ask"),
        "mid": g.get("mid") or g.get("last"),
        "last": g.get("last"),
        "contract": g.get("contract"),
    }
    q["src"] = q.get("src") or "paxg"
    return q


def _attach_book(q: dict) -> dict:
    g = q.get("gate") or _gate_ticker()
    gb, ga = g.get("bid"), g.get("ask")
    if gb is None or ga is None:
        gb, ga = q.get("bid"), q.get("ask")
    q["book"] = snapshot(
        gb, ga,
        display_bid=q.get("bid"),
        display_ask=q.get("ask"),
    )
    return q


def forex_spot(timeframe: str = "1m") -> dict:
    from forex_data import (
        BOOK_LEVEL_TF,
        BOOK_SIGNAL_TF,
        bar_remaining,
        forex_quote as g1_quote,
        forex_rail,
        get_xau_klines,
        paxg_tick_score,
        _BAR_SEC,
    )
    tf = (timeframe or "1m").lower()
    q = g1_quote()
    g = _gate_ticker()
    q["gate"] = {
        "bid": g.get("bid"),
        "ask": g.get("ask"),
        "mid": g.get("mid") or g.get("last"),
        "last": g.get("last"),
        "contract": g.get("contract"),
    }
    q["timeframe"] = tf
    q["bar_sec"] = _BAR_SEC.get(tf) or 60
    q["bar_left"] = bar_remaining(tf) if tf in _BAR_SEC else 60
    try:
        q["rail"] = forex_rail()
    except Exception:
        q["rail"] = {}
    try:
        q["tick"] = paxg_tick_score()
    except Exception:
        q["tick"] = {"score": 0.0, "n": 0}
    q["signal_tf"] = BOOK_SIGNAL_TF
    q["level_tf"] = BOOK_LEVEL_TF
    try:
        from forex_signal import live_signal
        q["signal"] = live_signal(BOOK_SIGNAL_TF)
    except Exception as e:
        q["signal"] = {
            "direction": "NEUTRAL", "confidence": 0.0, "is_stable": False,
            "error": str(e)[:160],
        }
    try:
        from forex_signal import sr_levels
        rows, _ = get_xau_klines(BOOK_LEVEL_TF, 120)
        levels = sr_levels(rows)
    except Exception:
        levels = {}
    q["book_levels"] = {
        "support": (levels or {}).get("nearest_support"),
        "resistance": (levels or {}).get("nearest_resistance"),
        "tf": BOOK_LEVEL_TF,
    }
    return _attach_book(q)


def forex_chart(timeframe: str = "1m", limit: int | None = None, plain: bool = False) -> dict:
    from forex_data import forex_chart as g1_chart
    out = g1_chart(timeframe, limit=limit, plain=plain, algo="g1")
    out["algo"] = "gate"
    g = _gate_ticker()
    out["gate"] = {
        "bid": g.get("bid"),
        "ask": g.get("ask"),
        "mid": g.get("mid") or g.get("last"),
        "last": g.get("last"),
    }
    return out
