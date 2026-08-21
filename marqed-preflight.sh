#!/bin/bash
# fullstack-agent — MarQed preflight.
# Copyright (C) 2026 Jared Rhodenizer (upstream) — AGPL-3.0-or-later
#
# Zegt of deze machine klaar is vóór je 7 GB gaat downloaden.
# Werkt losstaand, dus ook zonder de repo:
#
#   curl -fsSL https://raw.githubusercontent.com/zeeneddie/fullstack-agent/main/marqed-preflight.sh | bash
#
# Exit 0 = ga je gang. Exit 1 = er is een blokkade; die staat erbij.
# Waarschuwingen blokkeren niet: ze vertellen wat er strákser kan.
BLOKKADES=0
WAARSCHUWINGEN=0

ok()   { printf '  \033[32mok\033[0m    %s\n' "$*"; }
warn() { printf '  \033[33mlet op\033[0m %s\n' "$*"; WAARSCHUWINGEN=$((WAARSCHUWINGEN+1)); }
blok() { printf '  \033[31mBLOK\033[0m  %s\n' "$*"; BLOKKADES=$((BLOKKADES+1)); }

echo ""
echo "== preflight: is deze machine klaar voor de spraak-/gezicht-stack? =="
echo ""

# --- besturingssysteem -------------------------------------------------
OS="$(uname -s)"
case "$OS" in
  Linux)  ok "Linux — $(. /etc/os-release 2>/dev/null; echo "${PRETTY_NAME:-onbekend}")" ;;
  Darwin) ok "macOS $(sw_vers -productVersion 2>/dev/null)" ;;
  *)      blok "$OS — dit script is bash (Linux/macOS). Op Windows gebruik je de wizard: claude \"set me up\"" ;;
esac

# --- gereedschap -------------------------------------------------------
command -v git >/dev/null     && ok "git $(git --version | awk '{print $3}')" || blok "git ontbreekt"
command -v python3 >/dev/null && ok "python3 $(python3 -V | awk '{print $2}') (uv haalt zelf 3.11 voor de omgeving)" \
                              || blok "python3 ontbreekt"
if command -v uv >/dev/null; then ok "uv $(uv --version | awk '{print $2}')"
else warn "uv ontbreekt — de installer haalt hem zelf op (astral.sh)"; fi

# --- Claude Code: het brein --------------------------------------------
if command -v claude >/dev/null; then
  ok "claude $(claude --version 2>/dev/null | awk '{print $1}')"
  if [ -f "$HOME/.claude/.credentials.json" ] || [ -s "$HOME/.claude.json" ]; then
    ok "claude lijkt ingelogd"
  else
    warn "geen inlog-sporen gevonden in ~/.claude — start één keer 'claude' en log in"
  fi
else
  blok "claude ontbreekt — de stem draait op de Claude Agent SDK, dus op je abonnement"
fi

# --- schijfruimte ------------------------------------------------------
VRIJ_KB=$(df -Pk "$HOME" | awk 'NR==2{print $4}')
VRIJ_GB=$((VRIJ_KB / 1024 / 1024))
if [ "$VRIJ_GB" -ge 8 ]; then ok "${VRIJ_GB} GB vrij in \$HOME (nodig: ~8 GB)"
else blok "${VRIJ_GB} GB vrij in \$HOME — er is ~8 GB nodig (omgeving 6,6 GB + modellen 1 GB)"; fi

# --- GPU ---------------------------------------------------------------
if command -v nvidia-smi >/dev/null 2>&1; then
  KAART=$(nvidia-smi --query-gpu=name --format=csv,noheader 2>/dev/null | head -1)
  DRIVER=$(nvidia-smi --query-gpu=driver_version --format=csv,noheader 2>/dev/null | head -1)
  MAJOR=${DRIVER%%.*}
  if [ -n "$MAJOR" ] && [ "$MAJOR" -ge 580 ] 2>/dev/null; then
    ok "$KAART, driver $DRIVER — spraakherkenning op GPU (~0,2 s)"
  else
    warn "$KAART, driver $DRIVER — torch's CUDA 13 wil >=580. Valt netjes terug op CPU (~2,2 s), breekt niet"
  fi
