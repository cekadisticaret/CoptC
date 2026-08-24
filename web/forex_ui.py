"""CoptC /admin/forex — EylulForex sayfalarını oturum altında sun."""
from __future__ import annotations

import os
import sys
import urllib.error
import urllib.request

from flask import request

_DIR = os.path.dirname(os.path.abspath(__file__))
_FX = os.path.join(os.path.dirname(_DIR), "EylulForex")
if _FX not in sys.path:
    sys.path.insert(0, _FX)

_PAGES = {
    "": "FOREX_HTML",
    "home": "FOREX_HTML",
    "gpsusdt": "FOREX_GPSUSDT_HTML",
    "gpsusdt2": "FOREX_GPS2_HTML",
    "bin-b103": "FOREX_BINB103_HTML",
    "b103": "FOREX_B103_HTML",
    "algoritma-islemler": "FOREX_FX_ALGOS_HTML",
    "grafik": "FOREX_GRAFIK_HTML",
    "cem02": "FOREX_CEM02_HTML",
    "openapi": "FOREX_OAPI_HTML",
    "islemler": "FOREX_ISLEMLER_HTML",
    "yapay-zeka-analiz": "FOREX_YZA_HTML",
    "gpsusdt/islemler": "FOREX_GPS_ISLEMLER_HTML",
    "gpsusdt2/islemler": "FOREX_GPS2_ISLEMLER_HTML",
    "bin-b103/islemler": "FOREX_BINB103_ISLEMLER_HTML",
    "cem02/islemler": "FOREX_CEM02_ISLEMLER_HTML",
    "openapi/islemler": "FOREX_OAPI_ISLEMLER_HTML",
    "b103/islemler": "FOREX_B103_ISLEMLER_HTML",
}


def _pages():
    import importlib
    import forex_pages
    return importlib.reload(forex_pages)


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
    return html


def render_page(page: str, base: str) -> tuple[str, int]:
    key = (page or "").strip().strip("/")
    if key.startswith("algoritma-islemler"):
        attr = "FOREX_FX_ALGOS_HTML"
    else:
        attr = _PAGES.get(key)
    if not attr:
        return "forex sayfası yok", 404
    try:
        html = getattr(_pages(), attr)
    except Exception as exc:
        return f"forex şablon yüklenemedi: {exc}", 500
    return _rewrite(html, base or ""), 200


def proxy_api(rest: str, token: str):
    """(body_bytes|None, status, mimetype). body None → jsonify caller-side."""
    qs = request.query_string.decode() if request.query_string else ""
    url = f"http://127.0.0.1:5070/poly/api/forex/{rest}"
    if qs:
        url += "?" + qs
    headers = {"Accept": "application/json"}
    if token:
        headers["X-Forex-Remote"] = token
    body = request.get_data() if request.method in ("POST", "PUT", "PATCH") else None
    if body:
        headers["Content-Type"] = request.content_type or "application/json"
    req = urllib.request.Request(url, data=body or None, headers=headers, method=request.method)
    try:
        with urllib.request.urlopen(req, timeout=30) as resp:
            return resp.read(), resp.status, resp.headers.get_content_type() or "application/json"
    except urllib.error.HTTPError as exc:
        return exc.read(), exc.code, "application/json"
    except Exception:
        return None, 502, "application/json"
