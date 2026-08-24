"""CEM01 (g1) → Gate.io XAU_USDT ayna.

$100 × 30x, taker %0.05/taraf (~$3/tur). Beklenen kâr < $9 ise açılmaz.
SL/TP g1 mesafesiyle Gate girişine kaydırılır (PAXG vs Gate $ farkı mutlak kopyalanmaz).
"""
from __future__ import annotations

from datetime import datetime
from zoneinfo import ZoneInfo

from gate_book import (
    MIN_REWARD_USD,
    amend_from_src,
    expected_gross,
    open_paper,
    snapshot,
    with_lock,
    _close,
    _plist,
)
from gate_api import live_allowed, live_position, place_market, close_position

_TZ = ZoneInfo("Europe/Istanbul")
MAX_CHASE_SEC = 12


def _now() -> str:
    return datetime.now(_TZ).strftime("%Y.%m.%d %H:%M:%S")


def _side(pos: dict | None) -> str:
    return str((pos or {}).get("side") or "")


def _g1_book() -> dict:
    from forex_book import snapshot as g1_snap
    from forex_data import forex_quote
    q = forex_quote()
    return g1_snap(q.get("bid"), q.get("ask"), book="g1")


def _age_sec(pos: dict | None) -> float | None:
    raw = (pos or {}).get("open_time") or (pos or {}).get("entry_time_tr")
    if not raw:
        return None
    s = str(raw).strip()
    for fmt in ("%Y.%m.%d %H:%M:%S", "%Y-%m-%d %H:%M:%S"):
        try:
            dt = datetime.strptime(s[:19], fmt).replace(tzinfo=_TZ)
            return max(0.0, (datetime.now(_TZ) - dt).total_seconds())
        except ValueError:
            continue
    return None


def _reject(st: dict, side: str, reason: str, **extra) -> None:
    row = {"side": side, "reason": reason, "at": _now()}
    row.update(extra)
    st["last_reject"] = row


def tick() -> dict:
    from gate_api import ticker

    q = ticker()
    bid, ask = q.get("bid"), q.get("ask")
    mid = q.get("mid") or q.get("last")
    if not bid or not ask or not mid:
        return {"ok": False, "error": "gate_ticker"}

    g1 = _g1_book()
    want_pos = {
        _side(p): p
        for p in (g1.get("positions") or [])
        if _side(p) in ("buy", "sell")
    }
    want = list(want_pos)

    def _run(st, hist):
        closed = []
        opened = []
        skipped = []
        amended = []

        live = _plist(st)
        live_by = {}
        for p in live:
            s = _side(p)
            if s:
                live_by.setdefault(s, []).append(p)

        for side, rows in list(live_by.items()):
            if side in want_pos:
                continue
            for pos in rows:
                if live_allowed() and pos.get("live"):
                    try:
                        close_position()
                    except Exception as e:
                        _reject(st, side, "live_close_fail", detail=str(e)[:120])
                        return {
                            "ok": False,
                            "error": f"close {e}"[:200],
                            "closed": closed,
                            "opened": opened,
                            "skipped": skipped,
                            "amended": amended,
                        }
                closed.append(_close(st, hist, pos, bid, ask, "g1_flat"))

        live = _plist(st)
        live_by = {}
        for p in live:
            s = _side(p)
            if s:
                live_by.setdefault(s, []).append(p)

        for side, src in want_pos.items():
            rows = live_by.get(side) or []
            if rows:
                for pos in rows:
                    if amend_from_src(pos, src):
                        amended.append({"id": pos.get("id"), "side": side})
                continue

            src_id = src.get("id")
            if src_id and src_id == st.get("last_src_id"):
                skipped.append({"side": side, "reason": "already_done", "src_id": src_id})
                continue

            exp = expected_gross(src, mid)
            if exp is None or exp < MIN_REWARD_USD:
                _reject(
                    st, side, "reward_low",
                    expected_usd=exp,
                    min_usd=MIN_REWARD_USD,
                    detail=f"beklenen ${exp if exp is not None else '—'} < ${MIN_REWARD_USD:.0f}",
                )
                skipped.append({
                    "side": side,
                    "reason": "reward_low",
                    "expected_usd": exp,
                    "src_id": src_id,
                })
                continue

            age = _age_sec(src)
            if age is not None and age > MAX_CHASE_SEC:
                _reject(st, side, "chase", wait=round(age, 1), expected_usd=exp)
                skipped.append({"side": side, "age": round(age, 1), "src_id": src_id})
                continue

            if live_allowed():
                try:
                    from gate_book import NOTIONAL
                    from gate_api import contracts_for_notional
                    n = contracts_for_notional(NOTIONAL, mid)
                    place_market(side, n)
                    lp = live_position()
                    pos = open_paper(st, side, bid, ask, src, exp)
                    if lp:
                        pos["entry"] = round(float(lp["entry"] or pos["entry"]), 2)
                        pos["live"] = True
                        pos["fill_src"] = "gate_usdm_live"
                        pos["contracts"] = lp.get("contracts") or pos.get("contracts")
                    opened.append(pos)
                except Exception as e:
                    _reject(st, side, "emir", detail=str(e)[:120], expected_usd=exp)
                    return {
                        "ok": False,
                        "error": str(e)[:200],
                        "closed": closed,
                        "opened": opened,
                        "skipped": skipped,
                        "amended": amended,
                    }
            else:
                opened.append(open_paper(st, side, bid, ask, src, exp))

        return {
            "ok": True,
            "closed": closed,
            "opened": opened,
            "skipped": skipped,
            "amended": amended,
        }

    out = with_lock(_run)
    book = snapshot(bid, ask)
    out.update({
        "mirror": "g1",
        "want": want,
        "bid": bid,
        "ask": ask,
        "mid": mid,
        "min_reward_usd": MIN_REWARD_USD,
        "live": live_allowed(),
        "paper": not live_allowed(),
        "balance": book.get("balance"),
        "equity": book.get("equity"),
        "open_count": book.get("open_count"),
        "reject": (book.get("last_reject") or {}).get("reason"),
    })
    return out
