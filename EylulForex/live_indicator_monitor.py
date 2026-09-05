"""
Canlı İndikatör İzleme Sistemi (Live Indicator Monitor)
===========================================================

Amaç: Konuştuğumuz çizim bazlı indikatörlerin (trend çizgisi, kanal, VWAP,
volume profile, fibonacci, order block/FVG) hepsini tek bir modülde
otomatik ve objektif şekilde hesaplayıp, her biri için ANLIK durum yorumu
(fikir/yön/güven skoru) üreten bir sistem.

Kullanım senaryosu:
- Bu dosya bağımsız çalışabilir (kendi OHLCV verinizi DataFrame olarak
  verirsiniz) ya da canlı bir loop içinde periyodik çağrılabilir.
- Cursor'daki asıl karar algoritmanıza `get_market_snapshot(df)` fonksiyonunun
  döndürdüğü dict'i JSON olarak besleyebilirsiniz — LONG/SHORT/BEKLE kararını
  o taraf verir, bu modül sadece "objektif teknik durum" üretir.

Girdi formatı (df: pandas.DataFrame), zaman sırasına göre artan, kolonlar:
    timestamp (datetime), open, high, low, close, volume

Bağımlılıklar: sadece pandas + numpy (ta-lib veya harici paket gerekmez,
mevcut altyapınıza (DigitalOcean droplet, PM2) ek kurulum yükü getirmez).

Not: Buradaki her indikatör heuristik/parametrik bir yaklaşımdır.
Parametreler (pencere, eşik vb.) piyasaya ve zaman dilimine göre
backtest ile ayarlanmalıdır — production'a almadan önce mutlaka
kendi verinizle doğrulayın.
"""

from __future__ import annotations

import math
from dataclasses import dataclass, field
from datetime import datetime, timezone
from typing import Dict, List, Optional, Tuple

import numpy as np
import pandas as pd


# ============================================================
# 1. PIVOT TESPİTİ VE OTOMATİK TREND ÇİZGİSİ
# ============================================================

def find_pivots(df: pd.DataFrame, left: int = 3, right: int = 3) -> Tuple[List[int], List[int]]:
    """
    Pivot high/low noktalarını bulur (solundaki 'left' ve sağındaki 'right'
    bar sayısına göre lokal maksimum/minimum).
    Not: Bir pivot'un "onaylanması" için sağındaki 'right' kadar barın
    kapanması gerekir -> canlı akışta pivot en erken (right) bar gecikmeyle
    kesinleşir. Bu normaldir, look-ahead bias'tan kaçınmak için gereklidir.
    """
    highs, lows = df["high"].values, df["low"].values
    n = len(df)
    pivot_highs, pivot_lows = [], []

    for i in range(left, n - right):
        window_h = highs[i - left:i + right + 1]
        if highs[i] == window_h.max() and np.argmax(window_h) == left:
            pivot_highs.append(i)
        window_l = lows[i - left:i + right + 1]
        if lows[i] == window_l.min() and np.argmin(window_l) == left:
            pivot_lows.append(i)

    return pivot_highs, pivot_lows


def auto_trendline(df: pd.DataFrame, pivot_idxs: List[int], kind: str = "support") -> Optional[dict]:
    """
    Son iki pivot noktasından bir doğru geçirir ve güncel bara projekte eder.
    kind='support' -> pivot low'lardan, kind='resistance' -> pivot high'lardan.
    """
    if len(pivot_idxs) < 2:
        return None

    i1, i2 = pivot_idxs[-2], pivot_idxs[-1]
    col = "low" if kind == "support" else "high"
    y1, y2 = df[col].iloc[i1], df[col].iloc[i2]

    if i2 == i1:
        return None

    slope = (y2 - y1) / (i2 - i1)
    current_idx = len(df) - 1
    projected_value = y2 + slope * (current_idx - i2)
    current_price = df["close"].iloc[-1]
    distance_pct = ((current_price - projected_value) / projected_value) * 100

    if kind == "support":
        status = "fiyat_ustunde" if current_price > projected_value else "kirildi"
    else:
        status = "fiyat_altinda" if current_price < projected_value else "kirildi"

    return {
        "kind": kind,
        "slope": round(slope, 6),
        "projected_line_value": round(float(projected_value), 5),
        "current_price": round(float(current_price), 5),
        "distance_pct": round(float(distance_pct), 3),
        "status": status,
        "pivot_bar_indices": [i1, i2],
    }


