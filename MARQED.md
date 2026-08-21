# MarQed fork — wat hier afwijkt van upstream

Fork van **[jaredrhod/fullstack-agent](https://github.com/jaredrhod/fullstack-agent)**
(AGPL-3.0-or-later). Alle eer voor het origineel gaat naar Jared
Rhodenizer. Fork-punt: tag `fork-point-fdf0b71`.

## Wat er anders is

**1. De onderdelen komen uit onze eigen forks.** Fase 3 van de wizard
kloonde hardcoded van `github.com/jaredrhod/<naam>`; dat is nu
`github.com/zeeneddie/<naam>`. Zonder die wijziging staan onze forks er
wel, maar gebruikt de installatie ze niet — en dan mist de machine de
install-reparaties uit `zeeneddie/backtalk` en het offline bord uit
`zeeneddie/barehands`.

**2. `marqed-install.sh` — één commando, geen gesprek.** Upstream
installeert via een conversationele wizard. Die is prettig voor een
nieuwkomer en ongeschikt om twee machines identiek te krijgen. Dit script
doet hetzelfde zonder vragen, met gepinde versies, en eindigt op een
poort die de kéten toetst in plaats van hem aan te kondigen.

```bash
./marqed-install.sh [home-map]

MARQED_REF=v1.2      ./marqed-install.sh   # elk stuk op één git-ref
MARQED_SOURCE=/media/usb/stack ./marqed-install.sh   # zonder GitHub
```

**3. De geheugenvault wordt bewust niet geïnstalleerd.** Onze
geheugenlaag staat in `~/.claude/projects/*/memory` — ~470 getypeerde
feiten, git-versioneerd, met hooks en poorten eromheen. De upstream-wizard
wil `MEMORY.md` vervangen door een pointer naar een Obsidian-vault en
biedt aan 26 projecten te migreren. Wat we er wél uit meenemen is het
**Jobs**-patroon (één notitie per terugkerende taak: boot chain,
kwaliteitslat, en een *Lessons*-sectie waarin correcties terugvloeien) —
dat is de terugkoppeling die onze eigen laag mist.

## Wat de poorten meten

`marqed-install.sh` faalt hard, met exitcode, als een van deze twee niet
sluit:

1. **backtalk's eigen poort** (`verify.py`): spreekt een zin uit door de
   echte stem, laat de echte oren hem terugluisteren, en eist ≥70%
   woordbehoud. Die poort ving tijdens de bouw een breuk die verder
   groen leek.
2. **de ketenpoort** (in dit script): schrijft alle vier de bustoestanden
   en een golfvorm, en controleert via HTTP dat het gezicht ze terugmeldt.

## Gemeten (2026-08-21)

Ubuntu 24.04 · NVIDIA RTX A2000 Laptop (driver 580.173.02):

| poort | uitkomst |
|---|---|
| stem uit (Kokoro `bm_lewis`) | 4,6 s audio, eerste stuk na ~1,0 s |
| oren in (whisper `small.en`, GPU) | 0,21 s, 100% woordbehoud |
| oren in (CPU, ter vergelijking) | 2,16 s, 100% woordbehoud |
| brein (Claude Agent SDK op abonnement) | verbinding 6,8 s · eerste zin 1,8 s · mét tool-gebruik 4,4 s |
| keten stem → gezicht | alle vier de toestanden + golfvorm komen door |

**Niet gemeten, blijft handwerk:** microfoon en luidsprekers (vraagt een
mens die praat en luistert) en de gebaren van barehands (vraagt een
webcam en een hand).

## Licentie en herkomst

Ongewijzigd **AGPL-3.0-or-later**. Wijzigingen in deze fork vallen onder
dezelfde licentie; draait een gewijzigde versie als dienst voor derden,
dan hoort de broncode van díé versie beschikbaar te zijn. Dat is de reden
dat deze stack **naast** het platform staat en er geen onderdeel van is.

De vault-templates in `ai-memory-vault` staan onder **CC BY-SA 4.0** —
afgeleiden daarvan moeten dezelfde licentie dragen. Ook daarom nemen we
daar het patroon over en niet de tekst.

Links naar de vier onderdelen in `README.md` wijzen bewust nog naar
`jaredrhod/*`: dat is attributie, geen installatiebron.
