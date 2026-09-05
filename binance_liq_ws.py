#!/usr/bin/env python3
"""Binance USD-M piyasa likidasyonları — !forceOrder@arr websocket.

  python3 binance_liq_ws.py          # daemon
  python3 binance_liq_ws.py status   # özet

SELL force order → long likidasyon
BUY force order  → short likidasyon
"""
from __future__ import annotations

import asyncio
import fcntl
import json
import os
import sys
import time
from pathlib import Path

import websockets

_ROOT = Path(__file__).resolve().parent
if str(_ROOT) not in sys.path:
    sys.path.insert(0, str(_ROOT))

LIQ_CACHE_FILE = Path("/tmp/binance_liq_cache.json")
LIQ_LOCK_FILE = Path("/tmp/binance_liq_ws.lock")
WS_URL = "wss://fstream.binance.com/market/stream?streams=!forceOrder@arr"
_MAX_PER_SYM = 180
_MAX_AGE_SEC = 6 * 3600
_WRITE_GAP = 0.6

_events: dict[str, list[dict]] = {}
_dirty = False
_last_write = 0.0
_lock_fd: int | None = None


def _try_lock() -> int | None:
    LIQ_LOCK_FILE.parent.mkdir(parents=True, exist_ok=True)
    fd = os.open(str(LIQ_LOCK_FILE), os.O_CREAT | os.O_RDWR, 0o644)
    try:
        fcntl.flock(fd, fcntl.LOCK_EX | fcntl.LOCK_NB)
    except BlockingIOError:
        os.close(fd)
        return None
    try:
        os.ftruncate(fd, 0)
        os.write(fd, f"{os.getpid()}\n".encode())
    except OSError:
        pass
    return fd


def _usd(o: dict) -> float:
    try:
        ap = float(o.get("ap") or o.get("p") or 0)
        z = float(o.get("z") or o.get("q") or 0)
        return ap * z if ap > 0 and z > 0 else 0.0
    except (TypeError, ValueError):
        return 0.0


def _ingest(msg: dict) -> None:
    global _dirty
    if not isinstance(msg, dict):
        return
    if msg.get("e") != "forceOrder":
        return
    o = msg.get("o") or {}
    sym = str(o.get("s") or "").upper()
    if not sym:
        return
    side_raw = str(o.get("S") or "").upper()
    # SELL liq = long pozisyon kapandı; BUY liq = short kapandı
    liq_side = "long" if side_raw == "SELL" else "short" if side_raw == "BUY" else ""
    if not liq_side:
        return
    ts = int(o.get("T") or msg.get("E") or int(time.time() * 1000))
    try:
        price = float(o.get("ap") or o.get("p") or 0)
    except (TypeError, ValueError):
        price = 0.0
    usd = _usd(o)
    if usd <= 0 and price > 0:
        try:
            usd = price * float(o.get("z") or o.get("q") or 0)
        except (TypeError, ValueError):
            usd = 0.0
    if usd <= 0:
        return
    row = {
        "ts": ts,
        "side": liq_side,
        "price": round(price, 8),
        "usd": round(usd, 2),
    }
    bag = _events.setdefault(sym, [])
    bag.append(row)
    cutoff = int(time.time() * 1000) - _MAX_AGE_SEC * 1000
    bag = [x for x in bag if int(x.get("ts") or 0) >= cutoff]
    if len(bag) > _MAX_PER_SYM:
        bag = bag[-_MAX_PER_SYM:]
    _events[sym] = bag
    _dirty = True


def _flush(*, force: bool = False) -> None:
    global _last_write, _dirty
    now = time.time()
    if not force and (not _dirty or now - _last_write < _WRITE_GAP):
        return
    payload = {
        "updated_at": now,
        "src": "fstream_forceOrder",
        "symbols": len(_events),
        "events": _events,
    }
    tmp = Path(str(LIQ_CACHE_FILE) + ".tmp")
    tmp.write_text(json.dumps(payload, separators=(",", ":")), encoding="utf-8")
    tmp.replace(LIQ_CACHE_FILE)
    _last_write = now
    _dirty = False


async def _run() -> None:
    global _dirty
    while True:
        try:
            async with websockets.connect(
                WS_URL,
                ping_interval=20,
                ping_timeout=20,
                close_timeout=5,
                max_size=2**22,
            ) as ws:
                print(f"[liq-ws] bağlandı {WS_URL}", flush=True)
                _dirty = True
                _flush(force=True)
                last_hb = time.time()
                async for raw in ws:
                    try:
                        msg = json.loads(raw)
                    except json.JSONDecodeError:
                        continue
                    data = msg.get("data") if isinstance(msg, dict) and "data" in msg else msg
                    if isinstance(data, dict):
                        _ingest(data)
                    _flush()
                    if time.time() - last_hb > 25:
                        _dirty = True
                        _flush(force=True)
                        last_hb = time.time()
        except asyncio.CancelledError:
            raise
        except Exception as exc:
            print(f"[liq-ws] hata: {exc}", flush=True)
            _flush(force=True)
            await asyncio.sleep(3)


def status() -> dict:
    try:
        if LIQ_CACHE_FILE.exists():
            d = json.loads(LIQ_CACHE_FILE.read_text(encoding="utf-8"))
            age = time.time() - float(d.get("updated_at") or 0)
            n = sum(len(v) for v in (d.get("events") or {}).values())
            return {"ok": True, "age_sec": round(age, 1), "events": n, "symbols": d.get("symbols")}
    except Exception as exc:
        return {"ok": False, "error": str(exc)}
    return {"ok": False, "error": "cache yok"}


def main() -> int:
    if len(sys.argv) > 1 and sys.argv[1] == "status":
        print(json.dumps(status(), ensure_ascii=False, indent=2))
        return 0
    global _lock_fd
    _lock_fd = _try_lock()
    if _lock_fd is None:
        print("[liq-ws] başka süreç çalışıyor", flush=True)
        return 1
    try:
        asyncio.run(_run())
    except KeyboardInterrupt:
        _flush(force=True)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
