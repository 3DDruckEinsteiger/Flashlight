# Herkunft und Lizenzen

Stand: 12.11.2026. Alles, was in der App oder im Store-Auftritt von Screenlight Mobile verwendet wird.

## In der App

| Was | Herkunft | Recht |
|---|---|---|
| Programmcode | eigener Code dieses Repositorys | eigenes Werk |
| App-Icon | vorhanden seit Version 1.0 (`Screenlight/Assets.xcassets/AppIcon.appiconset`), unverändert übernommen | Herkunft des Icons ist in diesem Repository nicht dokumentiert; es wurde von Apple mit Version 1.0 geprüft und veröffentlicht |
| Symbole in der Oberfläche | SF Symbols, über `Image(systemName:)` vom System geliefert | von Apple für Apps auf Apple-Plattformen bereitgestellt; es werden nur allgemeine Symbole verwendet, keine, die Apple-Funktionen oder -Produkte darstellen |
| Schrift in der Oberfläche | Systemschrift der Geräte | vom System gestellt, nicht mitgeliefert |
| Töne, Musik, Fotos | keine | entfällt |
| Fremde Bibliotheken | keine | entfällt |

## Store-Bilder

| Was | Herkunft | Recht |
|---|---|---|
| Screenshots | echte Aufnahmen der App aus dem Simulator | eigenes Werk |
| Gestaltung (Hintergrund, Rahmen) | `Store/tools/store_bild.html`, eigener Code | eigenes Werk |
| Überschriften, lateinische, kyrillische und griechische Schrift | Inter, `Store/medien/schrift/Inter.ttf`, aus https://github.com/google/fonts/tree/main/ofl/inter | SIL Open Font License 1.1, Text in `Store/medien/schrift/OFL_Inter.txt` |
| Überschriften in anderen Schriftsystemen | Noto Sans (Arabic, Hebrew, Thai, Devanagari, Bengali, Gujarati, Gurmukhi, Kannada, Malayalam, Oriya, Tamil, Telugu, JP, KR, SC, TC) und Noto Nastaliq Urdu, aus https://github.com/google/fonts/tree/main/ofl | SIL Open Font License 1.1, Texte je Familie in `Store/medien/schrift/OFL_*.txt`; die Dateien werden mit `Store/tools/schriften_laden.py` geladen |

Bewusst nicht verwendet: Apples Schrift „SF Pro“ für Werbe-Überschriften und Geräterahmen-Grafiken.

## Texte

Alle Store- und App-Texte sind eigene Texte. Deutsch und Englisch von Hand geschrieben, die übrigen Sprachen
maschinell übersetzt und gegengelesen. Genannt werden nur die Apple-Produktnamen iPhone, iPad, Mac und
VoiceOver zur Beschreibung der Kompatibilität; keine Marken Dritter in Name, Untertitel oder Schlagwörtern.
