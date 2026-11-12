#!/usr/bin/env python3
"""Baut die gestalteten App-Store-Bilder aus echten Screenshots der App.

Machart: Die Vorlage store_bild.html (Überschrift oben, echter Screenshot mit runden
Ecken, hellem Ring und Schatten, dahinter das Licht in der Farbe des Motivs) wird mit
Google Chrome ohne Fenster in der Zielgröße gerendert. Danach wird das Bild ohne
Transparenz als RGB-PNG gespeichert (Apple lehnt Bilder mit Alphakanal ab).

Aufruf (vom Projektordner aus):
  python3 Store/tools/store_bilder.py <roh-ordner> <ziel-ordner> [sprache ...]

Roh-Ordner:   <roh>/<sprache>/<geraet>/<NN>.png   (echte Aufnahmen, z. B. de/iphone/01.png)
Ziel-Ordner:  <ziel>/<asc-locale>/<APP_IPHONE_67|APP_IPAD_PRO_3GEN_129|APP_DESKTOP>/<NN>.png
Überschriften: Store/lokalisierung/<sprache>.json unter "shots" (Liste, eine je Motiv).
"""
import json
import pathlib
import subprocess
import sys
import urllib.parse

ROOT = pathlib.Path(__file__).resolve().parents[2]
TEMPLATE = ROOT / "Store" / "tools" / "store_bild.html"
LOC = ROOT / "Store" / "lokalisierung"
CHROME = "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"

sys.path.insert(0, str(pathlib.Path(__file__).parent))
from asc_locales import LOCALES  # noqa: E402

# Zielgröße, Eckenradius des Screenshots (Anteil seiner Breite), Bildersatz in App Store Connect.
DEVICES = {
    "iphone": {"size": (1320, 2868), "radius": 0.115, "set": "APP_IPHONE_67"},
    "ipad": {"size": (2064, 2752), "radius": 0.035, "set": "APP_IPAD_PRO_3GEN_129"},
    "mac": {"size": (2880, 1800), "radius": 0.022, "set": "APP_DESKTOP"},
}
# Lichtfarbe hinter dem Screenshot, passend zum Motiv.
GLOW = ["ffd199", "b24dff", "ff8a2a", "0d66ff", "ff2a2a"]
RTL = {"ar", "he", "ur"}
# Schriften für Schriftsysteme, die Inter nicht abdeckt (alle unter SIL OFL, siehe Store/medien/schrift).
FONTS = {
    "ar": "Noto Sans Arabic", "ur": "Noto Nastaliq Urdu", "he": "Noto Sans Hebrew", "th": "Noto Sans Thai",
    "hi": "Noto Sans Devanagari", "mr": "Noto Sans Devanagari", "bn": "Noto Sans Bengali",
    "gu": "Noto Sans Gujarati", "pa": "Noto Sans Gurmukhi", "kn": "Noto Sans Kannada",
    "ml": "Noto Sans Malayalam", "or": "Noto Sans Oriya", "ta": "Noto Sans Tamil", "te": "Noto Sans Telugu",
    "ja": "Noto Sans JP", "ko": "Noto Sans KR", "zh-Hans": "Noto Sans SC", "zh-Hant": "Noto Sans TC",
}


# Zeilenhöhe für Schriften mit hohen Ober- und Unterlängen.
TALL = {"ur": 1.9, "ar": 1.35, "th": 1.35, "hi": 1.3, "mr": 1.3, "bn": 1.3, "gu": 1.3, "pa": 1.3,
        "kn": 1.3, "ml": 1.3, "or": 1.3, "ta": 1.3, "te": 1.3}


def render(shot: pathlib.Path, out: pathlib.Path, text: str, device: dict, glow: str, language: str) -> None:
    width, height = device["size"]
    query = urllib.parse.urlencode({
        "w": width, "h": height, "radius": device["radius"], "glow": glow, "text": text,
        "lang": language, "dir": "rtl" if language in RTL else "ltr",
        "font": FONTS.get(language, ""),
        "fontfile": FONTS[language].replace(" ", "") + ".ttf" if language in FONTS else "",
        "lh": TALL.get(language, 1.12), "shot": shot.resolve().as_uri()})
    out.parent.mkdir(parents=True, exist_ok=True)
    raw = out.with_suffix(".raw.png")
    subprocess.run([
        CHROME, "--headless=new", "--disable-gpu", "--hide-scrollbars", "--force-device-scale-factor=1",
        f"--window-size={width},{height}", "--allow-file-access-from-files", "--virtual-time-budget=5000",
        "--no-first-run", "--disable-extensions", f"--screenshot={raw}", f"{TEMPLATE.as_uri()}?{query}",
    ], check=True, timeout=180, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    # RGB ohne Alphakanal; sips ist Bestandteil von macOS.
    subprocess.run(["sips", "-s", "format", "jpeg", "-s", "formatOptions", "100", str(raw), "--out",
                    str(raw.with_suffix(".jpg"))], check=True, stdout=subprocess.DEVNULL)
    subprocess.run(["sips", "-s", "format", "png", str(raw.with_suffix(".jpg")), "--out", str(out)],
                   check=True, stdout=subprocess.DEVNULL)
    raw.unlink()
    raw.with_suffix(".jpg").unlink()


def main() -> int:
    if len(sys.argv) < 3:
        print(__doc__)
        return 1
    raw_root, out_root = pathlib.Path(sys.argv[1]), pathlib.Path(sys.argv[2])
    wanted = sys.argv[3:] or sorted(p.name for p in raw_root.iterdir() if p.is_dir())
    english = json.loads((LOC / "en.json").read_text(encoding="utf-8"))["shots"]
    count = 0
    for language in wanted:
        source = LOC / f"{language}.json"
        base = language if source.exists() else "en"
        heads = json.loads((LOC / f"{base}.json").read_text(encoding="utf-8")).get("shots") or english
        for name, device in DEVICES.items():
            for shot in sorted((raw_root / language / name).glob("[0-9][0-9].png")):
                index = int(shot.stem) - 1
                out = out_root / LOCALES[language] / device["set"] / shot.name
                render(shot, out, heads[index], device, GLOW[index % len(GLOW)], language)
                count += 1
        print(language, "fertig", flush=True)
    print(count, "Bilder")
    return 0


if __name__ == "__main__":
    sys.exit(main())