# ============================================================
# 2. DOĞRUSAL REGRESYON KANALI
# ============================================================

def linear_regression_channel(df: pd.DataFrame, window: int = 100, std_mult: float = 2.0) -> dict:
    """
    Son 'window' bar üzerinden en küçük kareler regresyonu + standart sapma
    bantları. Kalman filtre yaklaşımının statik/basit versiyonu.
    """
    sub = df["close"].iloc[-window:].reset_index(drop=True)
    x = np.arange(len(sub))
    slope, intercept = np.polyfit(x, sub.values, 1)
    fitted = slope * x + intercept
    residuals = sub.values - fitted
    std = residuals.std()

    current_fitted = fitted[-1]
    upper = current_fitted + std_mult * std
    lower = current_fitted - std_mult * std
    current_price = sub.values[-1]

    if current_price >= upper:
        position = "ust_bant_uzeri"
    elif current_price <= lower:
        position = "alt_bant_altinda"
    else:
        position = "kanal_ici"

    trend_direction = "yukselen" if slope > 0 else "dusen" if slope < 0 else "yatay"

    return {
        "window": window,
        "slope": round(float(slope), 6),
        "trend_direction": trend_direction,
        "channel_mid": round(float(current_fitted), 5),
        "channel_upper": round(float(upper), 5),
        "channel_lower": round(float(lower), 5),
        "current_price": round(float(current_price), 5),
        "position": position,
    }


# ============================================================
# 3. DONCHIAN / KELTNER KANALLARI + SQUEEZE
# ============================================================

def donchian_channel(df: pd.DataFrame, period: int = 20) -> dict:
    upper = df["high"].rolling(period).max().iloc[-1]
    lower = df["low"].rolling(period).min().iloc[-1]
    mid = (upper + lower) / 2
    current_price = df["close"].iloc[-1]

    if current_price >= upper:
        status = "ust_kirilim"
    elif current_price <= lower:
        status = "alt_kirilim"
    else:
        status = "kanal_ici"

    return {
        "period": period,
        "upper": round(float(upper), 5),
        "mid": round(float(mid), 5),
        "lower": round(float(lower), 5),
        "current_price": round(float(current_price), 5),
        "status": status,
    }


def _atr(df: pd.DataFrame, period: int = 14) -> pd.Series:
    high, low, close = df["high"], df["low"], df["close"]
    prev_close = close.shift(1)
    tr = pd.concat([
        high - low,
        (high - prev_close).abs(),
        (low - prev_close).abs(),
    ], axis=1).max(axis=1)
    return tr.rolling(period).mean()


def keltner_channel(df: pd.DataFrame, period: int = 20, atr_mult: float = 1.5) -> dict:
    ema = df["close"].ewm(span=period, adjust=False).mean()
    atr = _atr(df, period)
    upper = ema + atr_mult * atr
    lower = ema - atr_mult * atr
    current_price = df["close"].iloc[-1]

    return {
        "period": period,
        "ema_mid": round(float(ema.iloc[-1]), 5),
        "upper": round(float(upper.iloc[-1]), 5),
        "lower": round(float(lower.iloc[-1]), 5),
        "current_price": round(float(current_price), 5),
    }


