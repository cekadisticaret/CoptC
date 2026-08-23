"""BursaApp lider haritası — coin başına en iyi motorlar.

GET /kripto/api/lider  ·  X-Lider-Token
Sıra: win rate → PnL → işlem sayısı. CEBU açılışta 1. varsa onu, yoksa/sinyal
yoksa 2. yi kullanır.
"""
from __future__ import annotations

import json
import os
import time
import urllib.error
import urllib.request

_DIR = os.path.dirname(os.path.abspath(__file__))
_ROOT = os.path.abspath(os.path.join(_DIR, "..", ".."))
_CACHE_FILE = os.path.join(_DIR, "data", "lider_cache.json")
_TTL_SEC = 180
_META = frozenset({"cebu", "jarvis_v1"})
_DEFAULT_URL = "https://bursaapp.com/kripto/api/lider"

_mem: dict = {"at": 0.0, "payload": None}


def _read_dotenv() -> dict[str, str]:
    path = os.path.join(_ROOT, ".env")
    out: dict[str, str] = {}
    try:
        with open(path, encoding="utf-8") as f:
            for line in f:
                line = line.strip()
                if not line or line.startswith("#") or "=" not in line:
                    continue
                k, v = line.split("=", 1)
                out[k.strip()] = v.strip().strip("'").strip('"')
    except OSError:
        return out
    return out


def _cfg() -> tuple[str, str]:
    env = _read_dotenv()
    url = (os.getenv("LIDER_API_URL") or env.get("LIDER_API_URL") or _DEFAULT_URL).strip()
    token = (os.getenv("LIDER_API_TOKEN") or env.get("LIDER_API_TOKEN") or "").strip()
    return url, token


def _load_disk() -> dict | None:
    try:
        with open(_CACHE_FILE, encoding="utf-8") as f:
            data = json.load(f)
        if isinstance(data, dict) and data.get("coins"):
            return data
    except (OSError, json.JSONDecodeError):
        return None
    return None


def _save_disk(payload: dict) -> None:
    try:
        os.makedirs(os.path.dirname(_CACHE_FILE), exist_ok=True)
        with open(_CACHE_FILE, "w", encoding="utf-8") as f:
            json.dump(payload, f, ensure_ascii=False)
    except OSError:
        pass


def fetch(force: bool = False) -> dict:
    now = time.time()
    if not force and _mem["payload"] and (now - _mem["at"]) < _TTL_SEC:
        return _mem["payload"]
    url, token = _cfg()
    payload = None
    if url and token:
        req = urllib.request.Request(
            url,
            headers={"Accept": "application/json", "X-Lider-Token": token},
            method="GET",
        )
        try:
            with urllib.request.urlopen(req, timeout=8) as resp:
                raw = json.loads(resp.read().decode("utf-8"))
            if isinstance(raw, dict) and raw.get("coins"):
                payload = raw
        except (urllib.error.URLError, TimeoutError, json.JSONDecodeError, OSError) as exc:
            print(f"[LIDER] çekilemedi: {exc}")
    if payload is None:
        payload = _mem["payload"] or _load_disk() or {}
    else:
        _save_disk(payload)
    _mem["at"] = now
    _mem["payload"] = payload
    return payload or {}


def _base(sym: str) -> str:
    return (sym or "").upper().replace("USDT", "")


def ranked(symbol: str, available: set[str] | frozenset[str] | None = None) -> list[dict]:
    """WR sırası, yalnızca yerelde olan motorlar."""
    coins = (fetch().get("coins") or {})
    rows = coins.get(_base(symbol)) or []
    out = []
    for r in rows:
        if not isinstance(r, dict):
            continue
        uid = str(r.get("key") or "").strip()
        if not uid or uid in _META:
            continue
        if available is not None and uid not in available:
            continue
        out.append({
            "uid": uid,
            "label": r.get("label") or uid,
            "wr": float(r.get("wr") or 0),
            "pnl": float(r.get("pnl") or 0),
            "trades": int(r.get("trades") or 0),
            "api_rank": r.get("rank"),
        })
    out.sort(key=lambda x: (x["wr"], x["pnl"], x["trades"]), reverse=True)
    for i, row in enumerate(out, 1):
        row["pick_rank"] = i
    return out


def pick(symbol: str, available: set[str] | frozenset[str] | None = None) -> dict | None:
    """1. (en yüksek WR); yoksa 2."""
    rows = ranked(symbol, available)
    return rows[0] if rows else None


def pick_pair(symbol: str, available: set[str] | frozenset[str] | None = None) -> list[dict]:
    """Açılışta dene: 1. sonra 2."""
    return ranked(symbol, available)[:2]
