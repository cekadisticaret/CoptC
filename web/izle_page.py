"""/izle — /forex/grafik kopyası. EylulForex grafik şablonuna dokunmaz."""
from __future__ import annotations

import os
import sys

_DIR = os.path.dirname(os.path.abspath(__file__))
_FX = os.path.join(os.path.dirname(_DIR), "EylulForex")
if _FX not in sys.path:
    sys.path.insert(0, _FX)

_PUBLIC_CSS = """<style>
body.fx-public .sidebar,
body.fx-public .rail,
body.fx-public .book-pane{display:none!important}
body.fx-public .desk{width:100%}
</style>"""


def _rewrite(html: str, base: str) -> str:
    html = html.replace("</head>", _PUBLIC_CSS + "\n</head>")
    html = html.replace('class="fx-g1"', 'class="fx-g1 fx-public"')
    html = html.replace("/poly/api/forex", f"{base}/izle/fx")
    html = html.replace('"/forex/', f'"{base}/forex/')
    html = html.replace("'/forex/", f"'{base}/forex/")
    html = html.replace("XAUUSD — CEM01", "İzle — CEM01")
    html = html.replace("<title>İzle — CEM01</title>", "<title>İzle</title>")
    return html


def render(base: str) -> tuple[str, int]:
    from forex_pages import _chart_page

    html = _chart_page("g1")
    return _rewrite(html, base or ""), 200
