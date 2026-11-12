#!/bin/zsh
# Nimmt die fünf Store-Motive als echte Screenshots aus dem Simulator auf.
#
# Aufruf:  Store/tools/store_aufnahmen.sh <simulator-name> <iphone|ipad> <ziel-ordner> [sprache ...]
# Voraussetzung: Simulator läuft, Debug-Build der App ist installiert.
# Ergebnis: <ziel>/<sprache>/<iphone|ipad>/01.png … 05.png
# Ohne Sprachangabe werden alle Sprachen aus Store/lokalisierung plus en-GB, en-AU, en-CA aufgenommen.

set -u
device=$1; kind=$2; out=$3; shift 3
root=${0:A:h:h:h}
if [ $# -eq 0 ]; then
  set -- $(ls "$root/Store/lokalisierung" | sed 's/\.json$//') en-GB en-AU en-CA
fi
app=com.amim.Flashlight
wait_time=${SHOT_WAIT:-3}

shoot() {  # shoot <datei> <startparameter...>
  local file=$1; shift
  xcrun simctl terminate "$device" $app >/dev/null 2>&1
  xcrun simctl launch "$device" $app -uiTestReset YES "$@" >/dev/null || return 1
  sleep $wait_time
  xcrun simctl io "$device" screenshot "$file" >/dev/null 2>&1
}

xcrun simctl status_bar "$device" override --time "9:41" --batteryState charged --batteryLevel 100 --cellularBars 4 --wifiBars 3 2>/dev/null

for lang in "$@"; do
  dir="$out/$lang/$kind"; mkdir -p "$dir"
  l=(-AppleLanguages "($lang)")
  h=(-hintDismissed YES)
  shoot "$dir/01.png" $l $h -selectedTab color -colorRed 1 -colorGreen 0.82 -colorBlue 0.6
  shoot "$dir/02.png" $l $h -selectedTab color -colorRed 0.7 -colorGreen 0.3 -colorBlue 1 -uiTestFavorites "FF2A2A,26E640,0D66FF,FF338C"
  shoot "$dir/03.png" $l $h -selectedTab mode -mode Candle
  shoot "$dir/04.png" $l $h -selectedTab timer -colorRed 0.05 -colorGreen 0.4 -colorBlue 1 -uiTestTimerMinutes 15
  # Motiv 5 zeigt die Wisch-Tipps des ersten Starts.
  shoot "$dir/05.png" $l -hintDismissed NO -selectedTab color -colorRed 0.2 -colorGreen 0.85 -colorBlue 1
  n=$(ls "$dir" | wc -l | tr -d ' ')
  echo "$lang $n"
done