else
  warn "geen NVIDIA-kaart — alles op CPU. Spraakherkenning ~2,2 s in plaats van ~0,2 s, verder gelijk"
fi

# --- microfoon en luidsprekers -----------------------------------------
if [ "$OS" = "Linux" ]; then
  N=$(arecord -l 2>/dev/null | grep -c '^card')
  [ "${N:-0}" -gt 0 ] && ok "$N opnameapparaat(en) gevonden" || warn "geen opnameapparaat gevonden via arecord"
else
  ok "microfoon: macOS vraagt bij de eerste start zelf om toestemming"
fi

# --- de push-to-talk-toets ---------------------------------------------
if [ "$OS" = "Linux" ]; then
  case "${XDG_SESSION_TYPE:-onbekend}" in
    x11) ok "X11-sessie — de push-to-talk-toets werkt globaal" ;;
    wayland)
      warn "Wayland-sessie — een globale toets wordt daar vaak NIET afgevangen."
      warn "  Uitwegen: log in op een X11-sessie, of zet jezelf in de 'input'-groep"
      warn "  (sudo usermod -aG input \$USER, daarna uitloggen), of gebruik hands-free"
      warn "  luisteren: zeg 'go hands free' zodra de stem draait." ;;
    *) warn "sessietype onbekend (${XDG_SESSION_TYPE:-leeg}) — de globale toets is niet te voorspellen" ;;
  esac
else
  warn "macOS: geef je terminal Input Monitoring (Systeeminstellingen > Privacy & beveiliging)"
fi

# --- espeak-ng: library EN data ----------------------------------------
LIB=nee; DATA=nee
command -v espeak-ng >/dev/null 2>&1 && LIB=ja
for f in /opt/homebrew/lib/libespeak-ng.dylib /usr/local/lib/libespeak-ng.dylib \
         /usr/lib/x86_64-linux-gnu/libespeak-ng.so.1 /usr/lib/libespeak-ng.so.1; do
  [ -e "$f" ] && LIB=ja
done
for d in /usr/lib/x86_64-linux-gnu /usr/share /usr/local/share /usr/lib \
         /opt/homebrew/share /usr/local/opt/espeak-ng/share; do
  [ -f "$d/espeak-ng-data/phontab" ] && DATA=ja
done
if [ "$LIB" = ja ] && [ "$DATA" = ja ]; then
  ok "espeak-ng: library en data allebei aanwezig"
else
  warn "espeak-ng onvolledig (library=$LIB, data=$DATA) — de installer vraagt één keer om sudo."
  warn "  Let op: alleen de library is NIET genoeg. Dat is precies waar upstream op omviel."
fi

# --- internet ----------------------------------------------------------
for host in github.com huggingface.co; do
  if curl -fsS --max-time 8 -o /dev/null "https://$host" 2>/dev/null; then ok "$host bereikbaar"
  else blok "$host niet bereikbaar — de eerste installatie heeft internet nodig"; fi
done

# --- oordeel -----------------------------------------------------------
echo ""
if [ "$BLOKKADES" -gt 0 ]; then
  echo "== NIET klaar: $BLOKKADES blokkade(s), $WAARSCHUWINGEN waarschuwing(en) =="
  echo "   Los de BLOK-regels op en draai dit opnieuw."
  exit 1
fi
echo "== klaar om te installeren ($WAARSCHUWINGEN waarschuwing(en), geen blokkades) =="
echo ""
echo "   mkdir -p ~/my-agent && cd ~/my-agent"
echo "   git clone https://github.com/zeeneddie/fullstack-agent"
echo "   ./fullstack-agent/marqed-install.sh"
echo ""