def bollinger_bands(df: pd.DataFrame, period: int = 20, std_mult: float = 2.0) -> dict:
    sma = df["close"].rolling(period).mean()
    std = df["close"].rolling(period).std()
    upper = sma + std_mult * std
    lower = sma - std_mult * std
    return {
        "sma": round(float(sma.iloc[-1]), 5),
        "upper": round(float(upper.iloc[-1]), 5),
        "lower": round(float(lower.iloc[-1]), 5),
        "bandwidth": round(float((upper.iloc[-1] - lower.iloc[-1]) / sma.iloc[-1]), 5),
    }


def squeeze_status(df: pd.DataFrame, bb_period: int = 20, kc_period: int = 20) -> dict:
    """
    Bollinger Bandı Keltner Kanalı içine girdiğinde 'squeeze' (sıkışma) oluşur
    -> genelde patlama/kırılım öncesi düşük volatilite dönemidir.
    """
    bb = bollinger_bands(df, bb_period)
    kc = keltner_channel(df, kc_period)

    is_squeeze = bb["upper"] < kc["upper"] and bb["lower"] > kc["lower"]

    return {
        "bollinger": bb,
        "keltner": kc,
        "squeeze_active": bool(is_squeeze),
        "yorum": "sikisma_var_kirilim_yaklasiyor_olabilir" if is_squeeze else "sikisma_yok",
    }


# ============================================================
# 4. ANCHORED VWAP
# ============================================================

def anchored_vwap(df: pd.DataFrame, anchor_idx: int = 0, std_mult: float = 1.0) -> dict:
    """
    anchor_idx: VWAP hesabının başlayacağı bar indexi (örn. gün başlangıcı,
    önemli haber barı, session açılışı). Varsayılan 0 = tüm dataframe.
    """
    sub = df.iloc[anchor_idx:].copy()
    typical_price = (sub["high"] + sub["low"] + sub["close"]) / 3
    cum_vol = sub["volume"].cumsum()
    cum_vol_price = (typical_price * sub["volume"]).cumsum()
    vwap = cum_vol_price / cum_vol

    # VWAP etrafındaki standart sapma bandı
    variance = ((typical_price - vwap) ** 2 * sub["volume"]).cumsum() / cum_vol
    std = np.sqrt(variance)

    current_price = df["close"].iloc[-1]
    current_vwap = vwap.iloc[-1]
    current_std = std.iloc[-1]

    upper_band = current_vwap + std_mult * current_std
    lower_band = current_vwap - std_mult * current_std

    if current_price > upper_band:
        status = "vwap_ustunde_asiri"
    elif current_price > current_vwap:
        status = "vwap_ustunde"
    elif current_price < lower_band:
        status = "vwap_altinda_asiri"
    else:
        status = "vwap_altinda"

    return {
        "anchor_idx": anchor_idx,
        "vwap": round(float(current_vwap), 5),
        "upper_band": round(float(upper_band), 5),
        "lower_band": round(float(lower_band), 5),
        "current_price": round(float(current_price), 5),
        "status": status,
    }


# ============================================================
# 5. VOLUME PROFILE (POC / VAH / VAL)
# ============================================================

