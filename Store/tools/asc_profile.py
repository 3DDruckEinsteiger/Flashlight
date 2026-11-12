#!/usr/bin/env python3
"""Legt App-Store-Provisioning-Profile für Screenlight Mobile an und installiert sie lokal.

Nötig, wenn Xcode nicht mit einem Entwicklerkonto angemeldet ist und der API-Schlüssel keine
Cloud-Signierung darf: Dann wird von Hand mit dem lokalen Zertifikat „Apple Distribution“ signiert,
und das Profil muss genau dieses Zertifikat enthalten.

Aufruf:  uv run --with pyjwt --with cryptography python Store/tools/asc_profile.py
Ergebnis: Profile „Screenlight Mobile iOS App Store“ und „Screenlight Mobile Mac App Store“
(vorhandene gleichnamige aktive Profile werden wiederverwendet), installiert unter
~/Library/Developer/Xcode/UserData/Provisioning Profiles und ~/Library/MobileDevice/Provisioning Profiles.
"""
import base64
import pathlib
import subprocess
import sys

sys.path.insert(0, str(pathlib.Path(__file__).parent))
import asc_store as asc  # noqa: E402

BUNDLE = "com.amim.Flashlight"
PROFILES = {"IOS_APP_STORE": ("Screenlight Mobile iOS App Store", ".mobileprovision"),
            "MAC_APP_STORE": ("Screenlight Mobile Mac App Store", ".provisionprofile")}


def local_serial() -> str:
    pem = subprocess.run(["security", "find-certificate", "-c", "Apple Distribution", "-p"],
                         capture_output=True, text=True, check=True).stdout
    out = subprocess.run(["openssl", "x509", "-noout", "-serial"], input=pem, capture_output=True, text=True, check=True).stdout
    return out.strip().split("=")[1].upper()


def main() -> None:
    serial = local_serial()
    certificates = asc.paged("/v1/certificates?filter[certificateType]=DISTRIBUTION&limit=50")
    certificate = next((c for c in certificates if c["attributes"]["serialNumber"].upper() == serial), None)
    if not certificate:
        raise SystemExit("Das lokale Zertifikat „Apple Distribution“ ist in App Store Connect nicht vorhanden.")
    bundle = asc.paged(f"/v1/bundleIds?filter[identifier]={BUNDLE}")[0]
    existing = {p["attributes"]["name"]: p for p in asc.paged("/v1/profiles?limit=200")
                if p["attributes"]["profileState"] == "ACTIVE"}
    for kind, (name, suffix) in PROFILES.items():
        profile = existing.get(name)
        if not profile:
            status, payload = asc.call("POST", "/v1/profiles", {"data": {
                "type": "profiles", "attributes": {"name": name, "profileType": kind},
                "relationships": {"bundleId": {"data": {"type": "bundleIds", "id": bundle["id"]}},
                                  "certificates": {"data": [{"type": "certificates", "id": certificate["id"]}]}}}})
            if status != 201:
                raise SystemExit(f"{name}: {status} {asc.errors(payload)}")
            profile = payload["data"]
            print("angelegt:", name)
        else:
            print("vorhanden:", name)
        content = base64.b64decode(profile["attributes"]["profileContent"])
        uuid = profile["attributes"]["uuid"]
        for folder in ("~/Library/Developer/Xcode/UserData/Provisioning Profiles", "~/Library/MobileDevice/Provisioning Profiles"):
            target = pathlib.Path(folder).expanduser()
            target.mkdir(parents=True, exist_ok=True)
            (target / (uuid + suffix)).write_bytes(content)
        print("  installiert:", uuid, "gültig bis", profile["attributes"]["expirationDate"][:10])


if __name__ == "__main__":
    main()
