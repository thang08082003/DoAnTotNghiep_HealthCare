import math
from typing import Dict, List, Optional


def _mean(values: List[float]) -> float:
    if not values:
        return float("nan")
    return sum(values) / float(len(values))


def _std(values: List[float]) -> float:
    n = len(values)
    if n < 2:
        return float("nan")
    m = _mean(values)
    var = sum((v - m) * (v - m) for v in values) / float(n - 1)
    return math.sqrt(var)


def _percentile(values: List[float], p: float) -> float:
    if not values:
        return float("nan")
    if p <= 0:
        return min(values)
    if p >= 100:
        return max(values)
    vs = sorted(values)
    k = (len(vs) - 1) * (p / 100.0)
    f = math.floor(k)
    c = math.ceil(k)
    if f == c:
        return vs[int(k)]
    d0 = vs[f] * (c - k)
    d1 = vs[c] * (k - f)
    return d0 + d1


def _moving_average(values: List[float], win: int) -> List[float]:
    if win < 1:
        return values[:]
    n = len(values)
    if n == 0:
        return []
    out = [0.0] * n
    half = win // 2
    cum = [0.0]
    s = 0.0
    for v in values:
        s += v
        cum.append(s)
    for i in range(n):
        a = max(0, i - half)
        b = min(n, i + half + 1)
        cnt = b - a
        if cnt > 0:
            out[i] = (cum[b] - cum[a]) / float(cnt)
        else:
            out[i] = values[i]
    return out


def _bandpass_basic(signal: List[float], fs: float) -> List[float]:
    if not signal:
        return []
    m = _mean(signal)
    x = [v - m for v in signal]
    win = max(3, int(0.5 * fs))
    return _moving_average(x, win)


def _normalize(values: List[float]) -> List[float]:
    if not values:
        return []
    vmin = min(values)
    vmax = max(values)
    rng = vmax - vmin
    if rng <= 1e-9:
        return [0.0 for _ in values]
    return [(v - vmin) / rng for v in values]


def _detect_peaks(x: List[float], fs: float) -> List[int]:
    n = len(x)
    if n < 3:
        return []
    xn = _normalize(x)
    thr = _percentile(xn, 75.0)
    refractory = max(1, int(0.3 * fs))
    peaks: List[int] = []
    i = 1
    while i < n - 1:
        if xn[i] > thr and xn[i] > xn[i - 1] and xn[i] >= xn[i + 1]:
            peaks.append(i)
            i += refractory
        else:
            i += 1
    return peaks


def _median(values: List[float]) -> float:
    if not values:
        return float("nan")
    vs = sorted(values)
    n = len(vs)
    mid = n // 2
    if n % 2 == 1:
        return float(vs[mid])
    return (vs[mid - 1] + vs[mid]) / 2.0


def _estimate_fs_from_timestamps(timestamps: List[float]) -> float:
    if not timestamps or len(timestamps) < 2:
        return float("nan")
    diffs = [timestamps[i] - timestamps[i - 1] for i in range(1, len(timestamps))]
    # Dùng median để chống outlier
    med_dt = _median([d for d in diffs if d > 0])
    if med_dt and med_dt > 0:
        return 1.0 / med_dt
    return float("nan")


def _build_time_axis(n: int, fs: float, timestamps: Optional[List[float]]) -> List[float]:
    if timestamps is not None and len(timestamps) == n:
        t0 = float(timestamps[0])
        return [float(timestamps[i]) - t0 for i in range(n)]
    if fs > 0:
        return [i / fs for i in range(n)]
    return [float(i) for i in range(n)]


def _filter_rr_by_range(rr_ms: List[float], rr_min_ms: float, rr_max_ms: float) -> List[float]:
    if not rr_ms:
        return []
    return [v for v in rr_ms if (v > rr_min_ms) and (v < rr_max_ms)]


