"""產生預錄語音（edge-tts 台灣華語）。

用法：python -I tools/gen_voice.py [--force]
  介面與教學 → assets/voice/ui/<id>.ogg（女聲曉臻）
  所有內建句子、身體句子、部位名稱 → assets/voice/f/p_<md5前12碼>.ogg（曉臻）與 assets/voice/m/…（雲哲）
檔名用句子文字的 md5，所以照顧者改過的句子會自動改用電腦語音。
只重做有變動的（assets/voice/manifest.json）。
"""
import asyncio
import hashlib
import json
import os
import re
import subprocess
import sys

import edge_tts

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "assets", "voice")
VOICES = {"f": ("zh-TW-HsiaoChenNeural", "+0%", "+0Hz"), "m": ("zh-TW-YunJheNeural", "+0%", "+0Hz")}
UI_VOICE = ("zh-TW-HsiaoChenNeural", "-3%", "+4Hz")
EXTRA = ["你好，我是現在的聲音"]


def key(text: str) -> str:
    return "p_" + hashlib.md5(text.strip().encode("utf8")).hexdigest()[:12]


def block(src: str, name: str) -> str:
    i = src.index("const " + name)
    j = src.index("\n}\n", i) if src[i:].split("\n", 1)[0].rstrip().endswith("{") else src.index("\n]\n", i)
    return src[i:j]


def collect():
    src = open(os.path.join(ROOT, "scripts", "data.gd"), encoding="utf8").read()
    phrases = []
    for m in re.finditer(r'"\w+": \[(.*?)\]', block(src, "PHRASES"), re.S):
        phrases += re.findall(r'"([^"]+)"', m.group(1))
    phrases += re.findall(r'"([^"]+)"', src[src.index("const BODY_ACTIONS"):].split("\n", 1)[0])
    parts = dict(re.findall(r'"(\w+)": "([^"]+)"', block(src, "PARTS")))
    feels = re.findall(r'\["(\w+)", "([^"]+)", "([^"]+)"\]', block(src, "FEELINGS"))
    for pid, pname in parts.items():
        phrases.append(pname)
        for _fid, _short, tail in feels:
            phrases.append(("我全身" + tail) if pid == "whole" else ("我的" + pname + tail))
    phrases += EXTRA
    ui = dict(re.findall(r'"(\w+)": "([^"]+)"', block(src, "VOICE")))
    for vid, text, _act in re.findall(r'\["(tut_\d+)", "([^"]+)", "([^"]*)"\]', block(src, "TUTORIAL")):
        ui[vid] = text
    seen, uniq = set(), []
    for p in phrases:
        if p not in seen:
            seen.add(p)
            uniq.append(p)
    return uniq, ui


def clean(t: str) -> str:
    return t.replace("ㄒ、ㄧ、ㄝ", "西、一、耶").replace("「", "").replace("」", "")


async def speak(text, path, voice):
    mp3 = path[:-4] + ".mp3"
    name, rate, pitch = voice
    for attempt in range(5):
        try:
            await edge_tts.Communicate(clean(text), name, rate=rate, pitch=pitch).save(mp3)
            break
        except Exception as e:  # noqa: BLE001 — 網路偶發錯誤重試
            print("retry", os.path.basename(path), e, flush=True)
            await asyncio.sleep(2 + attempt * 2)
    else:
        raise RuntimeError("語音失敗：" + text)
    subprocess.run(["ffmpeg", "-v", "error", "-y", "-i", mp3, "-ac", "1", "-ar", "24000", "-c:a", "libvorbis", "-q:a", "3", path], check=True)
    os.remove(mp3)


async def main():
    force = "--force" in sys.argv
    mf = os.path.join(OUT, "manifest.json")
    old = json.load(open(mf, encoding="utf8")) if os.path.exists(mf) else {}
    phrases, ui = collect()
    jobs = {}
    for vid, text in ui.items():
        jobs["ui/" + vid] = (text, UI_VOICE)
    for g, v in VOICES.items():
        for p in phrases:
            jobs[f"{g}/{key(p)}"] = (p, v)
    for d in ["ui", "f", "m"]:
        os.makedirs(os.path.join(OUT, d), exist_ok=True)
    todo = [k for k, (t, _v) in jobs.items() if force or old.get(k) != t or not os.path.exists(os.path.join(OUT, k + ".ogg"))]
    print(f"句子 {len(phrases)}，介面 {len(ui)}，共 {len(jobs)} 檔，要產生 {len(todo)}", flush=True)
    sem = asyncio.Semaphore(8)
    done = [0]

    async def one(k):
        async with sem:
            t, v = jobs[k]
            await speak(t, os.path.join(OUT, k + ".ogg"), v)
            old[k] = t
            done[0] += 1
            if done[0] % 50 == 0:
                print("ok", done[0], flush=True)
                json.dump(old, open(mf, "w", encoding="utf8"), ensure_ascii=False, indent=0)

    await asyncio.gather(*(one(k) for k in todo))
    for k in list(old):
        if k not in jobs:
            old.pop(k)
            p = os.path.join(OUT, k + ".ogg")
            if os.path.exists(p):
                os.remove(p)
    json.dump(old, open(mf, "w", encoding="utf8"), ensure_ascii=False, indent=0)
    print("done", flush=True)


if __name__ == "__main__":
    asyncio.run(main())
