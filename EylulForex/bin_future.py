"""Binance USDT-M — FUTURE paneli. Emir yalnızca panelden manuel (otomatik/cron yok)."""
from __future__ import annotations

import sys
from pathlib import Path

_DIR = Path(__file__).resolve().parent
_ROOT = _DIR.parent
_KRIPTO = str(_ROOT / "AgustosKripto")
if str(_ROOT) not in sys.path:
    sys.path.insert(0, str(_ROOT))
if _KRIPTO not in sys.path:
    sys.path.insert(0, _KRIPTO)

from bin_indicator import load_symbol, spot as ind_spot  # noqa: E402
from binance_futures_client import (  # noqa: E402
    BinanceFuturesClient,
    BinanceFuturesError,
    qty_from_notional,
    round_step,
)


def _client() -> BinanceFuturesClient:
    return BinanceFuturesClient()


def _positions(symbol: str | None = None) -> list[dict]:
    c = _client()
    if not c.configured():
        return []
    rows = c.position_risk(symbol)
    out = []
    for r in rows:
        amt = float(r.get("positionAmt") or 0)
        if abs(amt) < 1e-12:
            continue
        out.append({
            "symbol": r.get("symbol"),
            "side": "LONG" if amt > 0 else "SHORT",
            "qty": abs(amt),
            "position_amt": amt,
            "entry_price": float(r.get("entryPrice") or 0),
            "mark_price": float(r.get("markPrice") or 0),
            "unrealized_pnl": float(r.get("unRealizedProfit") or 0),
            "leverage": int(float(r.get("leverage") or 0)),
            "margin_type": r.get("marginType"),
            "liquidation_price": float(r.get("liquidationPrice") or 0),
            "notional": abs(float(r.get("notional") or 0)),
        })
    return out


def _wallet() -> dict:
    ws = {}
    try:
        from binance_um_wallet import fetch
        hit = fetch() or {}
        if hit.get("wallet") is not None:
            ws = {
                "wallet": float(hit.get("wallet") or 0),
                "available": float(hit.get("available") or 0),
                "unrealized": float(hit.get("unrealized") or 0),
                "equity": float(hit.get("equity") or hit.get("wallet") or 0),
                "src": "ws",
            }
    except Exception:
        pass

    rest_err = None
    rest = None
    c = _client()
    if c.configured():
        try:
            rows = c.get("/fapi/v2/balance", signed=True, ignore_ban=True)
            usdt = next((x for x in rows if x.get("asset") == "USDT"), None)
            if usdt:
                rest = {
                    "wallet": float(usdt.get("balance") or 0),
                    "available": float(usdt.get("availableBalance") or 0),
                    "unrealized": float(usdt.get("crossUnPnl") or 0),
                    "equity": float(usdt.get("balance") or 0) + float(usdt.get("crossUnPnl") or 0),
                    "src": "rest",
                }
        except BinanceFuturesError as e:
            rest_err = str(e)[:240]
        except Exception as e:
            rest_err = str(e)[:240]

    use = rest or ws
    return {
        "wallet": use.get("wallet"),
        "available": use.get("available"),
        "unrealized": use.get("unrealized"),
        "equity": use.get("equity"),
        "src": use.get("src") or "none",
        "rest_error": rest_err,
        "ws_ok": bool(ws),
    }


def _prepare(symbol: str, leverage: int, margin_type: str = "ISOLATED") -> dict:
    from binance_fapi_guard import filters_for
    c = _client()
    filt = filters_for(symbol)
    resp = {"symbol": symbol.upper(), "leverage": int(leverage), "margin_type": margin_type.upper(), "filters": filt}
    resp["leverage_resp"] = c.set_leverage(symbol, leverage)
    try:
        resp["margin_resp"] = c.set_margin_type(symbol, margin_type)
    except BinanceFuturesError as e:
        body = e.body if isinstance(e.body, dict) else {}
        if body.get("code") in (-4046, 4046) or "No need to change" in str(e):
            resp["margin_resp"] = {"skipped": True}
        else:
            raise
    return resp


