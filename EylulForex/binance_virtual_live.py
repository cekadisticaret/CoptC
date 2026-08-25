"""GPSUSDT + BIN_XAUUSDT — borsa emri yok, Isolated MARKET gibi sanal kasa.

Fiyat / mark / derinlik Binance'ten gelir. `new_order` gitmez.
Her sayfanın kendi $500 kasası var; birbirinden düşmez.
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
_BOOKS = ("gps", "bin")


def _book_empty() -> dict:
    return {"init": INIT, "cash": INIT, "locked": 0.0}


def _empty() -> dict:
    return {
        "enabled": True,
        "books": {k: _book_empty() for k in _BOOKS},
        "updated_at_tr": "",
    }


def _norm_book(book: str | None) -> str:
    return "gps" if str(book or "") == "gps" else "bin"


def _migrate(d: dict) -> dict:
    if isinstance(d.get("books"), dict) and d["books"]:
        books = {}
        for k in _BOOKS:
            row = d["books"].get(k) or {}
            books[k] = {
                "init": float(row.get("init") or INIT),
                "cash": float(row.get("cash") if row.get("cash") is not None else INIT),
                "locked": float(row.get("locked") or 0),
            }
        d["books"] = books
        d.setdefault("enabled", True)
        return d
    # Eski ortak kasa — ayır, her biri $500
    return _empty()


def load() -> dict:
    try:
        d = json.loads(_FILE.read_text(encoding="utf-8"))
        if isinstance(d, dict):
            return _migrate(d)
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
    """GPS: `gpsusdt_live_control.virtual_live`. BIN / boş: sanal dosya."""
    if book == "gps":
        try:
            ctrl = json.loads((_DIR / "gpsusdt_live_control.json").read_text(encoding="utf-8"))
            return bool(ctrl.get("virtual_live"))
        except (OSError, json.JSONDecodeError, TypeError):
            return False
    return bool(load().get("enabled", True))


def enable(cash: float = INIT, book: str | None = None) -> dict:
    d = load()
    d["enabled"] = True
    keys = [_norm_book(book)] if book else list(_BOOKS)
    for k in keys:
        d.setdefault("books", {})[k] = {"init": float(cash), "cash": float(cash), "locked": 0.0}
    return save(d)


def _slot(d: dict, book: str | None) -> dict:
    key = _norm_book(book)
    books = d.setdefault("books", {})
    if key not in books or not isinstance(books[key], dict):
        books[key] = _book_empty()
    row = books[key]
    row.setdefault("init", INIT)
    row.setdefault("cash", INIT)
    row.setdefault("locked", 0.0)
    return row


def account(book: str | None = None) -> dict:
    d = load()
    row = _slot(d, book)
    cash = float(row.get("cash") or 0)
    used = float(row.get("locked") or 0)
    return {
        "wallet": round(cash, 4),
        "available": round(cash - used, 4),
        "unrealized": 0.0,
        "equity": round(cash, 4),
        "init": float(row.get("init") or INIT),
        "book": _norm_book(book),
        "virtual": True,
    }


def available(book: str | None = None) -> float:
    return float(account(book)["available"])


def apply_open(book: str, fee: float, margin: float) -> None:
    d = load()
    row = _slot(d, book)
    row["cash"] = round(float(row.get("cash") or 0) - float(fee or 0), 6)
    row["locked"] = float(margin or 0)
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
    row = _slot(d, book)
    row["cash"] = round(float(row.get("cash") or 0) + float(gross or 0) - float(fee_close or 0), 6)
    row["locked"] = 0.0
    save(d)
