"""Gate.io USDT-M — XAU_USDT public fiyat + imzalı emir (anahtar varsa).

CEM01 kâğıdına / CEMAPI'ye dokunmaz. Canlı emir yalnız GATE_API_KEY +
GATE_API_SECRET ve GATE_LIVE=1 iken.
"""
from __future__ import annotations

import hashlib
import hmac
import json
import os
import time
import urllib.error
import urllib.parse
import urllib.request
from pathlib import Path

CONTRACT = "XAU_USDT"
_HOST = "https://api.gateio.ws"
_PREFIX = "/api/v4"
_UA = {"User-Agent": "coptc-gate-g1/1.0", "Accept": "application/json"}
_TICK_TTL = 2.0
_CONTRACT_TTL = 3600.0
_tick_cache: tuple[float, dict] | None = None
_contract_cache: tuple[float, dict] | None = None

# Kullanıcı VIP0 taker %0.05. Sözleşme listesi 0.075 gösterebilir; kural %0.05.
TAKER_RATE = 0.0005
QUANTO_FALLBACK = 0.0001
_ROOT = Path(__file__).resolve().parent.parent
_ENV = _ROOT / ".env"


def _load_env() -> None:
    try:
        if not _ENV.exists():
            return
        text = _ENV.read_text(encoding="utf-8")
    except OSError:
        return
    for line in text.splitlines():
        line = line.strip()
        if not line or line.startswith("#") or "=" not in line:
            continue
        k, _, v = line.partition("=")
        os.environ.setdefault(k.strip(), v.strip().strip('"').strip("'"))


_load_env()


def _key() -> str:
    return (os.environ.get("GATE_API_KEY") or "").strip()


def _secret() -> str:
    return (os.environ.get("GATE_API_SECRET") or "").strip()


def configured() -> bool:
    return bool(_key() and _secret())


def live_allowed() -> bool:
    flag = (os.environ.get("GATE_LIVE") or "").strip().lower()
    return configured() and flag in ("1", "true", "yes", "on")


def _get(path: str, params: dict | None = None, timeout: float = 10.0) -> dict | list:
    qs = urllib.parse.urlencode(params or {})
    url = f"{_HOST}{_PREFIX}{path}"
    if qs:
        url += "?" + qs
    req = urllib.request.Request(url, headers=_UA)
    with urllib.request.urlopen(req, timeout=timeout) as r:
        return json.load(r)


def ticker() -> dict:
    global _tick_cache
    now = time.time()
    if _tick_cache and now - _tick_cache[0] < _TICK_TTL:
        return dict(_tick_cache[1])
    raw = _get("/futures/usdt/tickers", {"contract": CONTRACT})
    row = raw[0] if isinstance(raw, list) and raw else (raw if isinstance(raw, dict) else {})
    last = float(row.get("last") or 0)
    mark = float(row.get("mark_price") or last)
    bid = float(row.get("highest_bid") or last)
    ask = float(row.get("lowest_ask") or last)
    if bid <= 0:
        bid = last
    if ask <= 0:
        ask = last
    if bid > ask > 0:
        bid, ask = ask, bid
    out = {
        "contract": CONTRACT,
        "last": last,
        "mark": mark,
        "bid": bid,
        "ask": ask,
        "mid": round((bid + ask) / 2, 2) if bid and ask else last,
        "index": float(row.get("index_price") or 0) or None,
    }
    _tick_cache = (now, out)
    return dict(out)


def contract_info() -> dict:
    global _contract_cache
    now = time.time()
    if _contract_cache and now - _contract_cache[0] < _CONTRACT_TTL:
        return dict(_contract_cache[1])
    row = _get(f"/futures/usdt/contracts/{CONTRACT}")
    if not isinstance(row, dict):
        row = {}
    out = {
        "quanto": float(row.get("quanto_multiplier") or QUANTO_FALLBACK),
        "taker": float(row.get("taker_fee_rate") or TAKER_RATE),
        "leverage_max": float(row.get("leverage_max") or 50),
        "order_size_min": int(float(row.get("order_size_min") or 1)),
        "mark": float(row.get("mark_price") or 0) or None,
        "last": float(row.get("last_price") or 0) or None,
    }
    _contract_cache = (now, out)
    return dict(out)