def status(symbol: str | None = None) -> dict:
    sym = (symbol or load_symbol()).upper()
    c = _client()
    q = ind_spot("1m")
    pos = [p for p in _positions(sym) if (p.get("symbol") or "").upper() == sym]
    return {
        "ok": True,
        "manual_only": True,
        "testnet": c.testnet,
        "configured": c.configured(),
        "symbol": sym,
        "mark": q.get("mark"),
        "bid": q.get("bid"),
        "ask": q.get("ask"),
        "wallet": _wallet(),
        "position": pos[0] if pos else None,
        "positions_all": _positions(),
    }


def open_position(
    symbol: str,
    side: str,
    *,
    margin_usd: float,
    leverage: int = 5,
    stop_loss: float | None = None,
    margin_type: str = "ISOLATED",
) -> dict:
    """Manuel emir — yalnızca panel POST ile çağrılır."""
    sym = symbol.upper()
    side_u = side.upper()
    if side_u in ("LONG", "BUY"):
        order_side = "BUY"
        pos_side = "LONG"
        stop_side = "SELL"
    elif side_u in ("SHORT", "SELL"):
        order_side = "SELL"
        pos_side = "SHORT"
        stop_side = "BUY"
    else:
        raise ValueError("side LONG veya SHORT olmalı")

    margin = float(margin_usd)
    lev = int(leverage)
    if margin <= 0:
        raise ValueError("margin_usd > 0 olmalı")
    if lev < 1 or lev > 125:
        raise ValueError("leverage 1–125 olmalı")

    c = _client()
    if not c.configured():
        raise BinanceFuturesError("BINANCE_FUTURES_API_KEY eksik")

    prep = _prepare(sym, lev, margin_type)
    filt = prep["filters"]
    mark = float(c.mark_price(sym))
    qty = qty_from_notional(
        margin,
        mark,
        leverage=lev,
        step_size=float(filt.get("step_size") or 0.001),
        min_qty=float(filt.get("min_qty") or 0.001),
        min_notional=float(filt.get("min_notional") or 5.0),
    )
    if qty <= 0:
        raise ValueError("lot hesaplanamadı — margin veya min notional yetersiz")

    order = c.new_order(symbol=sym, side=order_side, type="MARKET", quantity=qty)
    entry = float(order.get("avgPrice") or mark or 0)
    stop_order = None
    if stop_loss is not None and float(stop_loss) > 0:
        tick = float(filt.get("tick_size") or 0.0001)
        stop_px = round_step(float(stop_loss), tick)
        if pos_side == "LONG" and stop_px >= entry:
            raise ValueError("LONG stop-loss girişin altında olmalı")
        if pos_side == "SHORT" and stop_px <= entry:
            raise ValueError("SHORT stop-loss girişin üstünde olmalı")
        stop_order = c.new_order(
            symbol=sym,
            side=stop_side,
            type="STOP_MARKET",
            stopPrice=stop_px,
            closePosition="true",
            workingType="MARK_PRICE",
        )

    return {
        "ok": True,
        "symbol": sym,
        "side": pos_side,
        "qty": qty,
        "leverage": lev,
        "margin_usd": margin,
        "entry_price": entry,
        "mark": mark,
        "order": order,
        "stop_order": stop_order,
        "testnet": c.testnet,
    }


def close_position(symbol: str) -> dict:
    """Manuel kapanış — yalnızca panel POST ile çağrılır."""
    sym = symbol.upper()
    c = _client()
    if not c.configured():
        raise BinanceFuturesError("API key yok")
    pos = _positions(sym)
    if not pos:
        raise ValueError(f"{sym} açık pozisyon yok")
    p = pos[0]
    amt = float(p.get("position_amt") or 0)
    qty = abs(amt)
    side = "SELL" if amt > 0 else "BUY"
    from binance_fapi_guard import filters_for
    filt = filters_for(sym)
    qty = round_step(qty, float(filt.get("step_size") or 0.001))
    order = c.new_order(
        symbol=sym,
        side=side,
        type="MARKET",
        quantity=qty,
        reduceOnly="true",
    )
    return {"ok": True, "symbol": sym, "order": order, "closed_side": p.get("side")}
