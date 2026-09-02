"""BIN_XAUUSDT — seçilen sanal defterin (Aktif et) salt okunur aynası.

Aç/kapa kararı `fx_algo_{uid}_state.json` açık satırından gelir.
`signal_for_book` yalnız durum/önizleme içindir; BIN kendi sinyalini koşturmaz.
GPSUSDT / CEM01 / fx_algo defterlerine yazmaz.
"""
from __future__ import annotations

import json
import os
import sys
from pathlib import Path

_DIR = os.path.dirname(os.path.abspath(__file__))
if _DIR not in sys.path:
    sys.path.insert(0, _DIR)

from fx_algo_catalog import get_book  # noqa: E402
from fx_algo_signals import signal_for_book  # noqa: E402

DEFAULT_UID = "d104"


def _control() -> dict:
    try:
        from bin_b103_binance import load_control
        c = load_control()
        return c if isinstance(c, dict) else {}
    except Exception:
        return {}


def current_uid() -> str:
    uid = str(_control().get("engine_uid") or DEFAULT_UID).strip().lower()
    return uid if get_book(uid) else DEFAULT_UID


def current_book() -> dict:
    return get_book(current_uid()) or get_book(DEFAULT_UID) or {
        "uid": DEFAULT_UID, "name": "D104", "title": "D104 · Akış vekili",
    }


def engine_info() -> dict:
    b = current_book()
    return {
        "uid": b.get("uid") or DEFAULT_UID,
        "name": b.get("name") or b.get("uid"),
        "title": b.get("title") or b.get("name") or "",
    }


def engine_paper_pos_for(uid: str) -> dict | None:
    """Verilen fx_algo sanal defterin açık satırı — yazmaz."""
    key = str(uid or "").strip().lower()
    if not key or not get_book(key):
        return None
    path = Path(_DIR) / "data" / f"fx_algo_{key}_state.json"
    if not path.exists():
        return None
    try:
        st = json.loads(path.read_text(encoding="utf-8"))
    except (json.JSONDecodeError, OSError):
        return None
    if not isinstance(st, dict):
        return None
    rows = st.get("open_positions")
    if not isinstance(rows, list):
        rows = []
    if not rows and isinstance(st.get("position"), dict):
        rows = [st["position"]]
    if not rows and isinstance(st.get("positions"), list):
        rows = [p for p in st["positions"] if isinstance(p, dict)]
    row = rows[0] if rows else None
    if not isinstance(row, dict):
        return None
    out = dict(row)
    out.setdefault("uid", key)
    return out


def engine_info_for(uid: str) -> dict:
    b = get_book((uid or "").strip().lower()) or {}
    return {
        "uid": b.get("uid") or uid,
        "name": b.get("name") or b.get("uid") or uid,
        "title": b.get("title") or b.get("name") or "",
    }


def engine_paper_pos() -> dict | None:
    """Seçilen fx_algo sanal defterin açık satırı — yazmaz."""
    return engine_paper_pos_for(current_uid())


def engine_last_close(uid: str, src_id) -> dict | None:
    """Kaynak defterde kapanmış satır — Isolated birebir çıkış için."""
    key = str(uid or "").strip().lower()
    sid = str(src_id or "").strip()
    if not key or not sid:
        return None
    path = Path(_DIR) / "data" / f"fx_algo_{key}_history.json"
    if not path.exists():
        return None
    try:
        rows = json.loads(path.read_text(encoding="utf-8"))
    except (json.JSONDecodeError, OSError):
        return None
    if not isinstance(rows, list):
        return None
    for rec in reversed(rows):
        if isinstance(rec, dict) and str(rec.get("id") or "") == sid:
            return rec
    return None


def set_engine_uid(uid: str) -> dict:
    book = get_book((uid or "").strip().lower())
    if not book:
        return {"ok": False, "error": "unknown_book"}
    from bin_b103_binance import load_control, save_control
    c = load_control()
    prev = str(c.get("engine_uid") or DEFAULT_UID)
    c["engine_uid"] = book["uid"]
    save_control(c)
    return {
        "ok": True,
        "uid": book["uid"],
        "name": book.get("name"),
        "title": book.get("title"),
        "prev": prev,
        "changed": prev != book["uid"],
    }


def pick_tf(sig1: str, sig4: str) -> tuple[str, str]:
    if sig1 in ("UP", "DOWN"):
        return "1h", sig1
    if sig4 in ("UP", "DOWN"):
        return "4h", sig4
    return "1h", "NEUTRAL"


def resolve(kl1: list, kl4: list) -> dict:
    book = current_book()
    s1 = signal_for_book(book, kl1)
    s4 = signal_for_book(book, kl4)
    tf, sig = pick_tf(s1, s4)
    return {
        "direction": sig,
        "tf": tf,
        "sig_1h": s1,
        "sig_4h": s4,
        "engine": book.get("uid"),
        "name": book.get("name"),
        "title": book.get("title"),
        "is_stable": sig in ("UP", "DOWN"),
        "confidence": 1.0 if sig in ("UP", "DOWN") else 0.0,
    }


def side_of(sig: str) -> str | None:
    if sig == "UP":
        return "buy"
    if sig == "DOWN":
        return "sell"
    return None