def volume_profile(df: pd.DataFrame, lookback: int = 200, bins: int = 30, value_area_pct: float = 0.70) -> dict:
    """
    Fiyat eksenini 'bins' aralığa bölüp her aralıktaki toplam hacmi hesaplar.
    POC (Point of Control): en çok hacim gören fiyat seviyesi.
    VAH/VAL: toplam hacmin %70'ini (value_area_pct) içeren üst/alt sınırlar.
    """
    sub = df.iloc[-lookback:]
    price_min, price_max = sub["low"].min(), sub["high"].max()
    bin_edges = np.linspace(price_min, price_max, bins + 1)
    bin_volumes = np.zeros(bins)

    for _, row in sub.iterrows():
        # Her barın hacmini, o barın high-low aralığına düşen bin'lere eşit dağıtıyoruz
        low_bin = np.searchsorted(bin_edges, row["low"], side="right") - 1
        high_bin = np.searchsorted(bin_edges, row["high"], side="right") - 1
        low_bin, high_bin = max(0, low_bin), min(bins - 1, high_bin)
        span = max(1, high_bin - low_bin + 1)
        for b in range(low_bin, high_bin + 1):
            bin_volumes[b] += row["volume"] / span

    poc_idx = int(np.argmax(bin_volumes))
    poc_price = (bin_edges[poc_idx] + bin_edges[poc_idx + 1]) / 2

    # Value area: POC'tan dışarı doğru genişleyerek hacmin %70'ine ulaşana kadar
    total_volume = bin_volumes.sum()
    target_volume = total_volume * value_area_pct
    included = {poc_idx}
    accumulated = bin_volumes[poc_idx]
    lo, hi = poc_idx, poc_idx

    while accumulated < target_volume and (lo > 0 or hi < bins - 1):
        left_vol = bin_volumes[lo - 1] if lo > 0 else -1
        right_vol = bin_volumes[hi + 1] if hi < bins - 1 else -1
        if left_vol >= right_vol:
            lo -= 1
            accumulated += bin_volumes[lo]
            included.add(lo)
        else:
            hi += 1
            accumulated += bin_volumes[hi]
            included.add(hi)

    vah = bin_edges[hi + 1]
    val = bin_edges[lo]
    current_price = df["close"].iloc[-1]

    if current_price > vah:
        status = "value_area_ustunde"
    elif current_price < val:
        status = "value_area_altinda"
    else:
        status = "value_area_ici"

    return {
        "poc": round(float(poc_price), 5),
        "value_area_high": round(float(vah), 5),
        "value_area_low": round(float(val), 5),
        "current_price": round(float(current_price), 5),
        "status": status,
    }


# ============================================================
# 6. OTOMATİK FİBONACCİ (SON SWING'DEN)
# ============================================================

def auto_fibonacci(df: pd.DataFrame, pivot_highs: List[int], pivot_lows: List[int]) -> Optional[dict]:
    """
    En son oluşan swing high/low çiftinden fibonacci retracement seviyeleri
    üretir ve güncel fiyatın hangi seviyeye en yakın olduğunu bulur.
    """
    if not pivot_highs or not pivot_lows:
        return None

    last_high_idx, last_low_idx = pivot_highs[-1], pivot_lows[-1]
    high_price = df["high"].iloc[last_high_idx]
    low_price = df["low"].iloc[last_low_idx]

    uptrend = last_low_idx < last_high_idx  # low önce oluştuysa yükseliş swing'i
    diff = high_price - low_price

    levels_pct = [0.0, 0.236, 0.382, 0.5, 0.618, 0.786, 1.0]
    if uptrend:
        levels = {p: high_price - diff * p for p in levels_pct}
    else:
        levels = {p: low_price + diff * p for p in levels_pct}

    current_price = df["close"].iloc[-1]
    nearest_level = min(levels.items(), key=lambda kv: abs(kv[1] - current_price))

    return {
        "swing_direction": "yukselis" if uptrend else "dusus",
        "swing_high": round(float(high_price), 5),
        "swing_low": round(float(low_price), 5),
        "levels": {f"{int(p*1000)/1000}": round(float(v), 5) for p, v in levels.items()},
        "current_price": round(float(current_price), 5),
        "nearest_level_pct": nearest_level[0],
        "nearest_level_price": round(float(nearest_level[1]), 5),
        "distance_to_nearest_pct": round(
            float((current_price - nearest_level[1]) / nearest_level[1] * 100), 3
        ),
    }


# ============================================================
# 7. ORDER BLOCK / FAIR VALUE GAP (BASİT SMC)
# ============================================================

