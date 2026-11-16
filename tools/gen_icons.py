"""產生介面圖示（原創簡單線條，白色，程式裡再上色）→ assets/icons/*.svg
用法：python -I tools/gen_icons.py
"""
import os

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "assets", "icons")
HEAD = '<svg xmlns="http://www.w3.org/2000/svg" width="192" height="192" viewBox="0 0 64 64" fill="none" stroke="#fff" stroke-width="5" stroke-linecap="round" stroke-linejoin="round">'
F = 'fill="#fff" stroke="none"'

ICONS = {
    "yesno": f'<path d="M8 22 l7 7 l13 -15"/><path d="M38 36 l18 18 M56 36 l-18 18"/>',
    "cross": f'<rect x="24" y="8" width="16" height="48" rx="3" {F}/><rect x="8" y="24" width="48" height="16" rx="3" {F}/>',
    "body": f'<circle cx="32" cy="11" r="6" {F}/><path d="M32 20 v20 M18 26 l14 -4 l14 4 M32 40 l-8 18 M32 40 l8 18"/>',
    "cup": '<path d="M12 20 h32 v20 a12 12 0 0 1 -12 12 h-8 a12 12 0 0 1 -12 -12 z"/><path d="M44 26 h4 a6 6 0 0 1 0 12 h-4"/><path d="M20 6 q4 4 0 8 M30 6 q4 4 0 8"/>',
    "chat": '<path d="M10 12 h44 v28 h-24 l-12 10 v-10 h-8 z"/><path d="M20 24 h24 M20 32 h14"/>',
    "heart": f'<path d="M32 54 C10 40 6 28 10 20 C14 11 26 10 32 20 C38 10 50 11 54 20 C58 28 54 40 32 54 z" {F}/>',
    "adjust": '<rect x="8" y="10" width="48" height="30" rx="4"/><path d="M24 52 h16 M32 40 v12"/><path d="M20 25 h24 M38 19 l6 6 l-6 6"/>',
    "keyboard": '<rect x="5" y="16" width="54" height="34" rx="5"/><path d="M14 26 h2 M24 26 h2 M34 26 h2 M44 26 h4 M14 34 h2 M24 34 h2 M34 34 h2 M44 34 h4 M20 42 h24"/>',
    "star": f'<path d="M32 6 l7.6 15.6 l17.2 2.4 l-12.4 12 l3 17 l-15.4 -8.2 l-15.4 8.2 l3 -17 l-12.4 -12 l17.2 -2.4 z" {F}/>',
    "gear": '<circle cx="32" cy="32" r="9"/><path d="M32 6 v8 M32 50 v8 M6 32 h8 M50 32 h8 M13.6 13.6 l5.6 5.6 M44.8 44.8 l5.6 5.6 M13.6 50.4 l5.6 -5.6 M44.8 19.2 l5.6 -5.6"/><circle cx="32" cy="32" r="18"/>',
    "bell": f'<path d="M32 8 a16 16 0 0 1 16 16 v12 l6 8 h-44 l6 -8 v-12 a16 16 0 0 1 16 -16 z" {F}/><circle cx="32" cy="52" r="5" {F}/>',
    "speaker": f'<path d="M8 24 h10 l14 -12 v40 l-14 -12 h-10 z" {F}/><path d="M40 22 q6 10 0 20 M47 15 q12 17 0 34"/>',
    "backspace": '<path d="M22 14 h34 v36 h-34 l-16 -18 z"/><path d="M30 24 l14 16 M44 24 l-14 16"/>',
    "trash": '<path d="M10 16 h44 M24 16 v-6 h16 v6 M16 16 l3 40 h26 l3 -40"/><path d="M27 26 v20 M37 26 v20"/>',
    "pause": f'<rect x="14" y="10" width="12" height="44" rx="3" {F}/><rect x="38" y="10" width="12" height="44" rx="3" {F}/>',
    "play": f'<path d="M16 8 l38 24 l-38 24 z" {F}/>',
    "up": '<path d="M32 54 v-42 M14 28 l18 -18 l18 18"/>',
    "down": '<path d="M32 10 v42 M14 36 l18 18 l18 -18"/>',
    "left": '<path d="M54 32 h-42 M28 14 l-18 18 l18 18"/>',
    "right": '<path d="M10 32 h42 M36 14 l18 18 l-18 18"/>',
    "moon": f'<path d="M40 6 A26 26 0 1 0 58 40 A20 20 0 1 1 40 6 z" {F}/>',
    "desktop": '<rect x="6" y="10" width="52" height="34" rx="4"/><path d="M22 54 h20 M32 44 v10"/><path d="M14 36 h10"/>',
    "vol_up": f'<path d="M6 24 h8 l12 -10 v36 l-12 -10 h-8 z" {F}/><path d="M36 32 h20 M46 22 v20"/>',
    "vol_down": f'<path d="M6 24 h8 l12 -10 v36 l-12 -10 h-8 z" {F}/><path d="M36 32 h20"/>',
    "mute": f'<path d="M6 24 h8 l12 -10 v36 l-12 -10 h-8 z" {F}/><path d="M38 24 l16 16 M54 24 l-16 16"/>',
    "edit": '<path d="M42 8 l14 14 l-30 30 h-14 v-14 z M36 14 l14 14"/>',
    "plus": '<path d="M32 10 v44 M10 32 h44"/>',
    "check": '<path d="M10 34 l14 14 l30 -32"/>',
    "close": '<path d="M14 14 l36 36 M50 14 l-36 36"/>',
    "power": '<path d="M32 6 v24"/><path d="M18 14 a22 22 0 1 0 28 0"/>',
    "book": '<path d="M32 14 q-10 -6 -24 -4 v40 q14 -2 24 4 q10 -6 24 -4 v-40 q-14 -2 -24 4 z M32 14 v40"/>',
    "refresh": '<path d="M52 20 a22 22 0 1 0 2 18"/><path d="M54 8 v14 h-14"/>',
    "info": f'<circle cx="32" cy="32" r="24"/><circle cx="32" cy="19" r="3.5" {F}/><path d="M32 29 v18"/>',
    "rotate": '<path d="M10 32 a22 22 0 0 1 40 -12"/><path d="M52 8 v14 h-14"/><path d="M54 32 a22 22 0 0 1 -40 12"/><path d="M12 56 v-14 h14"/>',
    "history": '<path d="M10 32 a22 22 0 1 0 6 -15"/><path d="M8 8 v12 h12"/><path d="M32 18 v14 l10 6"/>',
    "save": '<path d="M10 10 h36 l8 8 v36 h-44 z"/><path d="M20 10 v14 h22 v-14 M20 54 v-16 h24 v16"/>',
    "eye": f'<path d="M4 32 q28 -30 56 0 q-28 30 -56 0 z"/><circle cx="32" cy="32" r="9" {F}/>',
    "home": '<path d="M8 30 l24 -20 l24 20"/><path d="M14 26 v28 h36 v-28"/><path d="M27 54 v-14 h10 v14"/>',
    "clock": '<circle cx="32" cy="32" r="24"/><path d="M32 16 v16 l12 8"/>',
    "sun": f'<circle cx="32" cy="32" r="11" {F}/><path d="M32 4 v8 M32 52 v8 M4 32 h8 M52 32 h8 M12 12 l6 6 M46 46 l6 6 M12 52 l6 -6 M46 18 l6 -6"/>',
    "voice": f'<rect x="24" y="6" width="16" height="30" rx="8" {F}/><path d="M14 30 a18 18 0 0 0 36 0 M32 48 v10 M22 58 h20"/>',
    "space": '<path d="M8 30 v12 h48 v-12"/>',
    "enter": '<path d="M52 12 v20 h-40 M24 20 l-12 12 l12 12"/>',
    "front": f'<circle cx="32" cy="12" r="7" {F}/><path d="M32 22 v20 M18 28 l14 -4 l14 4 M32 42 l-8 16 M32 42 l8 16"/><circle cx="29" cy="11" r="1.5" fill="#000" stroke="none"/><circle cx="35" cy="11" r="1.5" fill="#000" stroke="none"/>',
    "back": f'<circle cx="32" cy="12" r="7" {F}/><path d="M32 22 v20 M18 28 l14 -4 l14 4 M32 42 l-8 16 M32 42 l8 16 M26 30 h12"/>',
    "calib": '<circle cx="32" cy="32" r="22"/><circle cx="32" cy="32" r="10"/><path d="M32 2 v12 M32 50 v12 M2 32 h12 M50 32 h12"/>',
}


def main():
    os.makedirs(OUT, exist_ok=True)
    for name, body in ICONS.items():
        with open(os.path.join(OUT, name + ".svg"), "w", encoding="utf8") as f:
            f.write(HEAD + body + "</svg>\n")
    print(len(ICONS), "icons")


if __name__ == "__main__":
    main()
