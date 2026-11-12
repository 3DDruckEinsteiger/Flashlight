# Prüfprotokoll Screenlight Mobile 1.1 (Build 5)

Stand: 12.11.2026. Geprüft wurde ausschließlich im Simulator (Vorgabe: kein echtes Gerät) und auf dem Mac.

## Killer-Punkte für diese Projektart (native App mit Store-Auftritt)

1. Jede Funktion wirklich bedient, nicht nur angesehen (automatische Bedien-Tests).
2. Update von der Vorversion verliert keine Daten (gespeicherte Einstellungen und Favoriten).
3. Kleinstes und größtes Gerät, Querformat, sehr große Schrift: Hauptfunktion bleibt erreichbar.
4. Alle Sprachen: nichts abgeschnitten, Rechts-nach-links gespiegelt, Bilder zeigen die richtige Sprache.
5. Jede Aussage im Store stimmt mit dem Code überein; keine Marken, keine Gesundheits- oder Sparversprechen.
6. Release-Build enthält keine Test-Schalter; Privacy Manifest vorhanden.
7. Store-Medien: Größe, Format, kein Alphakanal, Video nur App-Inhalt, Länge 15 bis 30 Sekunden.
8. Frischer Gegenprüfer ohne Vorwissen für Code und für den Store-Auftritt.

## Was geprüft wurde, mit Zahlen

| Prüfung | Ergebnis |
|---|---|
| Build iOS-Simulator, macOS, Archive iOS und macOS | alle erfolgreich, 0 Fehler, 0 Compiler-Warnungen im App-Code (1 Hinweis des Asset-Katalogs: 18 unbenutzte Icon-Dateien im Icon-Satz) |
| Bedien-Tests iPhone (großes Gerät) | 23 von 23 bestanden, zuletzt auf dem Endstand |
| Bedien-Tests iPad 13" | 23 von 23 bestanden |
| Abgedeckt | An/Aus, 10 Farben, Weißton, Helligkeit per Regler und Wischen, Farbwechsel per Wischen, alle 6 Modi, Timer (Start, Stopp, Ablauf, Ablauf bei ausgeblendeter Bedienung), Favoriten (merken, entfernen, rückgängig), Neustart behält Einstellungen, Hintergrund und Vordergrund, Querformat, sehr große Schrift, Beschriftungen für VoiceOver, Bedienung bleibt bei ausgeschaltetem Licht sichtbar, Favoriten aus Version 1.0 werden übernommen |
| Release-Build im Simulator gestartet | läuft; Test-Parameter wirkungslos |
| Kleines iPhone (SE, 375 × 667 Punkte) | 6 Sprachen und sehr große Schrift angesehen |
| Sprachen in der App angesehen | 16 (de, en, ar, he, ja, ru, el, fr, ta, ml, ko, zh-Hans, zh-Hant, th, hi, ur über Store-Aufnahmen) |
| Store-Bilder | 510 Dateien, per Skript: 50 Sprachen × 5 iPhone (1320 × 2868) und 5 iPad (2064 × 2752), Mac 2 Sprachen × 5 (2880 × 1800), alle ohne Alphakanal; per Kontaktbogen angesehen: 30 Sprachen |
| Store-Texte | 50 Sprachen, Längengrenzen per Skript (Untertitel ≤ 30, Werbetext ≤ 170, Schlagwörter ≤ 100), von App Store Connect ohne Fehler angenommen |
| Video | 886 × 1920, H.264 High Level 4.0, 30 Bilder/s, 25,3 s, stumme Stereo-Tonspur; 26 Einzelbilder angesehen, nur App-Inhalt |
| Blitzfrequenz | SOS höchstens 3 Wechsel pro Sekunde, Kerze und Disco darunter (vom Gegenprüfer nachgerechnet) |

## Mac-Test auf dem MacBook Air (12.11.2026, 15:04 bis 15:19 Uhr)

Gerät: MacBook Air M1, macOS 26.6.2. Geprüft wurde der Debug-Build desselben Quellstands wie Build 5, bedient per Fernsteuerung (VNC) mit Bildschirmaufnahme nach jedem Schritt.

| Schritt | Ergebnis |
|---|---|
| Start, Fenster, Menü „Light“ in der Menüleiste | in Ordnung |
| Maus: Farbe wählen, Reiter Farbe/Modus/Timer | in Ordnung |
| Maus: alle 6 Modi (Dauerlicht, SOS, Kerze, Disco, Regenbogen, Verlauf mit Von/Nach) | in Ordnung |
| Timer 5 Minuten starten, Countdown läuft (auch im Reiter), Ausschalten beendet den Timer | in Ordnung |
| Aus- und Einschalten per Knopf, Leertaste und ⌘L | in Ordnung |
| Pfeiltasten links/rechts (Farbe), hoch/runter (Helligkeit 100 → 90 → 80 → 70 %) | in Ordnung |
| Klick aufs Licht blendet die Bedienung aus, Escape holt sie zurück; Tasten wirken auch ohne Bedienung | in Ordnung |
| „Nur Licht“: Vollbild über den ganzen Bildschirm, Escape zurück ins Fenster | in Ordnung |
| Weißton-Regler mit der Maus ziehen | in Ordnung |
| Favorit merken, Hinweis „right-click to remove“, Rechtsklick → „Remove favorite“, Rückgängig-Leiste erscheint | in Ordnung |

