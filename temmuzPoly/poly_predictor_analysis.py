"""CoptC ince kopya — yalnız b1_mum_signal._fetch_klines."""
from __future__ import annotations

import sys
from pathlib import Path


async def _fetch_klines(symbol: str, tf: str = "1h", limit: int = 72) -> list[dict]:
    root = str(Path(__file__).resolve().parents[1])
    if root not in sys.path:
        sys.path.insert(0, root)
    from binance_fapi_guard import public_klines
    data = public_klines(symbol, tf, limit)
    if not isinstance(data, list):
        return []
    return [
        {
            "open": float(k[1]),
            "high": float(k[2]),
            "low": float(k[3]),
            "close": float(k[4]),
            "volume": float(k[5]),
        }
        for k in data
    ]
