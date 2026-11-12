#!/usr/bin/env python3
"""Prüft vor dem Einreichen, ob der Store-Entwurf vollständig ist.

Aufruf:  uv run --with pyjwt --with cryptography python Store/tools/asc_pruefen.py <IOS|MAC_OS> <version>
Zählt je Sprache Texte, Screenshots und Vorschauen und meldet alles, was fehlt oder
noch nicht fertig verarbeitet ist (ein hängender Upload blockiert das Einreichen).
"""
import pathlib
import sys

sys.path.insert(0, str(pathlib.Path(__file__).parent))
import asc_store as asc  # noqa: E402


def main() -> int:
    platform, version = sys.argv[1], sys.argv[2]
    item = asc.need_version(platform, version)
    print("Version", item["attributes"]["versionString"], item["attributes"].get("appVersionState"))
    problems, shots, previews = [], 0, 0
    locs = asc.paged(f"/v1/appStoreVersions/{item['id']}/appStoreVersionLocalizations?limit=200")
    for loc in locs:
        a = loc["attributes"]
        for field in ("description", "keywords", "whatsNew", "promotionalText", "supportUrl"):
            if not a.get(field):
                problems.append(f"{a['locale']}: {field} fehlt")
        status, sets = asc.call("GET", f"/v1/appStoreVersionLocalizations/{loc['id']}/appScreenshotSets?include=appScreenshots&limit=50")
        kinds = {}
        states = {s["id"]: s["attributes"].get("assetDeliveryState", {}).get("state") for s in sets.get("included", [])}
        for s in sets["data"]:
            ids = [x["id"] for x in s["relationships"]["appScreenshots"]["data"]]
            kinds[s["attributes"]["screenshotDisplayType"]] = len(ids)
            shots += len(ids)
            for i in ids:
                if states.get(i) != "COMPLETE":
                    problems.append(f"{a['locale']}: Screenshot {i} im Zustand {states.get(i)}")
        status, psets = asc.call("GET", f"/v1/appStoreVersionLocalizations/{loc['id']}/appPreviewSets?include=appPreviews&limit=50")
        for p in psets.get("included", []):
            previews += 1
            state = p["attributes"].get("assetDeliveryState", {}).get("state")
            if state != "COMPLETE":
                problems.append(f"{a['locale']}: Vorschauvideo im Zustand {state} {p['attributes'].get('assetDeliveryState', {}).get('errors')}")
        if a["locale"] in ("en-US", "de-DE"):
            print(" ", a["locale"], kinds)
    status, build = asc.call("GET", f"/v1/appStoreVersions/{item['id']}/build")
    if status == 200 and build.get("data"):
        b = build["data"]["attributes"]
        print("Build", b["version"], b["processingState"])
    else:
        problems.append("kein Build zugeordnet")
    print(len(locs), "Sprachen,", shots, "Screenshots,", previews, "Vorschauvideos")
    for problem in problems:
        print("PROBLEM", problem)
    print(len(problems), "Probleme")
    return 1 if problems else 0


if __name__ == "__main__":
    sys.exit(main())
