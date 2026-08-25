"""GPSUSDT + BIN_XAUUSDT — borsa emri yok, Isolated MARKET gibi sanal kasa.

Fiyat / mark / derinlik Binance'ten gelir. `new_order` gitmez.
İki sayfa aynı $500 kasayı görür.
"""
from __future__ import annotations

import json
from datetime import datetime
from pathlib import Path
from zoneinfo import ZoneInfo

_DIR = Path(__file__).resolve().parent / "data"
_FILE = _DIR / "binance_virtual_live.json"
_TZ = ZoneInfo("Europe/Istanbul")
INIT = 500.0


def _empty() -> dict:
    return {
        "enabled": True,
        "init": INIT,
        "cash": INIT,
        "locked": {"gps": 0.0, "bin": 0.0},
        "updated_at_tr": "",
    }


def load() -> dict:
    try:
        d = json.loads(_FILE.read_text(encoding="utf-8"))
        if isinstance(d, dict) and d.get("enabled") is not False:
            d.setdefault("init", INIT)
            d.setdefault("cash", INIT)
            d.setdefault("locked", {"gps": 0.0, "bin": 0.0})
            return d
        if isinstance(d, dict):
            return d
    except (OSError, json.JSONDecodeError, TypeError):
        pass
    return _empty()


def save(data: dict) -> dict:
    _DIR.mkdir(parents=True, exist_ok=True)
    data["updated_at_tr"] = datetime.now(_TZ).isoformat(timespec="seconds")
    tmp = _FILE.with_suffix(".json.tmp")
    tmp.write_text(json.dumps(data, ensure_ascii=False, indent=2), encoding="utf-8")
    tmp.replace(_FILE)
    return data


def enabled(book: str | None = None) -> bool:
    """GPS: `gpsusdt_live_control.virtual_live`. BIN / boş: ortak sanal dosya."""
    if book == "gps":
        try:
            ctrl = json.loads((_DIR / "gpsusdt_live_control.json").read_text(encoding="utf-8"))
            return bool(ctrl.get("virtual_live"))
        except (OSError, json.JSONDecodeError, TypeError):
            return False
    return bool(load().get("enabled", True))


def enable(cash: float = INIT) -> dict:
    d = load()
    d["enabled"] = True
    d["init"] = float(cash)
    d["cash"] = float(cash)
    d["locked"] = {"gps": 0.0, "bin": 0.0}
    return save(d)


def account() -> dict:
    d = load()
    cash = float(d.get("cash") or 0)
    locked = d.get("locked") or {}
    used = float(locked.get("gps") or 0) + float(locked.get("bin") or 0)
    return {
        "wallet": round(cash, 4),
        "available": round(cash - used, 4),
        "unrealized": 0.0,
        "equity": round(cash, 4),
        "init": float(d.get("init") or INIT),
        "virtual": True,
    }


def available() -> float:
    return float(account()["available"])


def apply_open(book: str, fee: float, margin: float) -> None:
    d = load()
    key = "gps" if book == "gps" else "bin"
    d["cash"] = round(float(d.get("cash") or 0) - float(fee or 0), 6)
    locked = d.setdefault("locked", {"gps": 0.0, "bin": 0.0})
    locked[key] = float(margin or 0)
    save(d)


def simulate_fill(market_fill, side: str, qty: float, fallback_px: float, taker: float) -> dict:
    """Binance MARKET merdiveni; derinlik boşsa hint fiyat."""
    side_l = "buy" if str(side).lower() in ("buy", "long") else "sell"
    try:
        fill = market_fill(side_l, float(qty))
    except Exception as e:
        fill = {"ok": False, "error": str(e)[:80]}
    px = float((fill or {}).get("price") or 0) or float(fallback_px or 0)
    q = float((fill or {}).get("qty") or qty or 0)
    if px <= 0 or q <= 0:
        return {"ok": False, "error": (fill or {}).get("error") or "virtual_empty"}
    notional = round(q * px, 8)
    fee = round(abs(notional) * float(taker or 0.0005), 6)
    return {
        "ok": True,
        "side": side_l,
        "qty": q,
        "price": px,
        "notional": notional,
        "levels": (fill or {}).get("levels"),
        "taker": True,
        "type": "MARKET",
        "order_id": None,
        "status": "FILLED",
        "fee": fee,
        "fee_src": "virtual_taker",
        "virtual": True,
    }


def apply_close(book: str, gross: float, fee_close: float) -> None:
    d = load()
    key = "gps" if book == "gps" else "bin"
    d["cash"] = round(float(d.get("cash") or 0) + float(gross or 0) - float(fee_close or 0), 6)
    locked = d.setdefault("locked", {"gps": 0.0, "bin": 0.0})
    locked[key] = 0.0
    save(d)
