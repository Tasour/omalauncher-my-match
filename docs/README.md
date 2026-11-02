# Documentation

Start with the [project README](../README.md), then pick the layer you need.

## Understand

- [Architecture](architecture.md) — data flow, caches, handoff and xG pipeline.
- [Data notice](data-notice.md) — sources, local caches, attribution and removal.
- [xG trajectory](design/trajectory-xg-2026-11-01.md) — why the chart exists,
  how to read crossings, and what it deliberately does not claim.

## Design and delivery

- [Feature proposals](design/features-proposals.md) — shipped work and backlog.
- [v5.10 improvements](design/improvements-2026-10-28.md) — the measured audit
  remediation plan.
- [100-user simulation](design/user-simulation-100.md) — product research notes.
- [CI workflow template](ci-workflow.yml) — copy to `.github/workflows/ci.yml`
  when the repository token has the `workflow` scope.

## Audits and measurements

Current, focused audits:

- [Data sources](audits/data-sources-2026-11-01.md)
- [Performance](audits/performance-2026-10-31.md)
- [Pre-match UX/accessibility/data](audits/prematch-2026-10-31.md)

Historical device measurements:

- [Device baseline, 2026-10-25](measurements/2026-10-25.md)
- [Reproducible v5.10 protocol](measurements/v5.10.0.md)

## Reports

The large HTML reports are kept for traceability, not as onboarding material:

- [Initial my-match audit](reports/audit-my-match.html)
- [Multi-expert audit](reports/audit-multi-expert-my-matches-2026-10-28.html)
- [Omalauncher energy audit](reports/audit-omalauncher-2026-10-25.html)
- [Omalauncher V-cycle](reports/cycle-en-v-omalauncher.html)
- [My Matches V-cycle](reports/cycle-en-v-my-matches-2026-11-01.html)

The initial audit notes are archived under
[`audits/archive/initial/`](audits/archive/initial/).
