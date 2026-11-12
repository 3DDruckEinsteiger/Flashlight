#!/usr/bin/env python3
"""Builds Screenlight/Localizable.xcstrings from Store/lokalisierung/<code>.json.

Each language file has two parts: "ui" (app texts, keyed by the English text)
and "store" (App Store texts). English is the source language. The three
English variants (GB, AU, CA) are derived from en.json by spelling rules.

Usage:  python3 Store/tools/build_strings.py          (run from the repository root)
It also checks the App Store length limits and updates knownRegions in the Xcode project.
"""
import json
import pathlib
import re
import sys

ROOT = pathlib.Path(__file__).resolve().parents[2]
LOC = ROOT / "Store" / "lokalisierung"
CATALOG = ROOT / "Screenlight" / "Localizable.xcstrings"
PROJECT = ROOT / "Screenlight.xcodeproj" / "project.pbxproj"

LIMITS = {"subtitle": 30, "promo": 170, "keywords": 100, "description": 4000, "whatsnew": 4000}
BRITISH = [("color", "colour"), ("Color", "Colour"), ("COLOR", "COLOUR"),
           ("favorite", "favourite"), ("Favorite", "Favourite")]


def british(text: str) -> str:
    for american, uk in BRITISH:
        text = text.replace(american, uk)
    return text


def load() -> dict:
    languages = {}
    for path in sorted(LOC.glob("*.json")):
        languages[path.stem] = json.loads(path.read_text(encoding="utf-8"))
    english = languages["en"]
    for code in ("en-GB", "en-AU", "en-CA"):
        if code in languages:
            continue
        store = {k: british(v) for k, v in english["store"].items()}
        if code != "en-CA":
            # "torch" is the everyday word there; lead with it.
            store["keywords"] = store["keywords"].replace("flashlight,torch", "torch,flashlight")
        languages[code] = {"ui": {k: british(v) for k, v in english["ui"].items()}, "store": store}
    return languages


def check(languages: dict) -> list:
    problems = []
    keys = set(languages["en"]["ui"])
    for code, data in languages.items():
        ui = data.get("ui", {})
        if set(ui) != keys:
            problems.append(f"{code}: ui keys differ: missing {sorted(keys - set(ui))} extra {sorted(set(ui) - keys)}")
        for key, value in ui.items():
            if not isinstance(value, str) or not value.strip():
                problems.append(f"{code}: empty ui value for {key!r}")
        for field, limit in LIMITS.items():
            value = data.get("store", {}).get(field, "")
            if not value.strip():
                problems.append(f"{code}: store.{field} missing")
            elif len(value) > limit:
                problems.append(f"{code}: store.{field} has {len(value)} characters (limit {limit})")
        if re.search(r"[‎‏‪-‮⁦-⁩]", json.dumps(data, ensure_ascii=False)):
            problems.append(f"{code}: contains directional control characters")
    return problems


def write_catalog(languages: dict) -> None:
    strings = {}
    for key in sorted(languages["en"]["ui"]):
        localizations = {}
        for code in sorted(languages):
            value = languages[code]["ui"][key]
            if code == "en":
                if value == key:
                    continue
            localizations[code] = {"stringUnit": {"state": "translated", "value": value}}
        strings[key] = {"localizations": localizations} if localizations else {}
    catalog = {"sourceLanguage": "en", "strings": strings, "version": "1.0"}
    CATALOG.write_text(json.dumps(catalog, ensure_ascii=False, indent=2, sort_keys=True) + "\n", encoding="utf-8")


def write_regions(languages: dict) -> None:
    text = PROJECT.read_text(encoding="utf-8")
    regions = ["en", "Base"] + sorted(code for code in languages if code != "en")
    block = "knownRegions = (\n" + "".join(f'\t\t\t\t"{r}",\n' if "-" in r else f"\t\t\t\t{r},\n" for r in regions) + "\t\t\t);"
    text = re.sub(r"knownRegions = \(\n.*?\n\t\t\t\);", lambda _: block, text, flags=re.S)
    PROJECT.write_text(text, encoding="utf-8")


def main() -> int:
    languages = load()
    problems = check(languages)
    for problem in problems:
        print("PROBLEM", problem)
    if problems:
        return 1
    write_catalog(languages)
    write_regions(languages)
    print(f"{len(languages)} languages, {len(languages['en']['ui'])} texts -> {CATALOG.relative_to(ROOT)}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
