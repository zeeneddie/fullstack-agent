#!/bin/bash
# fullstack-agent — MarQed deterministic installer.
# Copyright (C) 2026 Jared Rhodenizer (upstream) — AGPL-3.0-or-later
#
# Upstream installs through a conversational Claude Code wizard. This is
# the other route: one command, no questions, pinned versions, and a gate
# at the end that PROVES the loop closed instead of announcing it.
#
#   ./marqed-install.sh [home-folder]      (default: the parent folder)
#
# Installs: backtalk (voice) · ai-visualizer (face) · barehands (hands).
# The memory piece is deliberately NOT installed — our memory layer
# already lives in ~/.claude/projects/*/memory and the upstream wizard
# wants to replace its index with a pointer.
set -e
HERE="$(cd "$(dirname "$0")" && pwd)"
# --skip-preflight moet weg zijn vóór $1 als home-map wordt gelezen,
# anders installeert hij in een map die "--skip-preflight" heet.
SKIP_PREFLIGHT=0
if [ "${1:-}" = "--skip-preflight" ]; then SKIP_PREFLIGHT=1; shift; fi
HOME_DIR="${1:-$(dirname "$HERE")}"
ORG=zeeneddie
PIECES="backtalk ai-visualizer barehands"
# Pin every piece to one git ref (branch or tag). Empty = the fork's
# default branch. Set it when you want two machines on the exact same
# commit, or to try a branch before it lands.
REF="${MARQED_REF:-}"
# Where the pieces come from. Default: our forks on GitHub. Point it at a
# folder (a USB stick, an NFS share, a checkout) and the same command
# installs a machine with no GitHub access at all.
SOURCE="${MARQED_SOURCE:-https://github.com/$ORG}"

say() { printf '\n== %s\n' "$*"; }
fail() { printf '\n!! %s\n' "$*" >&2; exit 1; }

# --- preflight: alles wat de machine moet hebben, vóór de eerste byte ---
# Aparte stap zodat je hem ook los kunt draaien (of via curl) voordat je
# 7 GB gaat halen. --skip-preflight slaat hem over; dan is de uitkomst
# jouw verantwoordelijkheid.
if [ "$SKIP_PREFLIGHT" = 1 ]; then
  echo "-- preflight overgeslagen op verzoek"
elif [ -x "$HERE/marqed-preflight.sh" ]; then
  "$HERE/marqed-preflight.sh" || fail "preflight gaf rood — hierboven staat waarom. Los dat eerst op."
else
  echo "-- geen marqed-preflight.sh gevonden; alleen de harde eisen worden getoetst"
  command -v git >/dev/null     || fail "git ontbreekt"
  command -v python3 >/dev/null || fail "python3 ontbreekt"
  command -v claude >/dev/null  || fail "Claude Code (claude) ontbreekt — de stem draait erop"
fi

say "home: $HOME_DIR"
mkdir -p "$HOME_DIR"

# --- the pieces, from our forks ---
for p in $PIECES; do
  if [ -d "$HOME_DIR/$p/.git" ]; then
    say "$p: bijwerken"
    git -C "$HOME_DIR/$p" pull --ff-only -q || echo "   (lokale wijzigingen — pull overgeslagen, jouw versie wint)"
  else
    say "$p: klonen van $SOURCE${REF:+ @ $REF}"
    if [ -n "$REF" ]; then
      git clone -q --branch "$REF" "$SOURCE/$p" "$HOME_DIR/$p"
    else
      git clone -q "$SOURCE/$p" "$HOME_DIR/$p"
    fi
  fi
done

# --- the agent's identity: never run brainless ---
if [ ! -f "$HOME_DIR/CLAUDE.md" ]; then
  say "geen CLAUDE.md in de home — een minimale identiteit schrijven"
  cat > "$HOME_DIR/CLAUDE.md" <<'MD'
# Boot Config

Je bent **Jarvis**, de assistent van dit huis. Zelfde naam en toon, elke
sessie, of we nu typen of praten.

**Toon.** Direct, kort, Nederlands tenzij anders gevraagd. Geen slappe
slotzinnen, geen samenvattingen die niemand vroeg.

**Welkomstregel:** "Alles online. Waar werken we aan?"

## Je bent de monteur
Deze agent draait op open gereedschap dat naast dit bestand staat
(backtalk, ai-visualizer, barehands). Gaat er iets stuk, dan repareer JIJ
het: lees de TROUBLESHOOTING.md en MARQED.md van het betreffende stuk,
stel de diagnose en los het op. Stuur de mens niet het internet op.
MD
fi

# --- the voice: its own installer carries the gate ---
say "backtalk installeren (dit is het zware stuk: ~6 GB)"
( cd "$HOME_DIR/backtalk" && ./install.sh ) || fail "backtalk's eigen poort gaf rood — zie de uitvoer hierboven"

# --- wiring: the voice writes notes, the faces read them ---
say "de naden bedraden"
python3 - "$HOME_DIR" <<'PY'
import json, os, sys
home = sys.argv[1]
name = "Jarvis"

bt = os.path.join(home, "backtalk", "backtalk.json")
cfg = json.load(open(bt)) if os.path.exists(bt) else {}
cfg.update({
    "agent_dir": home,
    "name": name,
    "signals_dir": os.path.join(home, "backtalk"),
    "barehands_state_dir": os.path.join(home, "barehands", "state"),
    "greeting": f"Alles online. Waar werken we aan?",
    "stt_device": "auto",       # gpu.py bewijst het pad en valt terug op CPU
    "stt_compute": "int8",      # wordt float16 zodra CUDA het haalt
})
json.dump(cfg, open(bt, "w"), indent=2)

