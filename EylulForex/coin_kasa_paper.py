"""Cron — ACE (A1#26) ve ENA (A1#28) sanal Isolated. Diğer defterlere yazmaz."""
from __future__ import annotations

import json
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

from coin_kasa import DESKS, tick


def run() -> dict:
    out = {}
    for name in DESKS:
        try:
            book = tick(name)
            out[name] = {
                "ok": book.get("ok"),
                "dir": (book.get("signal") or {}).get("direction") or book.get("last_dir"),
                "bal": book.get("balance"),
                "open": book.get("open_count"),
                "eq": book.get("equity"),
            }
            print(
                f"coin-kasa {name} dir={out[name]['dir']} bal={out[name]['bal']} "
                f"open={out[name]['open']}",
                flush=True,
            )
        except Exception as e:
            out[name] = {"ok": False, "error": str(e)[:160]}
            print(f"coin-kasa {name} err={e}"[:200], flush=True)
    return out


if __name__ == "__main__":
    data = run()
    if "--json" in sys.argv:
        print(json.dumps(data, ensure_ascii=False))
