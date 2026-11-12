#!/bin/zsh
# Nimmt die fünf Store-Motive der Mac-Version auf, ohne den Bildschirm abzufilmen:
# Die Debug-App startet versteckt im Hintergrund, zeichnet ihr Fenster (1440×900 Punkte)
# selbst in eine PNG-Datei und beendet sich (Startparameter -uiTestSnapshot).
#
# Aufruf:  Store/tools/store_aufnahmen_mac.sh <Screenlight.app (Debug)> <ziel-ordner> [sprache ...]
# Ergebnis: <ziel>/<sprache>/mac/01.png … 05.png

set -u
app=$1; out=$2; shift 2
[ $# -eq 0 ] && set -- en de

shoot() {  # shoot <datei> <startparameter...>
  local file=$1; shift
  rm -f "$file"
  open -g -j -n "$app" --args -uiTestReset YES "$@" -uiTestSnapshot "$file"
  local n=0
  while [ ! -s "$file" ] && [ $n -lt 40 ]; do sleep 0.5; n=$((n+1)); done
  sleep 1
}

for lang in "$@"; do
  dir="$out/$lang/mac"; mkdir -p "$dir"
  l=(-AppleLanguages "($lang)")
  h=(-hintDismissed YES)
  shoot "$dir/01.png" $l $h -selectedTab color -colorRed 1 -colorGreen 0.82 -colorBlue 0.6
  shoot "$dir/02.png" $l $h -selectedTab color -colorRed 0.7 -colorGreen 0.3 -colorBlue 1 -uiTestFavorites "FF2A2A,26E640,0D66FF,FF338C"
  shoot "$dir/03.png" $l $h -selectedTab mode -mode Candle
  shoot "$dir/04.png" $l $h -selectedTab timer -colorRed 0.05 -colorGreen 0.4 -colorBlue 1 -uiTestTimerMinutes 15
  shoot "$dir/05.png" $l -hintDismissed NO -selectedTab color -colorRed 0.2 -colorGreen 0.85 -colorBlue 1
  echo "$lang $(ls "$dir" | wc -l | tr -d ' ')"
done
