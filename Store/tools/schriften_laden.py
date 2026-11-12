#!/usr/bin/env python3
"""Lädt die Noto-Schriften für die Überschriften der Store-Bilder (alle SIL OFL 1.1).

Quelle: https://github.com/google/fonts (Ordner ofl/<familie>/). Die Dateien landen in
Store/medien/schrift/ und werden wegen ihrer Größe nicht ins Git aufgenommen
(siehe .gitignore); dieses Skript holt sie bei Bedarf neu. Inter liegt im Repository.
"""
import pathlib
import urllib.parse
import urllib.request

TARGET = pathlib.Path(__file__).resolve().parents[1] / "medien" / "schrift"
BASE = "https://github.com/google/fonts/raw/main/ofl/"

# Familienname -> (Ordner, Dateiname im Google-Fonts-Repository)
FONTS = {
    "Noto Sans Arabic": ("notosansarabic", "NotoSansArabic[wdth,wght].ttf"),
    "Noto Nastaliq Urdu": ("notonastaliqurdu", "NotoNastaliqUrdu[wght].ttf"),
    "Noto Sans Hebrew": ("notosanshebrew", "NotoSansHebrew[wdth,wght].ttf"),
    "Noto Sans Thai": ("notosansthai", "NotoSansThai[wdth,wght].ttf"),
    "Noto Sans Devanagari": ("notosansdevanagari", "NotoSansDevanagari[wdth,wght].ttf"),
    "Noto Sans Bengali": ("notosansbengali", "NotoSansBengali[wdth,wght].ttf"),
    "Noto Sans Gujarati": ("notosansgujarati", "NotoSansGujarati[wdth,wght].ttf"),
    "Noto Sans Gurmukhi": ("notosansgurmukhi", "NotoSansGurmukhi[wdth,wght].ttf"),
    "Noto Sans Kannada": ("notosanskannada", "NotoSansKannada[wdth,wght].ttf"),
    "Noto Sans Malayalam": ("notosansmalayalam", "NotoSansMalayalam[wdth,wght].ttf"),
    "Noto Sans Oriya": ("notosansoriya", "NotoSansOriya[wdth,wght].ttf"),
    "Noto Sans Tamil": ("notosanstamil", "NotoSansTamil[wdth,wght].ttf"),
    "Noto Sans Telugu": ("notosanstelugu", "NotoSansTelugu[wdth,wght].ttf"),
    "Noto Sans JP": ("notosansjp", "NotoSansJP[wght].ttf"),
    "Noto Sans KR": ("notosanskr", "NotoSansKR[wght].ttf"),
    "Noto Sans SC": ("notosanssc", "NotoSansSC[wght].ttf"),
    "Noto Sans TC": ("notosanstc", "NotoSansTC[wght].ttf"),
}


def local_name(family: str) -> str:
    return family.replace(" ", "") + ".ttf"


def main() -> None:
    TARGET.mkdir(parents=True, exist_ok=True)
    for family, (folder, name) in FONTS.items():
        out = TARGET / local_name(family)
        if out.exists() and out.stat().st_size > 10_000:
            continue
        url = BASE + folder + "/" + urllib.parse.quote(name)
        try:
            with urllib.request.urlopen(url, timeout=120) as response:
                data = response.read()
        except Exception as error:  # noqa: BLE001 - report and continue with the next family
            print("FEHLER", family, error)
            continue
        if data[:4] not in (b"\x00\x01\x00\x00", b"OTTO", b"true"):
            print("FEHLER", family, "keine Schriftdatei erhalten")
            continue
        out.write_bytes(data)
        licence = TARGET / f"OFL_{folder}.txt"
        try:
            with urllib.request.urlopen(BASE + folder + "/OFL.txt", timeout=60) as response:
                licence.write_bytes(response.read())
        except Exception as error:  # noqa: BLE001
            print("FEHLER Lizenztext", family, error)
        print(family, len(data) // 1024, "KB")


if __name__ == "__main__":
    main()
