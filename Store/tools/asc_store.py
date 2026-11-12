#!/usr/bin/env python3
"""App Store Connect helper for Screenlight Mobile.

Reads the API key from ~/.claude/.appstoreconnect.env (ASC_ISSUER_ID, ASC_KEY_ID,
ASC_KEY_PATH). Nothing secret is stored in this repository.

Run with:  uv run --with pyjwt --with cryptography python Store/tools/asc_store.py <command>

Commands
  status                          versions, builds and review state
  version  <IOS|MAC_OS> <1.1>     create the version if it does not exist yet
  texts    <IOS|MAC_OS> <1.1>     upload name/subtitle and all store texts for every language
  media    <IOS|MAC_OS> <1.1> <folder>   upload screenshots/previews from <folder>/<locale>/<DISPLAY_TYPE>/*
  build    <IOS|MAC_OS> <1.1> <build>    attach an uploaded build to the version
  submit   <IOS|MAC_OS> <1.1>     hand the version to App Review
"""
import hashlib
import json
import os
import pathlib
import sys
import time
import urllib.error
import urllib.request

import jwt

APP_ID = "6758013532"
APP_NAME = "Screenlight Mobile"
ROOT = pathlib.Path(__file__).resolve().parents[2]
LOC = ROOT / "Store" / "lokalisierung"
API = "https://api.appstoreconnect.apple.com"

sys.path.insert(0, str(pathlib.Path(__file__).parent))
from asc_locales import LOCALES  # noqa: E402
SUPPORT_URL = "https://github.com/3DDruckEinsteiger/Flashlight"
PRIVACY_URL = "https://github.com/3DDruckEinsteiger/Flashlight/blob/main/PRIVACY_POLICY.md"


def _env() -> dict:
    values = {}
    for line in open(os.path.expanduser("~/.claude/.appstoreconnect.env"), encoding="utf-8"):
        line = line.strip()
        if "=" in line and not line.startswith("#"):
            key, value = line.split("=", 1)
            values[key.replace("export ", "").strip()] = value.strip().strip('"').strip("'")
    return values


ENV = _env()


def token() -> str:
    key = open(os.path.expanduser(ENV["ASC_KEY_PATH"]), encoding="utf-8").read()
    now = int(time.time())
    return jwt.encode({"iss": ENV["ASC_ISSUER_ID"], "iat": now, "exp": now + 900, "aud": "appstoreconnect-v1"},
                      key, algorithm="ES256", headers={"kid": ENV["ASC_KEY_ID"]})


def call(method: str, path: str, body=None, retries: int = 4):
    url = path if path.startswith("http") else API + path
    data = json.dumps(body).encode() if body is not None else None
    for attempt in range(retries):
        request = urllib.request.Request(url, data=data, method=method, headers={
            "Authorization": "Bearer " + token(), "Content-Type": "application/json"})
        try:
            with urllib.request.urlopen(request, timeout=90) as response:
                raw = response.read()
                return response.status, (json.loads(raw) if raw else None)
        except urllib.error.HTTPError as error:
            raw = error.read()
            if error.code in (429, 500, 502, 503, 504) and attempt < retries - 1:
                time.sleep(3 * (attempt + 1))
                continue
            try:
                return error.code, json.loads(raw)
            except ValueError:
                return error.code, raw.decode(errors="replace")
        except (urllib.error.URLError, TimeoutError):
            if attempt == retries - 1:
                raise
            time.sleep(3 * (attempt + 1))
    raise RuntimeError("unreachable")


def errors(payload) -> str:
    if isinstance(payload, dict) and "errors" in payload:
        return "; ".join(f"{e.get('code')}: {e.get('detail')}" for e in payload["errors"])
    return str(payload)[:400]


def paged(path: str) -> list:
    items = []
    while path:
        status, payload = call("GET", path)
        if status != 200:
            raise SystemExit(f"GET {path} -> {status} {errors(payload)}")
        items += payload["data"]
        path = payload.get("links", {}).get("next")
    return items


def languages() -> dict:
    sys.path.insert(0, str(pathlib.Path(__file__).parent))
    import build_strings
    loaded = build_strings.load()
    problems = build_strings.check(loaded)
    if problems:
        raise SystemExit("\n".join(problems))
    return loaded