def _mad_filter(rr_ms: List[float], thresh: float) -> List[float]:
    if not rr_ms:
        return []
    med = _median(rr_ms)
    abs_dev = [abs(v - med) for v in rr_ms]
    mad = _median(abs_dev)
    if mad <= 0 or not math.isfinite(mad):
        return rr_ms[:]  # không lọc khi MAD=0 hoặc không hợp lệ
    limit = thresh * mad
    return [v for v in rr_ms if abs(v - med) <= limit]


def compute_hrv(
    signal: List[float],
    fs: float,
    timestamps: Optional[List[float]] = None,
    drop_initial_seconds: float = 5.0,
    rr_min_ms: float = 250.0,
    rr_max_ms: float = 2000.0,
    mad_thresh: float = 3.0,
    debug_csv_path: Optional[str] = None,
    debug_preview_len: int = 400,
) -> Dict[str, float]:
    # Chuẩn hoá dữ liệu
    arr = [float(v) for v in signal]
    timestamps_list: Optional[List[float]] = None
    if timestamps is not None:
        # đảm bảo cùng độ dài với signal nếu được cung cấp ở dạng per-frame
        if isinstance(timestamps, list) and len(timestamps) == len(arr):
            timestamps_list = [float(t) for t in timestamps]
        else:
            timestamps_list = None

    # Ước lượng fs hiệu dụng khi có timestamp thực (giảm ảnh hưởng dao động fps)
    fs_eff = float(fs)
    if timestamps_list is not None:
        fs_est = _estimate_fs_from_timestamps(timestamps_list)
        if math.isfinite(fs_est) and fs_est > 0:
            fs_eff = fs_est

    # Kiểm tra tối thiểu 5 giây dữ liệu
    min_len = int(max(1.0, 5.0 * fs_eff))
    if fs_eff <= 0 or len(arr) < min_len:
        return {"sdnn": float("nan"), "rmssd": float("nan"), "pnn50": float("nan"), "hr": float("nan"), "hrv_score": 0, "hrv_level": "low"}

    x = _bandpass_basic(arr, fs_eff)
    peaks = _detect_peaks(x, fs_eff)

    # Bỏ 5 giây đầu theo khuyến nghị để ổn định tín hiệu
    if drop_initial_seconds and drop_initial_seconds > 0:
        cutoff = int(drop_initial_seconds * fs_eff)
        if cutoff > 0:
            peaks = [p for p in peaks if p >= cutoff]

    if len(peaks) < 3:
        out = {"sdnn": float("nan"), "rmssd": float("nan"), "pnn50": float("nan"), "hr": float("nan"), "hrv_score": 0, "hrv_level": "low", "num_peaks": len(peaks), "used_fs": float(fs_eff)}
        # Debug preview
        try:
            n = len(arr)
            m = max(0, min(int(debug_preview_len), n))
            times = _build_time_axis(n, fs_eff, timestamps_list)
            out["debug_preview"] = {
                "time_s": times[:m],
                "signal": arr[:m],
                "filtered": x[:m],
                "peaks_idx": [p for p in peaks if p < m],
            }
        except Exception:
            pass
        return out

    # RR (ms)
    rr_ms: List[float] = []
    if timestamps_list is not None:
        # RR từ timestamp thực: (t[i] - t[i-1]) * 1000
        for i in range(1, len(peaks)):
            t_i = timestamps_list[peaks[i]]
            t_prev = timestamps_list[peaks[i - 1]]
            rr_ms.append((t_i - t_prev) * 1000.0)
    else:
        # RR từ frame index: (peaks[i] - peaks[i-1]) * 1000 / fs
        for i in range(1, len(peaks)):
            rr_ms.append((peaks[i] - peaks[i - 1]) * 1000.0 / fs_eff)

    if not rr_ms:
        out = {"sdnn": float("nan"), "rmssd": float("nan"), "pnn50": float("nan"), "hr": float("nan"), "hrv_score": 0, "hrv_level": "low", "num_peaks": len(peaks), "used_fs": float(fs_eff)}
        try:
            n = len(arr)
            m = max(0, min(int(debug_preview_len), n))
            times = _build_time_axis(n, fs_eff, timestamps_list)
            out["debug_preview"] = {
                "time_s": times[:m],
                "signal": arr[:m],
                "filtered": x[:m],
                "peaks_idx": [p for p in peaks if p < m],
            }
        except Exception:
            pass
        return out

    # Làm sạch RR: lọc theo khoảng hợp lý và loại outlier bằng MAD
    rr_ms = _filter_rr_by_range(rr_ms, rr_min_ms, rr_max_ms)
    if mad_thresh and mad_thresh > 0:
        rr_ms = _mad_filter(rr_ms, mad_thresh)

    if len(rr_ms) < 2:
        out = {"sdnn": float("nan"), "rmssd": float("nan"), "pnn50": float("nan"), "hr": float("nan"), "hrv_score": 0, "hrv_level": "low", "num_peaks": len(peaks), "rr_count": len(rr_ms), "used_fs": float(fs_eff)}
        try:
            n = len(arr)
            m = max(0, min(int(debug_preview_len), n))
            times = _build_time_axis(n, fs_eff, timestamps_list)
            out["debug_preview"] = {
                "time_s": times[:m],
                "signal": arr[:m],
                "filtered": x[:m],
                "peaks_idx": [p for p in peaks if p < m],
            }
        except Exception:
            pass
        return out

    sdnn = _std(rr_ms)
    # RMSSD / pNN50
    diffs = [rr_ms[i] - rr_ms[i - 1] for i in range(1, len(rr_ms))]
    rmssd = math.sqrt(_mean([d * d for d in diffs])) if diffs else float("nan")
    pnn50 = (sum(1 for d in diffs if abs(d) > 50.0) / float(len(diffs))) * 100.0 if diffs else float("nan")
    mrr = _mean(rr_ms)
    hr = (60000.0 / mrr) if mrr and mrr > 0 else float("nan")

    # HRV score 0-100
    def _safe(v: float) -> float:
        try:
            return float(v)
        except Exception:
            return float("nan")

    sdnn_v = _safe(sdnn)
    rmssd_v = _safe(rmssd)
    pnn50_v = _safe(pnn50)

    score_f = (0.5 * (rmssd_v / 100.0) + 0.3 * (sdnn_v / 100.0) + 0.2 * (pnn50_v / 100.0)) * 100.0
    if math.isnan(score_f) or score_f < 0:
        score_i = 0
    else:
        score_i = int(min(100, round(score_f)))

    if score_i < 50:
        level = "low"
    elif score_i <= 80:
        level = "medium"
    else:
        level = "high"

    duration_s = float(len(arr) / fs_eff) if timestamps_list is None else float(max(0.0, (timestamps_list[-1] - timestamps_list[0])))

    out = {
        "sdnn": float(sdnn),
        "rmssd": float(rmssd),
        "pnn50": float(pnn50),
        "hr": float(hr),
        "hrv_score": score_i,
        "hrv_level": level,
        # Thông tin chẩn đoán bổ sung
        "num_peaks": int(len(peaks)),
        "rr_count": int(len(rr_ms)),
        "duration_s": duration_s,
        "used_fs": float(fs_eff),
        "used_timestamp": bool(timestamps_list is not None),
    }

    # Đính kèm preview gọn nhẹ để debug/plot phía Flutter (không ảnh hưởng Kotlin)
    try:
        n = len(arr)
        m = max(0, min(int(debug_preview_len), n))
        times = _build_time_axis(n, fs_eff, timestamps_list)
        out["debug_preview"] = {
            "time_s": times[:m],
            "signal": arr[:m],
            "filtered": x[:m],
            "peaks_idx": [p for p in peaks if p < m],
            "rr_ms_preview": rr_ms[: min(len(rr_ms), 400)],
        }
    except Exception:
        pass

    return out


