# 眼動鼠生活日常工具
<img width="1919" height="1079" alt="image" src="https://github.com/user-attachments/assets/868ac246-69cd-4096-a686-4a19da366ae2" />
示範

https://github.com/user-attachments/assets/656db740-2e84-4200-b7c7-a40ef5de0c08




給漸凍人（ALS）與上肢不便朋友的 **3D 眼控生活工具**（Godot 4.7）：用眼睛說話、求助、表達身體感覺、注音打字、使用電腦。

- **看著就選**：立體鍵帽按鍵，看著會浮起並填滿，滿了就按下；選過一次要先移開視線才能再選（防誤觸）。
- **十種分類**：快速回答（是／不是最大顆）、緊急照護、3D 身體感覺、生活照護、問候聊天、心情感受、調整位置、打字說話、我的常用（含最近說過）、電腦工具。
- **3D 身體感覺**：看著 3D 人體上不舒服的部位，再選痛、癢、麻、酸、脹、冷、熱、抽筋，說出「我的左肩膀有點痛」，再選「幫我揉一揉」等動作。
- **眼控注音**：不用打聲調、自動分字、詞語候選、選字後聯想；也可切換英數。詞庫來自 McBopomofo 小麥注音（MIT）。
- **求助與斷電警報**：求助鈕發出警報並自動調大音量；筆電電源被拔掉時自動警報，提醒檢查呼吸器電源。
- **暫停與休息**：暫停後只有看著「繼續」三秒才恢復；休息黑畫面。
- **語音**：內建句子用 edge-tts 預錄（女聲曉臻／男聲雲哲）；照顧者新增的句子用電腦內建語音即時朗讀。
- **語音動態教學**：3D 眼動鼠一邊說明、一邊用示範游標實際操作。
- **照顧者編輯**：每個分類都能用滑鼠＋鍵盤新增、修改、刪除、排序句子。
- **程式內更新**：Windows 版自動下載安裝新版並重新開啟。

搭配 [眼動鼠](https://github.com/achir1015/eyemouse)（127.0.0.1:47961 連線，直接拿到視線座標）使用最好；沒有眼動鼠時用滑鼠位置操作。

## 開發

```bash
python -I tools/build_dict.py      # 注音詞庫 → data/bpmf.txt（需要 tools/mcbopomofo_src）
python -I tools/gen_icons.py       # 介面圖示
python -I tools/gen_sfx.py         # 音效與警報聲
python -I tools/gen_voice.py       # 預錄語音（只重做有變動的）
bash tools/build_win.sh            # Windows 安裝程式＋免安裝 zip → ../build/release
bash platform/macos/build-dmg.sh   # 在 Mac 上（專案放 ~/Developer/eyemouse-life）→ ~/Developer/eyemouse-life-build/EyeMouseLife-macOS.dmg
```

測試：`Godot --path . -- --test --no-link --selftest --out=結果.txt`；截圖 `-- --test --no-link --screen=body:shoulder_l --shot=畫面.png`。

系統開發：吳玉柱 先生 與 Claude AI Opus 5.5