viz = os.path.join(home, "ai-visualizer", "ai-visualizer.json")
json.dump({"name": name, "badge": "", "face": "board", "port": 8790,
           "bus_dir": os.path.join(home, "backtalk"),
           "thinking_sound": True}, open(viz, "w"), indent=2)

bh = os.path.join(home, "barehands", "barehands.json")
json.dump({"name": name, "port": 8794,
           "orbs": [{"title": "Notes", "path": "sample-notes", "kind": "notes"},
                    {"title": "Props", "path": "media", "kind": "media"}]},
          open(bh, "w"), indent=2)
os.makedirs(os.path.join(home, "barehands", "state"), exist_ok=True)
print("   backtalk.json · ai-visualizer.json · barehands.json geschreven")
PY

# --- THE CHAIN GATE ---
# backtalk proved its own half. This proves the seam: the voice writes
# state files, and the face actually reports them back over HTTP.
say "de keten toetsen (stem schrijft, gezicht leest)"
VIZ_PORT=8790
VIZ_LOG="$HOME_DIR/keten-gate.log"
# EERST: is die poort al bezet? Zo ja, dan bindt onze server niet en
# ondervraagt de toets hieronder een VREEMDE server — die kan een andere
# bus-map lezen en dus vals groen geven. Gemeten: precies dat gebeurde,
# en alleen omdat de vreemde server toevallig een andere bus las viel het
# op. Een bezette poort is daarom een harde stop, geen waarschuwing.
# Zelf proberen te binden is de enige platformonafhankelijke toets:
# `ss` bestaat niet op macOS, en een controle die stil overslaat is geen
# controle. Precies dat gebeurde in de eerste versie hiervan.
if ! python3 - "$VIZ_PORT" <<'PYPORT' 2>/dev/null
import socket, sys
s = socket.socket()
try:
    s.bind(("127.0.0.1", int(sys.argv[1])))
except OSError:
    sys.exit(1)
finally:
    s.close()
PYPORT
then
  fail "poort $VIZ_PORT is al bezet — de ketenpoort zou een VREEMDE server meten
   en kan dan vals groen geven. Stop wat daar draait en draai dit opnieuw:
     linux:  ss -ltnp | grep :$VIZ_PORT
     macos:  lsof -nP -iTCP:$VIZ_PORT -sTCP:LISTEN"
fi
( cd "$HOME_DIR/ai-visualizer" && python3 server.py --no-open >"$VIZ_LOG" 2>&1 & echo $! > /tmp/marqed-viz.pid )
VIZ_PID="$(cat /tmp/marqed-viz.pid)"
# wacht tot ONZE server antwoordt, en stop als hij onderweg sterft
for _ in $(seq 1 20); do
  kill -0 "$VIZ_PID" 2>/dev/null || fail "het gezicht startte niet — zie $VIZ_LOG"
  curl -fsS --max-time 2 -o /dev/null "http://127.0.0.1:$VIZ_PORT/state" 2>/dev/null && break
  sleep 0.5
done
kill -0 "$VIZ_PID" 2>/dev/null || fail "het gezicht startte niet — zie $VIZ_LOG"
python3 - "$HOME_DIR" <<'PY' || { kill "$VIZ_PID" 2>/dev/null; exit 1; }
import json, os, sys, time, urllib.request
home = sys.argv[1]
bus = os.path.join(home, "backtalk")
def state():
    return json.load(urllib.request.urlopen("http://127.0.0.1:8790/state", timeout=5))
bad = []
for want in ("listening", "thinking", "speaking", "idle"):
    open(os.path.join(bus, ".voice_state"), "w").write(want)
    time.sleep(0.5)
    got = state()["state"]
    print(f"   {want:<10} -> gezicht meldt {got}")
    if got != want:
        bad.append(f"{want}->{got}")
open(os.path.join(bus, ".voice_waveform"), "w").write(
    json.dumps({"ts": time.time(), "samples": [20000.0] * 64}))
open(os.path.join(bus, ".voice_state"), "w").write("speaking")
time.sleep(0.5)
s = state()
nz = sum(1 for x in s["samples"] if abs(x) > 0.001)
print(f"   golfvorm   -> level {s['level']:.2f}, {nz}/64 samples")
if nz < 60:
    bad.append("golfvorm komt niet door")
for f in (".voice_state", ".voice_waveform"):
    try: os.remove(os.path.join(bus, f))
    except OSError: pass
if bad:
    print("   KETEN NIET GESLOTEN: " + ", ".join(bad))
    sys.exit(1)
print("   KETEN GESLOTEN: het gezicht volgt de stem.")
PY
kill "$VIZ_PID" 2>/dev/null || true
rm -f /tmp/marqed-viz.pid

say "klaar — en geverifieerd"
cat <<TXT

Starten:
  praten + gezicht   cd "$HOME_DIR" && ./fullstack-agent/start.sh voice
  praten + handen    cd "$HOME_DIR" && ./fullstack-agent/start.sh hands
  alleen typen       cd "$HOME_DIR" && claude

De poort opnieuw draaien wanneer je wilt:
  "$HOME_DIR"/backtalk/.venv/bin/python "$HOME_DIR"/backtalk/verify.py

Wat er NIET is geïnstalleerd: de Obsidian-geheugenvault. Onze geheugenlaag
staat al in ~/.claude/projects/*/memory — zie MARQED.md.
TXT