def quanto() -> float:
    try:
        return float(contract_info()["quanto"])
    except Exception:
        return QUANTO_FALLBACK


def contracts_for_notional(notional: float, price: float) -> int:
    q = quanto()
    oz = float(notional) / float(price)
    n = int(round(oz / q))
    return max(int(contract_info().get("order_size_min") or 1), n)


def oz_of(contracts: int, q: float | None = None) -> float:
    return float(contracts) * float(q if q is not None else quanto())


def klines(interval: str = "1m", limit: int = 240) -> list[dict]:
    allowed = {"1m", "5m", "15m", "30m", "1h", "4h", "1d"}
    iv = interval if interval in allowed else "1m"
    n = max(20, min(500, int(limit)))
    raw = _get(
        "/futures/usdt/candlesticks",
        {"contract": CONTRACT, "interval": iv, "limit": n},
    )
    out = []
    for c in raw if isinstance(raw, list) else []:
        try:
            out.append({
                "time": int(c["t"]),
                "open": float(c["o"]),
                "high": float(c["h"]),
                "low": float(c["l"]),
                "close": float(c["c"]),
                "volume": float(c.get("v") or 0),
            })
        except (KeyError, TypeError, ValueError):
            continue
    return out


def _sign(method: str, url: str, query: str, body: str) -> dict:
    t = str(int(time.time()))
    hashed = hashlib.sha512((body or "").encode("utf-8")).hexdigest()
    msg = f"{method}\n{url}\n{query or ''}\n{hashed}\n{t}"
    sign = hmac.new(_secret().encode("utf-8"), msg.encode("utf-8"), hashlib.sha512).hexdigest()
    return {"KEY": _key(), "Timestamp": t, "SIGN": sign}


def _signed(method: str, path: str, params: dict | None = None, body: dict | None = None) -> dict | list:
    if not configured():
        raise RuntimeError("gate_keys_missing")
    qs = urllib.parse.urlencode(params or {})
    payload = json.dumps(body, separators=(",", ":")) if body is not None else ""
    url_path = _PREFIX + path
    headers = {
        **_UA,
        "Content-Type": "application/json",
        **_sign(method, url_path, qs, payload),
    }
    url = _HOST + url_path
    if qs:
        url += "?" + qs
    data = payload.encode("utf-8") if payload else None
    req = urllib.request.Request(url, data=data, headers=headers, method=method)
    try:
        with urllib.request.urlopen(req, timeout=12) as r:
            raw = r.read()
            return json.loads(raw) if raw else {}
    except urllib.error.HTTPError as e:
        err = e.read().decode("utf-8", "replace")[:240]
        raise RuntimeError(f"gate {e.code}: {err}") from None


def set_leverage(leverage: int = 30) -> dict:
    return _signed(
        "POST",
        f"/futures/usdt/positions/{CONTRACT}/leverage",
        {"leverage": str(int(leverage))},
    )


def place_market(side: str, contracts: int) -> dict:
    if not live_allowed():
        raise RuntimeError("gate_live_off")
    size = abs(int(contracts))
    if side == "sell":
        size = -size
    set_leverage(30)
    return _signed(
        "POST",
        "/futures/usdt/orders",
        body={"contract": CONTRACT, "size": size, "price": "0", "tif": "ioc"},
    )


def close_position() -> dict:
    if not live_allowed():
        raise RuntimeError("gate_live_off")
    return _signed(
        "POST",
        f"/futures/usdt/positions/{CONTRACT}/close",
        body={"contract": CONTRACT},
    )


def live_position() -> dict | None:
    if not configured():
        return None
    row = _signed("GET", f"/futures/usdt/positions/{CONTRACT}")
    if not isinstance(row, dict):
        return None
    size = int(float(row.get("size") or 0))
    if size == 0:
        return None
    return {
        "side": "buy" if size > 0 else "sell",
        "contracts": abs(size),
        "entry": float(row.get("entry_price") or 0),
        "mark": float(row.get("mark_price") or 0) or None,
        "unreal": float(row.get("unrealised_pnl") or 0),
    }