def detect_fair_value_gaps(df: pd.DataFrame, lookback: int = 50) -> List[dict]:
    """
    3 mumluk klasik FVG tanımı: 1. mumun high'ı ile 3. mumun low'u arasında
    boşluk varsa (yükseliş FVG) ya da 1. mumun low'u ile 3. mumun high'ı
    arasında boşluk varsa (düşüş FVG) bu bölge 'imbalance/fair value gap'
    olarak işaretlenir. Fiyatın bu bölgeye geri dönüp dönmediği izlenir.
    """
    sub = df.iloc[-lookback:].reset_index(drop=True)
    gaps = []

    for i in range(2, len(sub)):
        c1, c3 = sub.iloc[i - 2], sub.iloc[i]
        if c3["low"] > c1["high"]:
            gaps.append({
                "type": "bullish_fvg",
                "gap_low": round(float(c1["high"]), 5),
                "gap_high": round(float(c3["low"]), 5),
                "bar_index": i,
            })
        elif c3["high"] < c1["low"]:
            gaps.append({
                "type": "bearish_fvg",
                "gap_low": round(float(c3["high"]), 5),
                "gap_high": round(float(c1["low"]), 5),
                "bar_index": i,
            })

    current_price = df["close"].iloc[-1]
    for g in gaps:
        g["filled"] = g["gap_low"] <= current_price <= g["gap_high"]

    return gaps[-5:]  # sadece en güncel 5 gap


def detect_order_blocks(df: pd.DataFrame, lookback: int = 50) -> List[dict]:
    """
    Basit order block tanımı: güçlü bir yönlü hareketten (impulse) hemen önceki
    ters yönlü son mum, 'order block' olarak işaretlenir.
    impulse eşiği: o barın gövdesi, son 20 barın ortalama gövdesinin 1.5 katından
    büyük olmalı.
    """
    sub = df.iloc[-lookback:].reset_index(drop=True)
    body = (sub["close"] - sub["open"]).abs()
    avg_body = body.rolling(20).mean()

    blocks = []
    for i in range(20, len(sub) - 1):
        is_impulse = body.iloc[i] > 1.5 * avg_body.iloc[i]
        if not is_impulse:
            continue
        impulse_bullish = sub["close"].iloc[i] > sub["open"].iloc[i]
        prev = sub.iloc[i - 1]
        prev_bearish = prev["close"] < prev["open"]
        prev_bullish = prev["close"] > prev["open"]

        if impulse_bullish and prev_bearish:
            blocks.append({
                "type": "bullish_order_block",
                "zone_low": round(float(prev["low"]), 5),
                "zone_high": round(float(prev["open"]), 5),
                "bar_index": i - 1,
            })
        elif (not impulse_bullish) and prev_bullish:
            blocks.append({
                "type": "bearish_order_block",
                "zone_low": round(float(prev["close"]), 5),
                "zone_high": round(float(prev["high"]), 5),
                "bar_index": i - 1,
            })

    current_price = df["close"].iloc[-1]
    for b in blocks:
        b["price_inside_zone"] = b["zone_low"] <= current_price <= b["zone_high"]

    return blocks[-5:]


# ============================================================
# 8. HEPSİNİ BİRLEŞTİREN ANLIK SNAPSHOT
# ============================================================

@dataclass
class IndicatorOpinion:
    name: str
    yorum: str          # Türkçe kısa yorum
    yon: str             # "yukselis" | "dusus" | "notr"
    guven: float          # 0-1 arası

    def to_dict(self) -> dict:
        return {"indikator": self.name, "yorum": self.yorum, "yon": self.yon, "guven": round(self.guven, 2)}


