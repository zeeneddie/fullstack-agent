# Snelstart — de stack op een nieuwe machine

Drie stappen, drie scripts. Linux of macOS (bash). Op Windows werkt deze
route niet; gebruik daar de conversationele wizard: `claude "set me up"`.

---

## 1. Is deze machine er klaar voor?

Dit hoeft nog niets te downloaden en heeft de repo niet nodig:

```bash
curl -fsSL https://raw.githubusercontent.com/zeeneddie/fullstack-agent/main/marqed-preflight.sh | bash
```

Groen = ga je gang. Rood = de blokkade staat erbij, met wat je moet doen.
Waarschuwingen blokkeren niet — die vertellen wat er strákser kan.

Waar hij op let, en waarom:

| controle | waarom |
|---|---|
| `claude` aanwezig **en ingelogd** | de stem draait op de Claude Agent SDK, dus op je abonnement |
| ~8 GB vrij in `$HOME` | omgeving 6,6 GB (torch draagt de CUDA-runtime) + modellen 1 GB |
| NVIDIA-driver ≥ 580 | dan draait de spraakherkenning op GPU (~0,2 s); anders CPU (~2,2 s), hij breekt niet |
| X11 of Wayland | onder Wayland wordt een **globale** toets vaak niet afgevangen — zie de uitwegen die hij noemt |
| espeak-ng: library **én data** | alleen de library is niet genoeg; dat is precies waar upstream op omviel |
| github.com + huggingface.co | de eerste installatie heeft internet nodig |

---

## 2. Installeren

```bash
mkdir -p ~/my-agent && cd ~/my-agent
git clone https://github.com/zeeneddie/fullstack-agent
./fullstack-agent/marqed-install.sh
```

Hij draait de preflight zelf nog een keer en stopt als die rood is.
Daarna, zonder verdere vragen: de drie onderdelen klonen, één keer sudo
als `espeak-ng` ontbreekt, de omgeving bouwen uit `requirements.lock.txt`
(419 gepinde pakketten), de modellen ophalen, en **twee poorten draaien**:

1. **de stem-poort** — spreekt een zin uit, luistert hem terug, eist ≥ 70 % woordbehoud
2. **de keten-poort** — schrijft alle vier de bustoestanden plus een golfvorm en controleert via HTTP dat het gezicht ze terugmeldt

Het eindigt op `KETEN GESLOTEN` en exitcode 0, of het faalt hard en zegt
welke helft het was. Reken op 10–20 minuten, vrijwel alles downloaden.

**Varianten:**

```bash
MARQED_REF=v1.2 ./fullstack-agent/marqed-install.sh          # elk stuk op één git-ref
MARQED_SOURCE=/media/usb/stack ./fullstack-agent/marqed-install.sh   # zonder GitHub
./fullstack-agent/marqed-install.sh --skip-preflight          # jouw verantwoordelijkheid
```

---

## 3. Starten

```bash
cd ~/my-agent
./fullstack-agent/marqed-start.sh          # stem + gezicht
./fullstack-agent/marqed-start.sh hands    # stem + het gebarenbord
./fullstack-agent/marqed-start.sh all      # allebei
./fullstack-agent/marqed-start.sh check    # alleen de poort, start niets
```

Hij leest de talk-toets uit jóuw config en zegt de spraakcommando's erbij.
Standaard: **hou de Home-toets ingedrukt, praat, laat los.** Indrukken
terwijl hij praat onderbreekt hem; verder is de microfoon dicht.

Hardop, zonder toetsenbord: `"go hands free"` · `"push to talk mode"` ·
`"stop asking for permission"` (daarna `"confirm"`) ·
`"switch to the deep model"` · `"usage report"`.

Wil je alleen typen: `claude` in `~/my-agent`. Dat is dezelfde agent, met
hetzelfde geheugen en dezelfde persoonlijkheid.

---

## Als het misgaat

```bash
./fullstack-agent/marqed-start.sh check     # zegt of het de mond of de oren is
```

- `~/my-agent/backtalk/logs/backtalk.log` — de details
- `~/my-agent/backtalk/MARQED.md` — de drie breuken die we hebben gerepareerd, met
  de foutmelding erbij. Herken je er één, dan staat de oorzaak er meteen naast.
- De agent is zelf de monteur: open `claude` in `~/my-agent` en beschrijf wat er
  misgaat. Zijn `CLAUDE.md` draagt die opdracht.

## Wie is de agent?

`~/my-agent/CLAUDE.md`. Het installatiescript schrijft daar een minimale
identiteit; naam, toon en welkomstregel pas je daar aan. De stem heeft
bewust géén eigen persoonlijkheid — hij is de mond van wie dat bestand
beschrijft.

## Wat er bewust NIET is geïnstalleerd

De Obsidian-geheugenvault. Onze geheugenlaag staat al in
`~/.claude/projects/*/memory`, en de upstream-wizard wil `MEMORY.md`
vervangen door een pointer en projecten migreren. Zie `MARQED.md`.
