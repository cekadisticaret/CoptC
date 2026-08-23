"""/izle — /forex/grafik kopyası. EylulForex grafik şablonuna dokunmaz."""
from __future__ import annotations

import os
import sys

_DIR = os.path.dirname(os.path.abspath(__file__))
_FX = os.path.join(os.path.dirname(_DIR), "EylulForex")
if _FX not in sys.path:
    sys.path.insert(0, _FX)


def _rewrite(html: str, base: str) -> str:
    brand = (
        f'<a href="{base}/" style="display:block;text-decoration:none;color:inherit;'
        'padding:4px 8px 10px">'
        '<div style="font-weight:800;font-size:15px;letter-spacing:-.3px">Cem Forex</div>'
        f'<div style="font-size:12px;color:#8b8678;margin-top:4px">← CoptC</div></a>'
    )
    html = html.replace("__FOREX_BRAND__", brand)
    html = html.replace('href="/poly"', f'href="{base}/"')
    html = html.replace('href="/kripto"', f'href="{base}/"')
    html = html.replace("/poly/api/forex", f"{base}/fx")
    html = html.replace('"/forex/', f'"{base}/forex/')
    html = html.replace("'/forex/", f"'{base}/forex/")
    html = html.replace("XAUUSD — CEM01", "İzle — CEM01")
    html = html.replace("<title>İzle — CEM01</title>", "<title>İzle</title>")
    return html


def render(base: str) -> tuple[str, int]:
    from forex_pages import _chart_page

    html = _chart_page("g1")
    return _rewrite(html, base or ""), 200