def _trendline_opinion(support: Optional[dict], resistance: Optional[dict]) -> IndicatorOpinion:
    if support and support["status"] == "kirildi":
        return IndicatorOpinion("otomatik_trend_cizgisi", "Destek trend çizgisi kırıldı, düşüş baskısı olabilir", "dusus", 0.55)
    if resistance and resistance["status"] == "kirildi":
        return IndicatorOpinion("otomatik_trend_cizgisi", "Direnç trend çizgisi kırıldı, yükseliş baskısı olabilir", "yukselis", 0.55)
    if support and support["status"] == "fiyat_ustunde":
        return IndicatorOpinion("otomatik_trend_cizgisi", "Fiyat destek trend çizgisinin üzerinde tutunuyor", "yukselis", 0.4)
    if resistance and resistance["status"] == "fiyat_altinda":
        return IndicatorOpinion("otomatik_trend_cizgisi", "Fiyat direnç trend çizgisinin altında sıkışıyor", "dusus", 0.4)
    return IndicatorOpinion("otomatik_trend_cizgisi", "Yeterli pivot yok / net durum belirsiz", "notr", 0.2)


def _channel_opinion(lr: dict, donchian: dict) -> IndicatorOpinion:
    if lr["position"] == "ust_bant_uzeri" and donchian["status"] == "ust_kirilim":
        return IndicatorOpinion("kanal_analizi", "Regresyon kanalının üstünde + Donchian üst kırılımı: güçlü momentum", "yukselis", 0.7)
    if lr["position"] == "alt_bant_altinda" and donchian["status"] == "alt_kirilim":
        return IndicatorOpinion("kanal_analizi", "Regresyon kanalının altında + Donchian alt kırılımı: güçlü düşüş momentumu", "dusus", 0.7)
    if lr["position"] == "kanal_ici" and donchian["status"] == "kanal_ici":
        return IndicatorOpinion("kanal_analizi", "Fiyat her iki kanalda da orta bölgede, yön belirsiz", "notr", 0.3)
    return IndicatorOpinion("kanal_analizi", f"Regresyon: {lr['position']}, Donchian: {donchian['status']}", "notr", 0.4)


def _vwap_opinion(vwap: dict) -> IndicatorOpinion:
    mapping = {
        "vwap_ustunde_asiri": ("Fiyat VWAP üst bandının çok üzerinde, kısa vadeli aşırı alım olabilir", "dusus", 0.45),
        "vwap_ustunde": ("Fiyat VWAP üzerinde, alıcı kontrolü", "yukselis", 0.5),
        "vwap_altinda": ("Fiyat VWAP altında, satıcı kontrolü", "dusus", 0.5),
        "vwap_altinda_asiri": ("Fiyat VWAP alt bandının çok altında, kısa vadeli aşırı satım olabilir", "yukselis", 0.45),
    }
    yorum, yon, guven = mapping.get(vwap["status"], ("Belirsiz", "notr", 0.2))
    return IndicatorOpinion("anchored_vwap", yorum, yon, guven)


def _volume_profile_opinion(vp: dict) -> IndicatorOpinion:
    mapping = {
        "value_area_ustunde": ("Fiyat value area'nın üzerinde, güçlü kabul bölgesinin dışında yükseliyor", "yukselis", 0.5),
        "value_area_altinda": ("Fiyat value area'nın altında, zayıflık işareti", "dusus", 0.5),
        "value_area_ici": ("Fiyat value area içinde, dengeli/yatay bölge", "notr", 0.3),
    }
    yorum, yon, guven = mapping.get(vp["status"], ("Belirsiz", "notr", 0.2))
    return IndicatorOpinion("volume_profile", yorum, yon, guven)


def _fibonacci_opinion(fib: Optional[dict]) -> IndicatorOpinion:
    if not fib:
        return IndicatorOpinion("fibonacci", "Yeterli swing verisi yok", "notr", 0.15)
    level = fib["nearest_level_pct"]
    if level in (0.618, 0.5) and abs(fib["distance_to_nearest_pct"]) < 0.3:
        yon = "yukselis" if fib["swing_direction"] == "yukselis" else "dusus"
        return IndicatorOpinion("fibonacci", f"Fiyat {level} seviyesine çok yakın, klasik geri çekilme bölgesi", yon, 0.45)
    return IndicatorOpinion("fibonacci", f"Fiyat en yakın {level} seviyesinden %{fib['distance_to_nearest_pct']} uzakta", "notr", 0.25)