Einschränkung: Über die Fernsteuerung gingen einzelne Klicks und Tastendrücke verloren (bei Wiederholung wirkten sie). Das trat bei Maus und Tastatur gleichermaßen und unabhängig vom Bedienelement auf; ich ordne es der Fernsteuerung zu, belegt ist das nicht. Nicht geprüft auf dem Mac: eigener Farbwähler, „Rückgängig“ anklicken, VoiceOver, Timer-Ablauf bis zum Ende.

## Einreichung

| Plattform | Version | Eingereicht | Status bei Abfrage |
|---|---|---|---|
| iOS (iPhone, iPad) | 1.1 (Build 5) | 12.11.2026, 14:52 Uhr | Warten auf Prüfung |
| macOS | 1.1 (Build 5) | 12.11.2026, 15:20 Uhr | Warten auf Prüfung |

## Gegenprüfer

- Code: 19 Funde, davon 1 kritisch. 17 übernommen und behoben, 2 bewusst so gelassen.
- Store-Auftritt: 9 Funde, alle belegt. 8 behoben, 1 nicht behebbar (siehe unten).

## Gefunden und behoben

- Timer: Eine alte Timer-Aufgabe konnte das Licht später ein zweites Mal ausschalten.
- iOS 16: Bildschirmhelligkeit wurde beim Verlassen der App nicht zurückgegeben; Regenbogen-Symbol fehlte dort.
- Bedienung ließ sich bei ausgeschaltetem Licht ausblenden (schwarzer Bildschirm ohne Knöpfe).
- Test-Schalter waren teilweise auch im Release-Build aktiv.
- Mac: gedrückt gehaltene Taste ließ den Bildschirm schnell blinken; Animation fror ein, wenn eine andere App vorn war.
- VoiceOver: Favoriten hießen wie ihr Farbcode, keine Ansage beim Entfernen, zu grobe Reglerschritte.
- Kleines iPhone: Der Ausschalten-Knopf rutschte mit Tipps und Favoriten aus dem Bild.
- Sehr große Schrift: abgeschnittene Wörter in Reitern, Modus und Timer.
- Rechts-nach-links: Weißton-Verlauf war zwischenzeitlich doppelt gespiegelt.
- Store-Bilder: Zeilenumbruch mitten im Wort (Japanisch, Koreanisch, Chinesisch), deutsches Datum in iPad-Bildern anderer Sprachen, amerikanische Schreibweise in britischen Bildern, Urdu-Überschrift zu eng.
- Video: Bild begann erst nach 1,5 Sekunden; am Ende war kurz der Home-Bildschirm zu sehen.
- Store-Texte: „neuer“ Weißton-Regler (gab es schon), „Selfie-Licht“ (auf demselben iPhone nicht nutzbar), „weniger Akkuverbrauch“ (nicht gemessen), ungenaue Timer-Angabe, Gesundheitsbegriff in chinesischen Schlagwörtern.
- Privacy Manifest fehlte.
- Symbol für Dauerlicht zeigte eine Taschenlampe (jetzt Glühbirne), Wörter für „Taschenlampe“ aus allen Schlagwörtern entfernt.

## Bewusst so gelassen

- Schriftgröße im Bedienfeld ist bei der ersten Bedienungshilfen-Stufe gedeckelt, damit An/Aus und Helligkeit immer auf den Bildschirm passen.
- Die Zeilen „Eigene Farbe“, „Von“ und „Nach“ öffnen den Farbwähler nur über das runde Farbfeld (Systemelement).
- Zwei gleichzeitig geöffnete Fenster auf dem iPad teilen sich eine Helligkeitssteuerung.
- Bundle-Kennung `com.amim.Flashlight` und die Adresse der Datenschutzerklärung enthalten das Wort „Flashlight“; beides lässt sich bei einer veröffentlichten App nicht ändern, ohne den Eintrag neu anzulegen.
- Herkunft des App-Icons ist im Repository nicht dokumentiert; es stammt aus Version 1.0 und wurde nicht verändert.

## Offen oder nicht prüfbar

- Kein Test auf echten Geräten: Haptik, tatsächliche Bildschirmhelligkeit, Akkuverbrauch und VoiceOver-Sprachausgabe sind nur am Code geprüft.
- Übersetzungen: Deutsch und Englisch von Hand; 45 Sprachen maschinell übersetzt und in einem zweiten Durchgang gegengelesen, nicht von Muttersprachlern geprüft. Am unsichersten: Urdu, Odia, Slowenisch, Punjabi, Kannada, Malayalam.
- Mac: Die automatischen Bedien-Tests (XCUITest) sind geschrieben und bauen, wurden aber nicht ausgeführt: Auf dem Arbeits-Mac hätten sie Axels Arbeit unterbrochen, auf dem MacBook Air fehlt Xcode. Der Mac wurde stattdessen von Hand per Fernsteuerung geprüft (siehe unten).
- Mac-Store-Bilder gibt es in Englisch und Deutsch; andere Sprachen zeigen im Mac App Store die englischen Bilder.
- Die im Store verlinkte Datenschutzerklärung nennt bis zum Zusammenführen des Pull Requests noch den alten Namen „Screenlight Free“.