def find_version(platform: str, version: str):
    for item in paged(f"/v1/apps/{APP_ID}/appStoreVersions?filter[platform]={platform}&limit=50"):
        if item["attributes"]["versionString"] == version:
            return item
    return None


def need_version(platform: str, version: str) -> dict:
    found = find_version(platform, version)
    if not found:
        raise SystemExit(f"version {version} for {platform} does not exist; run 'version' first")
    return found


# MARK: - Commands

def cmd_status() -> None:
    for item in paged(f"/v1/apps/{APP_ID}/appStoreVersions?limit=50"):
        a = item["attributes"]
        print("VERSION", a["platform"], a["versionString"], a.get("appVersionState"), item["id"])
    status, builds = call("GET", f"/v1/builds?filter[app]={APP_ID}&limit=10&sort=-uploadedDate&include=preReleaseVersion")
    included = {i["id"]: i["attributes"] for i in builds.get("included", [])}
    for item in builds["data"]:
        a = item["attributes"]
        pre = item["relationships"]["preReleaseVersion"]["data"]
        p = included.get(pre["id"], {}) if pre else {}
        print("BUILD", p.get("platform"), p.get("version"), a["version"], a["processingState"], a["uploadedDate"], item["id"])
    status, subs = call("GET", f"/v1/reviewSubmissions?filter[app]={APP_ID}&limit=10")
    for item in subs.get("data", []):
        a = item["attributes"]
        print("REVIEW", a.get("platform"), a.get("state"), a.get("submittedDate"), item["id"])


def cmd_version(platform: str, version: str) -> None:
    if find_version(platform, version):
        print("exists")
        return
    status, payload = call("POST", "/v1/appStoreVersions", {"data": {
        "type": "appStoreVersions",
        "attributes": {"platform": platform, "versionString": version, "releaseType": "AFTER_APPROVAL",
                       "copyright": "© 2026 Axel Mammitzsch"},
        "relationships": {"app": {"data": {"type": "apps", "id": APP_ID}}}}})
    print(status, "created" if status == 201 else errors(payload))


def cmd_texts(platform: str, version: str) -> None:
    langs = languages()
    item = need_version(platform, version)
    existing = {l["attributes"]["locale"]: l for l in
                paged(f"/v1/appStoreVersions/{item['id']}/appStoreVersionLocalizations?limit=200")}
    failed = []
    for code, locale in sorted(LOCALES.items()):
        store = langs[code]["store"]
        attributes = {"description": store["description"], "keywords": store["keywords"],
                      "promotionalText": store["promo"], "whatsNew": store["whatsnew"],
                      "supportUrl": SUPPORT_URL}
        if locale in existing:
            status, payload = call("PATCH", f"/v1/appStoreVersionLocalizations/{existing[locale]['id']}", {"data": {
                "type": "appStoreVersionLocalizations", "id": existing[locale]["id"], "attributes": attributes}})
        else:
            status, payload = call("POST", "/v1/appStoreVersionLocalizations", {"data": {
                "type": "appStoreVersionLocalizations", "attributes": dict(attributes, locale=locale),
                "relationships": {"appStoreVersion": {"data": {"type": "appStoreVersions", "id": item["id"]}}}}})
        if status not in (200, 201):
            failed.append(f"{locale} version texts: {status} {errors(payload)}")

    # Name, subtitle and privacy policy live on the app info that is still editable.
    infos = paged(f"/v1/apps/{APP_ID}/appInfos")
    editable = [i for i in infos if i["attributes"].get("state") not in ("READY_FOR_DISTRIBUTION",)] or infos
    info = editable[0]
    info_locs = {l["attributes"]["locale"]: l for l in
                 paged(f"/v1/appInfos/{info['id']}/appInfoLocalizations?limit=200")}
    for code, locale in sorted(LOCALES.items()):
        attributes = {"name": APP_NAME, "subtitle": langs[code]["store"]["subtitle"], "privacyPolicyUrl": PRIVACY_URL}
        if locale in info_locs:
            status, payload = call("PATCH", f"/v1/appInfoLocalizations/{info_locs[locale]['id']}", {"data": {
                "type": "appInfoLocalizations", "id": info_locs[locale]["id"], "attributes": attributes}})
        else:
            status, payload = call("POST", "/v1/appInfoLocalizations", {"data": {
                "type": "appInfoLocalizations", "attributes": dict(attributes, locale=locale),
                "relationships": {"appInfo": {"data": {"type": "appInfos", "id": info["id"]}}}}})
        if status not in (200, 201):
            failed.append(f"{locale} name/subtitle: {status} {errors(payload)}")
    print(f"{len(LOCALES)} locales processed, {len(failed)} problems")
    for line in failed:
        print("PROBLEM", line)


