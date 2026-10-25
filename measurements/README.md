# Mesures

Protocole et relevés bruts, avant et après optimisation.

## Dossiers

- `before/` : état avec le widget `my-match` actuel.
- `after/` : état avec le widget optimisé.

## À relever

- CPU par PID et par UID (deltas `/proc/<pid>/stat`).
- `dumpsys gfxinfo` sur 30 s au repos.
- Delta CPU écran éteint sur 60 s.
- `dumpsys netstats` (octets Wi-Fi/mobile).
- `dumpsys meminfo` (PSS).
- Processus invités (`ps -A -o PID,PPID,NAME`) et orphelins.
- `dumpsys batterystats --charged dev.omalauncher`.
- Test de décharge débranché 30–60 min.

Les commandes exactes sont dans `scripts/measure.sh`.
