#!/usr/bin/env python3
"""Customize web/loading.html: embed Mushroom Garrison key art + logo and restyle.
Re-runnable: replaces the embedded background payload and the style/title block."""
import base64, io, re
from pathlib import Path
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
SHELL = ROOT / "web/loading.html"
ART = ROOT / "assets/mg/ui/title_art.jpg"
LOGO = ROOT / "assets/mg/ui/logo.png"


def data_url(img: Image.Image, fmt: str, **kw) -> str:
    buf = io.BytesIO()
    img.save(buf, fmt, **kw)
    mime = {"WEBP": "image/webp", "JPEG": "image/jpeg"}[fmt]
    return f"data:{mime};base64," + base64.b64encode(buf.getvalue()).decode()


art = Image.open(ART).convert("RGB")
art.thumbnail((1280, 720))
art_url = data_url(art, "WEBP", quality=58, method=6)
logo = Image.open(LOGO).convert("RGBA")
logo.thumbnail((560, 300))
logo_url = data_url(logo, "WEBP", quality=80, method=6)

s = SHELL.read_text()
# 1) background art payload
s, n = re.subn(r'(#loading::before \{[^}]*?background: url\(")[^"]+("\))', lambda m: m.group(1) + art_url + m.group(2), s, count=1)
assert n == 1, "background payload not found"
# 2) palette + logo styling
repl = {
    "background: #0b1b18; color: #f5efdb;": "background: #1d2616; color: #fbf1d8;",
    "background: #0b1b18; isolation: isolate;": "background: #1d2616; isolation: isolate;",
    "background: linear-gradient(180deg, rgba(5,18,15,.02) 35%, rgba(5,18,15,.30) 66%, rgba(5,18,15,.88) 100%)":
        "background: linear-gradient(180deg, rgba(29,38,22,0) 40%, rgba(29,38,22,.35) 70%, rgba(24,18,8,.85) 100%)",
    "border: 1px solid rgba(220,192,120,.32); border-radius: 20px; background: rgba(10,31,26,.87);":
        "border: 3px solid #4a3218; border-radius: 22px; background: rgba(251,241,216,.94); color: #4a3218;",
    "color: #f1d28a; overflow-wrap": "color: #c9503f; overflow-wrap",
    "progress::-webkit-progress-bar { background: #29453b; }": "progress::-webkit-progress-bar { background: #e2d2ac; }",
    "#loading-status, #loading-notice { color: #e1e6d3; }": "#loading-status, #loading-notice { color: #6b4a2b; }",
    "button { padding: 10px 24px; border: 1px solid #a99563; border-radius: 10px; background: #223e32; color: #f7e6b6;":
        "button { padding: 10px 24px; border: 3px solid #4a3218; border-radius: 12px; background: #e0634f; color: #fff7e6;",
}
for a, b in repl.items():
    if a in s:
        s = s.replace(a, b)
s = s.replace("accent-color: #eec66f;", "accent-color: #e8a93a;")
s = s.replace("progress::-webkit-progress-value { background: #eec66f; }", "progress::-webkit-progress-value { background: #e8a93a; }")
s = s.replace("progress::-moz-progress-bar { background: #eec66f; }", "progress::-moz-progress-bar { background: #e8a93a; }")
# logo image above the (visually small) title text
logo_css = "    #game-logo { width: min(420px, 70vw); height: auto; margin-top: -86px; filter: drop-shadow(0 6px 10px rgba(0,0,0,.35)); }\n    @media (max-height: 480px) { #game-logo { width: min(260px, 40vw); margin-top: -40px; } }\n"
s = re.sub(r"    #game-logo \{.*\n(    @media \(max-height: 480px\) \{ #game-logo.*\n)?", "", s)
s = s.replace("  </style>\n</head>", logo_css + "  </style>\n</head>", 1)
s = re.sub(r'    <img id="game-logo"[^>]*>\n', "", s)
s = s.replace('    <h1 id="game-title"></h1>', f'    <img id="game-logo" alt="" src="{logo_url}">\n    <h1 id="game-title"></h1>', 1)
s = s.replace(".loading-copy { box-sizing: border-box; display: grid; justify-items: center; gap: 12px; width: min(680px, 100%);",
              ".loading-copy { box-sizing: border-box; display: grid; justify-items: center; gap: 12px; width: min(560px, 100%);")
SHELL.write_text(s)
print("loader bytes", len(s), "art", len(art_url), "logo", len(logo_url))