def _upload(asset: dict, path: pathlib.Path) -> None:
    data = path.read_bytes()
    for operation in asset["attributes"]["uploadOperations"]:
        chunk = data[operation["offset"]:operation["offset"] + operation["length"]]
        request = urllib.request.Request(operation["url"], data=chunk, method=operation["method"],
                                         headers={h["name"]: h["value"] for h in operation["requestHeaders"]})
        with urllib.request.urlopen(request, timeout=300) as response:
            response.read()


def cmd_media(platform: str, version: str, folder: str) -> None:
    """Folder layout: <folder>/<asc-locale>/<APP_IPHONE_67|APP_IPAD_PRO_3GEN_129|APP_DESKTOP|...>/NN_name.png
    Previews: <folder>/<asc-locale>/preview_<IPHONE_67|IPAD_PRO_3GEN_129|DESKTOP>/NN_name.mp4"""
    item = need_version(platform, version)
    base = pathlib.Path(folder)
    locs = {l["attributes"]["locale"]: l for l in
            paged(f"/v1/appStoreVersions/{item['id']}/appStoreVersionLocalizations?limit=200")}
    failed = []
    for locale_dir in sorted(p for p in base.iterdir() if p.is_dir()):
        loc = locs.get(locale_dir.name)
        if not loc:
            failed.append(f"{locale_dir.name}: no such localization on this version")
            continue
        wanted = [p for p in sorted(locale_dir.iterdir()) if p.is_dir()
                  and ("DESKTOP" in p.name) == (platform == "MAC_OS")]
        # Screenshot sets copied over from the previous version (old interface) must go.
        keep = {p.name for p in wanted if not p.name.startswith("preview_")}
        for old_set in paged(f"/v1/appStoreVersionLocalizations/{loc['id']}/appScreenshotSets?limit=50"):
            if keep and old_set["attributes"]["screenshotDisplayType"] not in keep:
                call("DELETE", f"/v1/appScreenshotSets/{old_set['id']}")
        for type_dir in wanted:
            is_preview = type_dir.name.startswith("preview_")
            kind = type_dir.name.replace("preview_", "")
            set_type, item_type = ("appPreviewSets", "appPreviews") if is_preview else ("appScreenshotSets", "appScreenshots")
            type_key = "previewType" if is_preview else "screenshotDisplayType"
            sets = paged(f"/v1/appStoreVersionLocalizations/{loc['id']}/{set_type}?limit=50")
            current = next((s for s in sets if s["attributes"][type_key] == kind), None)
            if current:
                # Replace what is there, so a re-run never duplicates images.
                for old in paged(f"/v1/{set_type}/{current['id']}/{item_type}?limit=50"):
                    call("DELETE", f"/v1/{item_type}/{old['id']}")
            else:
                status, payload = call("POST", f"/v1/{set_type}", {"data": {
                    "type": set_type, "attributes": {type_key: kind},
                    "relationships": {"appStoreVersionLocalization": {
                        "data": {"type": "appStoreVersionLocalizations", "id": loc["id"]}}}}})
                if status != 201:
                    failed.append(f"{locale_dir.name}/{type_dir.name}: {status} {errors(payload)}")
                    continue
                current = payload["data"]
            for file in sorted(p for p in type_dir.iterdir() if p.suffix.lower() in (".png", ".jpg", ".mp4", ".mov")):
                attributes = {"fileName": file.name, "fileSize": file.stat().st_size}
                if is_preview:
                    attributes["mimeType"] = "video/mp4" if file.suffix.lower() == ".mp4" else "video/quicktime"
                status, payload = call("POST", f"/v1/{item_type}", {"data": {
                    "type": item_type, "attributes": attributes,
                    "relationships": {set_type[:-1]: {"data": {"type": set_type, "id": current["id"]}}}}})
                if status != 201:
                    failed.append(f"{file}: {status} {errors(payload)}")
                    continue
                asset = payload["data"]
                _upload(asset, file)
                status, payload = call("PATCH", f"/v1/{item_type}/{asset['id']}", {"data": {
                    "type": item_type, "id": asset["id"],
                    "attributes": {"uploaded": True, "sourceFileChecksum": hashlib.md5(file.read_bytes()).hexdigest()}}})
                if status != 200:
                    failed.append(f"{file}: commit {status} {errors(payload)}")
        print("uploaded", locale_dir.name, flush=True)
    for line in failed:
        print("PROBLEM", line)
    print(f"done, {len(failed)} problems")


