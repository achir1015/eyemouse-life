"""合成介面音效與警報聲（原創，numpy 產生）→ assets/sfx/*.wav
用法：python -I tools/gen_sfx.py
"""
import os
import wave

import numpy as np

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "assets", "sfx")
SR = 44100


def env(n, a=0.005, r=0.08):
    t = np.arange(n) / SR
    e = np.minimum(1, t / max(a, 1e-4)) * np.exp(-t / max(r, 1e-4))
    return e


def tone(f, dur, a=0.005, r=0.1, kind="sine"):
    n = int(SR * dur)
    t = np.arange(n) / SR
    if kind == "sine":
        w = np.sin(2 * np.pi * f * t)
    elif kind == "tri":
        w = 2 / np.pi * np.arcsin(np.sin(2 * np.pi * f * t))
    else:
        w = np.sign(np.sin(2 * np.pi * f * t)) * 0.6
    return w * env(n, a, r)


def save(name, x, vol=0.8):
    x = np.asarray(x, dtype=np.float64)
    m = np.max(np.abs(x)) or 1.0
    x = x / m * vol
    data = (x * 32767).astype(np.int16)
    with wave.open(os.path.join(OUT, name + ".wav"), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(data.tobytes())


def cat(*parts):
    return np.concatenate(parts)


def silence(d):
    return np.zeros(int(SR * d))


def main():
    os.makedirs(OUT, exist_ok=True)
    # 選到：輕柔木琴兩音
    save("click", tone(880, 0.12, r=0.04, kind="tri") + 0.5 * tone(1320, 0.12, r=0.03), 0.55)
    save("select", cat(tone(660, 0.08, r=0.05, kind="tri"), tone(990, 0.16, r=0.08, kind="tri")), 0.6)
    save("tick", tone(1500, 0.04, r=0.01), 0.3)
    # 翻頁：濾過的雜訊滑音
    n = int(SR * 0.22)
    noise = np.random.default_rng(1).standard_normal(n)
    k = np.convolve(noise, np.ones(40) / 40, mode="same") * env(n, 0.03, 0.08)
    save("page", k, 0.35)
    save("pop", tone(520, 0.1, r=0.04) * np.linspace(1, 0.2, int(SR * 0.1)), 0.5)
    save("open", cat(tone(523, 0.1, r=0.08, kind="tri"), tone(659, 0.1, r=0.08, kind="tri"), tone(784, 0.2, r=0.15, kind="tri")), 0.55)
    save("back", cat(tone(784, 0.1, r=0.08, kind="tri"), tone(523, 0.18, r=0.12, kind="tri")), 0.5)
    save("chime", tone(1046, 0.6, r=0.3) + 0.6 * tone(1568, 0.6, r=0.25) + 0.3 * tone(2093, 0.6, r=0.2), 0.6)
    # 警報一：警笛（上下滑音，2 秒一循環，可無縫重播）
    d = 2.0
    t = np.arange(int(SR * d)) / SR
    f = 750 + 450 * (0.5 - 0.5 * np.cos(2 * np.pi * t / d))
    ph = 2 * np.pi * np.cumsum(f) / SR
    siren = np.sin(ph) + 0.35 * np.sin(2 * ph) + 0.15 * np.sin(3 * ph)
    save("alarm_siren", siren, 0.9)
    # 警報二：鈴聲（快速敲打的雙音鈴）
    hit = tone(1250, 0.09, a=0.001, r=0.06) + 0.7 * tone(1870, 0.09, a=0.001, r=0.05) + 0.4 * tone(2600, 0.09, a=0.001, r=0.03)
    ring = np.tile(hit, 12)
    save("alarm_bell", cat(ring, silence(0.4)), 0.9)
    # 警報三：嗶嗶聲（三短一停）
    b = tone(2000, 0.16, a=0.003, r=1.0, kind="square") * np.hanning(int(SR * 0.16)) ** 0.1
    save("alarm_beep", cat(b, silence(0.09), b, silence(0.09), b, silence(0.6)), 0.85)
    print("sfx ok")


if __name__ == "__main__":
    main()
