#!/bin/bash
# fullstack-agent — MarQed starter.
# Copyright (C) 2026 Jared Rhodenizer (upstream) — AGPL-3.0-or-later
#
# Start de agent en zegt erbij wat je moet doen. Dunne laag over
# start.sh: hij controleert eerst of de installatie er echt staat, leest
# de talk-toets uit jouw config in plaats van er een te noemen, en zegt
# de spraakcommando's die je anders moet onthouden.
#
#   ./marqed-start.sh            stem + gezicht (standaard)
#   ./marqed-start.sh hands      stem + het gebarenbord
#   ./marqed-start.sh all        stem + gezicht + bord
#   ./marqed-start.sh check      alleen de poort draaien, niets starten
HERE="$(cd "$(dirname "$0")" && pwd)"
HOME_DIR="$(dirname "$HERE")"
MODE="${1:-voice}"

fail() { printf '\n!! %s\n\n' "$*" >&2; exit 1; }

[ -d "$HOME_DIR/backtalk/.venv" ] || fail "De stem is hier niet geïnstalleerd.
   Draai eerst:  $HERE/marqed-install.sh"
[ -f "$HOME_DIR/CLAUDE.md" ] || fail "Geen CLAUDE.md in $HOME_DIR — de agent weet niet wie hij is.
   Draai $HERE/marqed-install.sh, die schrijft er een."

# de poort, los te draaien: zegt of het aan de mond of aan de oren ligt
if [ "$MODE" = "check" ]; then
  exec "$HOME_DIR/backtalk/.venv/bin/python" "$HOME_DIR/backtalk/verify.py"
fi

lees() {  # sleutel uit backtalk.json, zonder jq als afhankelijkheid
  python3 - "$HOME_DIR/backtalk/backtalk.json" "$1" <<'PY' 2>/dev/null
import json, sys
try:
    print(json.load(open(sys.argv[1])).get(sys.argv[2], "") or "")
except Exception:
    print("")
PY
}
NAAM="$(lees name)";     [ -n "$NAAM" ] || NAAM="je agent"
TOETS="$(lees ptt_key)";  [ -n "$TOETS" ] || TOETS="home"
MIC="$(lees mic_mode)"

cat <<TXT

== $NAAM start ==

TXT
if [ "$MIC" = "open" ]; then
  echo "  Hands-free luisteren staat aan: praat gewoon. De $TOETS-toets onderbreekt hem."
else
  echo "  HOU DE $(echo "$TOETS" | tr '[:lower:]' '[:upper:]')-TOETS INGEDRUKT, praat, laat los."
  echo "  Indrukken terwijl hij praat = onderbreken. De mic is verder dicht."
fi
cat <<TXT

  Hardop te zeggen, zonder toetsenbord:
    "go hands free" / "push to talk mode"      de microfoon
    "stop asking for permission" (+ "confirm") hij vraagt niet meer vooraf
    "switch to the deep model"                 zwaarder model, deze sessie
    "usage report"                             wat deze sessie heeft gekost

  Hij vraagt hardop toestemming vóór hij iets echts doet. Een exact "yes"
  keurt goed; iets anders weigert, en jouw woorden gaan als reden terug.

TXT
case "$MODE" in
  voice) echo "  Gezicht: http://127.0.0.1:8790/ — opent zelf." ;;
  hands) echo "  Bord: open http://127.0.0.1:8794/stage.html in Chrome en sta de camera toe." ;;
  all)   echo "  Gezicht: http://127.0.0.1:8790/ · Bord: http://127.0.0.1:8794/stage.html (Chrome)." ;;
esac
echo "  Ctrl-C hier stopt alles."
echo ""
exec "$HERE/start.sh" "$MODE"