def cmd_build(platform: str, version: str, build_number: str) -> None:
    item = need_version(platform, version)
    builds = paged(f"/v1/builds?filter[app]={APP_ID}&filter[version]={build_number}"
                   f"&filter[preReleaseVersion.platform]={platform}&filter[preReleaseVersion.version]={version}&limit=10")
    if not builds:
        raise SystemExit("build not found (still processing?)")
    build = builds[0]
    print("build", build["id"], build["attributes"]["processingState"])
    if build["attributes"]["processingState"] != "VALID":
        raise SystemExit("build is not ready yet")
    if build["attributes"].get("usesNonExemptEncryption") is None:
        # The app contains no encryption of its own.
        status, payload = call("PATCH", f"/v1/builds/{build['id']}", {"data": {
            "type": "builds", "id": build["id"], "attributes": {"usesNonExemptEncryption": False}}})
        print("encryption declaration", status, "" if status == 200 else errors(payload))
    status, payload = call("PATCH", f"/v1/appStoreVersions/{item['id']}/relationships/build",
                           {"data": {"type": "builds", "id": build["id"]}})
    print("attach", status, "" if status == 204 else errors(payload))


def cmd_submit(platform: str, version: str) -> None:
    item = need_version(platform, version)
    open_states = ("READY_FOR_REVIEW", "WAITING_FOR_REVIEW", "IN_REVIEW", "UNRESOLVED_ISSUES")
    submissions = paged(f"/v1/reviewSubmissions?filter[app]={APP_ID}&filter[platform]={platform}&limit=20")
    submission = next((s for s in submissions if s["attributes"]["state"] == "READY_FOR_REVIEW"), None)
    busy = [s for s in submissions if s["attributes"]["state"] in open_states[1:]]
    if busy:
        raise SystemExit(f"a submission is already open: {busy[0]['attributes']['state']}")
    if not submission:
        status, payload = call("POST", "/v1/reviewSubmissions", {"data": {
            "type": "reviewSubmissions", "attributes": {"platform": platform},
            "relationships": {"app": {"data": {"type": "apps", "id": APP_ID}}}}})
        if status != 201:
            raise SystemExit(f"create submission: {status} {errors(payload)}")
        submission = payload["data"]
    status, payload = call("POST", "/v1/reviewSubmissionItems", {"data": {
        "type": "reviewSubmissionItems",
        "relationships": {"reviewSubmission": {"data": {"type": "reviewSubmissions", "id": submission["id"]}},
                          "appStoreVersion": {"data": {"type": "appStoreVersions", "id": item["id"]}}}}})
    if status not in (201, 409):
        raise SystemExit(f"add version: {status} {errors(payload)}")
    if status == 409:
        print("note:", errors(payload))
    status, payload = call("PATCH", f"/v1/reviewSubmissions/{submission['id']}", {"data": {
        "type": "reviewSubmissions", "id": submission["id"], "attributes": {"submitted": True}}})
    print("submit", status, payload["data"]["attributes"] if status == 200 else errors(payload))


def main() -> None:
    args = sys.argv[1:]
    if not args:
        raise SystemExit(__doc__)
    commands = {"status": cmd_status, "version": cmd_version, "texts": cmd_texts,
                "media": cmd_media, "build": cmd_build, "submit": cmd_submit}
    if args[0] not in commands:
        raise SystemExit(__doc__)
    commands[args[0]](*args[1:])


if __name__ == "__main__":
    main()