def _smc_opinion(fvgs: List[dict], obs: List[dict]) -> IndicatorOpinion:
    active_bull_ob = [b for b in obs if b["type"] == "bullish_order_block" and b["price_inside_zone"]]
    active_bear_ob = [b for b in obs if b["type"] == "bearish_order_block" and b["price_inside_zone"]]
    unfilled_bull_fvg = [g for g in fvgs if g["type"] == "bullish_fvg" and not g["filled"]]
    unfilled_bear_fvg = [g for g in fvgs if g["type"] == "bearish_fvg" and not g["filled"]]

    if active_bull_ob:
        return IndicatorOpinion("smc_order_block_fvg", "Fiyat aktif bir bullish order block bölgesinde", "yukselis", 0.55)
    if active_bear_ob:
        return IndicatorOpinion("smc_order_block_fvg", "Fiyat aktif bir bearish order block bölgesinde", "dusus", 0.55)
    if unfilled_bull_fvg:
        return IndicatorOpinion("smc_order_block_fvg", "Doldurulmamış yükseliş FVG'si var, fiyat buraya çekilebilir", "yukselis", 0.35)
    if unfilled_bear_fvg:
        return IndicatorOpinion("smc_order_block_fvg", "Doldurulmamış düşüş FVG'si var, fiyat buraya çekilebilir", "dusus", 0.35)
    return IndicatorOpinion("smc_order_block_fvg", "Belirgin order block / FVG bölgesi yok", "notr", 0.2)


def get_market_snapshot(df: pd.DataFrame) -> dict:
    """
    ANA FONKSİYON: Verilen OHLCV DataFrame'i için tüm indikatörleri hesaplar,
    her biri için Türkçe yorum üretir ve genel bir confluence (birleşik)
    skor ile özet döner.

    df en az ~120-150 bar içermeli (regresyon kanalı ve volume profile
    için yeterli pencere gerekiyor). Daha az veri varsa fonksiyon eldeki
    veriyle çalışır ama bazı indikatörler 'yetersiz veri' der.
    """
    df = df.reset_index(drop=True)
    if len(df) < 30:
        raise ValueError("Analiz için en az 30 bar OHLCV verisi gerekli.")

    pivot_highs, pivot_lows = find_pivots(df, left=3, right=3)
    support_line = auto_trendline(df, pivot_lows, kind="support")
    resistance_line = auto_trendline(df, pivot_highs, kind="resistance")

    window = min(100, len(df) - 1)
    lr_channel = linear_regression_channel(df, window=window)
    donchian = donchian_channel(df, period=min(20, len(df) - 1))
    squeeze = squeeze_status(df)
    vwap = anchored_vwap(df, anchor_idx=0)
    vp_lookback = min(200, len(df))
    vp = volume_profile(df, lookback=vp_lookback)
    fib = auto_fibonacci(df, pivot_highs, pivot_lows)
    fvgs = detect_fair_value_gaps(df)
    obs = detect_order_blocks(df)

    opinions: List[IndicatorOpinion] = [
        _trendline_opinion(support_line, resistance_line),
        _channel_opinion(lr_channel, donchian),
        _vwap_opinion(vwap),
        _volume_profile_opinion(vp),
        _fibonacci_opinion(fib),
        _smc_opinion(fvgs, obs),
    ]

    # Basit confluence skoru: yön bazlı ağırlıklı toplam (-1..+1)
    score = 0.0
    for op in opinions:
        if op.yon == "yukselis":
            score += op.guven
        elif op.yon == "dusus":
            score -= op.guven
    max_possible = sum(op.guven for op in opinions) or 1.0
    normalized_score = round(score / max_possible, 3)

    if normalized_score > 0.25:
        genel_yorum = "Çoğunluk indikatör yükseliş yönünde"
        genel_yon = "yukselis"
    elif normalized_score < -0.25:
        genel_yorum = "Çoğunluk indikatör düşüş yönünde"
        genel_yon = "dusus"
    else:
        genel_yorum = "İndikatörler arasında net bir yön birliği yok"
        genel_yon = "notr"

    return {
        "timestamp": datetime.now(timezone.utc).isoformat(),
        "current_price": round(float(df["close"].iloc[-1]), 5),
        "detay": {
            "support_trendline": support_line,
            "resistance_trendline": resistance_line,
            "linear_regression_channel": lr_channel,
            "donchian_channel": donchian,
            "squeeze": squeeze,
            "anchored_vwap": vwap,
            "volume_profile": vp,
            "fibonacci": fib,
            "fair_value_gaps": fvgs,
            "order_blocks": obs,
        },
        "yorumlar": [op.to_dict() for op in opinions],
        "genel_confluence_skoru": normalized_score,
        "genel_yon": genel_yon,
        "genel_yorum": genel_yorum,
    }


