"""產生注音輸入詞庫 data/bpmf.txt（給眼控注音鍵盤用）。

來源：McBopomofo 小麥注音（MIT 授權，tools/mcbopomofo_src/），
  BPMFBase.txt   單字讀音（只取 big5 常用字）
  BPMFMappings.txt 詞的讀音
  phrase.occ     出現次數（排序用）
輸出：每行「詞<TAB>讀音（音節以空白分隔）<TAB>次數」，依次數由高到低。
用法：python -I tools/build_dict.py
"""
import os

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(ROOT, "tools", "mcbopomofo_src")
OUT = os.path.join(ROOT, "data", "bpmf.txt")

MAX_PHRASES = 45000


def main():
    occ = {}
    with open(os.path.join(SRC, "phrase.occ"), encoding="utf8") as f:
        for ln in f:
            p = ln.split()
            if len(p) == 2:
                occ[p[0]] = int(p[1])
    rows = []
    seen = set()
    primary = set()
    with open(os.path.join(SRC, "BPMFBase.txt"), encoding="utf8") as f:
        for ln in f:
            p = ln.split()
            if len(p) < 3 or p[-1] != "big5":
                continue
            ch, rd = p[0], p[1]
            if len(ch) != 1 or (ch, rd) in seen:
                continue
            seen.add((ch, rd))
            n = occ.get(ch, 0)
            if ch in primary:          # 同一字的第二種以後讀音（破音）排後面
                n //= 20
            primary.add(ch)
            rows.append((ch, rd, n))
    phrases = []
    with open(os.path.join(SRC, "BPMFMappings.txt"), encoding="utf8") as f:
        for ln in f:
            p = ln.split()
            if len(p) < 3:
                continue
            w, rd = p[0], p[1:]
            if not (2 <= len(w) <= 4) or len(rd) != len(w):
                continue
            n = occ.get(w, 0)
            if n < 1:
                continue
            phrases.append((w, " ".join(rd), n))
    phrases.sort(key=lambda r: -r[2])
    kept, pseen = [], set()
    for r in phrases:
        if (r[0], r[1]) in pseen:
            continue
        pseen.add((r[0], r[1]))
        kept.append(r)
        if len(kept) >= MAX_PHRASES:
            break
    allrows = rows + kept
    allrows.sort(key=lambda r: -r[2])
    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    with open(OUT, "w", encoding="utf8", newline="\n") as f:
        f.write("# 來源：McBopomofo 小麥注音輸入法詞庫（MIT License, Copyright (c) 2011-2026 Mengjuei Hsieh et al.）\n")
        for w, rd, n in allrows:
            f.write(f"{w}\t{rd}\t{n}\n")
    print("chars", len(rows), "phrases", len(kept), "bytes", os.path.getsize(OUT))


if __name__ == "__main__":
    main()
