# CLAUDE.md

Hinweise für Claude Code in diesem Repository.

## Was das ist

**Screenlight Mobile** (Bundle `com.amim.Flashlight`, Team `X34YY968L9`, App-Store-ID `6758013532`) ist eine
SwiftUI-App für iPhone, iPad und Mac, die den Bildschirm als sanfte Lichtquelle nutzt. Im App Store heißt
sie „Screenlight Mobile“; Ordner und Xcode-Ziel heißen `Screenlight`.

Positionierung im Store: **Bildschirmlicht** (Leselicht, Nachtlicht, Fülllicht, Farblicht), nicht
„Taschenlampe“. Grund: Apples Richtlinie 4.3(b) nennt Taschenlampen-Apps als gesättigte Kategorie.
Wörter für „Taschenlampe“ deshalb nicht in Schlagwörter oder Untertitel aufnehmen.

## Bauen und Testen

```bash
# iOS-Simulator
xcodebuild -project Screenlight.xcodeproj -scheme Screenlight -destination 'generic/platform=iOS Simulator' build
# macOS
xcodebuild -project Screenlight.xcodeproj -scheme Screenlight -destination 'platform=macOS' build
# Bedien-Tests (XCUITest, nur iOS; Simulatorname anpassen)
xcodebuild test -project Screenlight.xcodeproj -scheme Screenlight -destination 'platform=iOS Simulator,name=<Simulator>'
```

Das Projekt nutzt keine synchronisierten Ordner: Neue Swift-Dateien müssen in `project.pbxproj`
eingetragen werden. Mindestsysteme: iOS 16, macOS 14.

## Aufbau

- `Screenlight/Models/LightStore.swift`: zentraler Zustand (`ObservableObject`): Farbe, Helligkeit, Modus,
  Timer (Enddatum als Wahrheit), Favoriten, Speichern in `UserDefaults` (Schlüssel seit 1.0 unverändert).
- `Screenlight/Models/LightColor.swift`: sRGB-Farbwert, Voreinstellungen, Weißton, Favoriten.
- `Screenlight/Models/LightMode.swift`: Modi und `ModeAnimator`. Animationen sind reine Funktionen der Zeit,
  es laufen keine eigenen Timer. Die Rohwerte der Modi (`"Normal"`, `"Candle"` …) sind gespeicherte Kennungen
  und dürfen nicht umbenannt werden.
- `Screenlight/Views/LightSurface.swift`: das Licht selbst (`TimelineView`, pausiert bei Licht aus und im Hintergrund).
- `Screenlight/Views/ControlPanel.swift`, `Sections.swift`, `Components.swift`: Bedienfeld unten mit den Reitern
  Farbe, Modus, Timer, Helligkeitsregler, An/Aus und „Nur Licht“.
- `Screenlight/Support/Platform.swift`: Haptik, Bildschirm wach halten, Bildschirmhelligkeit (iOS), Vollbild (Mac).
- `ScreenlightUITests/`: Bedien-Tests. Sie finden Elemente über `accessibilityIdentifier`.

Startparameter nur in Debug-Builds (für Tests und Store-Aufnahmen): `-uiTestReset YES`,
`-uiTestSecondsPerMinute <n>`, `-uiTestFavorites <hex,hex>`, `-uiTestTimerMinutes <n>`, `-uiTestShowHUD YES`,
`-startLightOnly YES`; dazu die normalen Schlüssel wie `-selectedTab mode`, `-mode Candle`,
`-colorRed 1 -colorGreen 0 -colorBlue 0`, `-hintDismissed YES`.

## Sprachen

Quelle aller Texte ist `Store/lokalisierung/<code>.json` (50 Sprachen): `ui` (App-Texte, Schlüssel = englischer
Text), `store` (Untertitel, Werbetext, Schlagwörter, Beschreibung, Neuigkeiten) und `shots` (Überschriften
der Store-Bilder). `Screenlight/Localizable.xcstrings` wird daraus erzeugt und nicht von Hand bearbeitet:

```bash
python3 Store/tools/build_strings.py
```

Das Skript prüft auch die Längengrenzen des App Store. Englisch und Deutsch sind von Hand geschrieben, alle
anderen Sprachen maschinell übersetzt und in einem zweiten Durchgang gegengelesen, aber nicht von
Muttersprachlern geprüft.

## Store

- `Store/tools/asc_store.py`: Version anlegen, Texte, Bilder und Videos hochladen, Build zuordnen, einreichen
  (App-Store-Connect-API; Zugang aus `~/.claude/.appstoreconnect.env`, nichts davon liegt im Repository).
- `Store/tools/store_bilder.py` mit `store_bild.html`: gestaltete Store-Bilder aus echten Screenshots.
- `Store/QUELLEN.md`: Herkunft und Lizenzen von Schriften, Symbolen und Medien.

## Regeln

- Keine Werkzeuge oder Bibliotheken mit Telemetrie, keine Werbung, keine Datenerhebung in der App.
- Nur eigene oder nachweislich frei lizenzierte Schriften, Symbole, Töne und Bilder; Herkunft in `Store/QUELLEN.md` eintragen.
- Nicht auf `main` arbeiten, nichts force-pushen.

## Einreichen (Stand 12.11.2026)

Xcode ist auf diesem Mac nicht mit einem Entwicklerkonto angemeldet, und der API-Schlüssel darf keine
Cloud-Signierung. Deshalb wird von Hand signiert:

1. `Store/tools/asc_profile.py` legt die Profile „Screenlight Mobile iOS App Store“ und „… Mac App Store“
   mit dem lokalen Zertifikat „Apple Distribution“ an bzw. installiert sie.
2. `xcodebuild archive` (iOS: `generic/platform=iOS`, Mac: `generic/platform=macOS`), dann `-exportArchive`
   mit `signingStyle manual`, dem passenden Profil, `destination upload` und den drei
   `-authenticationKey…`-Parametern; beim Mac zusätzlich `installerSigningCertificate`
   „3rd Party Mac Developer Installer“.
3. `asc_store.py version|texts|media|build`, dann `asc_pruefen.py` (muss „0 Probleme“ melden), dann `asc_store.py submit`.

Apple verlangt beim Einreichen einen Prüfkontakt (Name, E-Mail, Telefon) und vollständige Altersangaben;
fehlt etwas, nennt die Antwort auf `reviewSubmissionItems` die Felder unter `meta.associatedErrors`.
Build-Nummern müssen über beide Plattformen hinweg steigen (zuletzt hochgeladen: Build 5).