# ============================================================
# 9. CANLI İZLEME DÖNGÜSÜ (İSKELET)
# ============================================================

def run_live_loop(fetch_ohlcv_fn, poll_interval_sec: int = 60, on_snapshot=None):
    """
    Basit canlı izleme döngüsü iskeleti.

    fetch_ohlcv_fn: argümansız çağrıldığında güncel OHLCV verisini
        pandas.DataFrame olarak döndüren fonksiyon (kendi borsa/veri
        API'nizden -- örn. Binance USDM futures -- besleyeceksiniz).
    on_snapshot: her yeni snapshot üretildiğinde çağrılacak callback
        (örn. Cursor'daki karar algoritmanıza HTTP POST atan bir fonksiyon,
        ya da SQLite'a yazan bir fonksiyon).

    Not: Bu fonksiyon bilinçli olarak basit tutuldu (blocking while loop +
    time.sleep). Gerçek production'da bunun yerine PM2 altında ayrı bir
    process olarak, ya da mevcut sinyal motorunuzun içinde bir cron/async
    task olarak çalıştırmanız daha uygun olur.
    """
    import time

    while True:
        try:
            df = fetch_ohlcv_fn()
            snapshot = get_market_snapshot(df)
            if on_snapshot:
                on_snapshot(snapshot)
            else:
                print(snapshot)
        except Exception as e:  # noqa: BLE001 - canlı döngü asla tamamen çökmemeli
            print(f"[canlı izleme hata] {e}")
        time.sleep(poll_interval_sec)


# ============================================================
# ÖRNEK KULLANIM
# ============================================================

if __name__ == "__main__":
    # Sentetik OHLCV verisi ile örnek çalıştırma (gerçek kullanımda kendi
    # verinizi -- örn. Binance klines -- DataFrame'e çevirip verin)
    rng = np.random.default_rng(7)
    n_bars = 250
    close = 100 + np.cumsum(rng.normal(0, 0.6, n_bars))
    high = close + rng.uniform(0.1, 0.8, n_bars)
    low = close - rng.uniform(0.1, 0.8, n_bars)
    open_ = close + rng.normal(0, 0.3, n_bars)
    volume = rng.uniform(50, 500, n_bars)

    sample_df = pd.DataFrame({
        "open": open_, "high": high, "low": low, "close": close, "volume": volume,
    })

    snapshot = get_market_snapshot(sample_df)

    print("=== ANLIK PİYASA DURUMU ===")
    print(f"Fiyat: {snapshot['current_price']}")
    print(f"Genel yön: {snapshot['genel_yon']} (skor: {snapshot['genel_confluence_skoru']})")
    print(f"Genel yorum: {snapshot['genel_yorum']}\n")
    for y in snapshot["yorumlar"]:
        print(f"- [{y['indikator']}] {y['yorum']} -> {y['yon']} (güven: {y['guven']})")
