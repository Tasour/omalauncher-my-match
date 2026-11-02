# Contributing

Keep the project local-first, readable on a phone, and safe to run from an OWL
file. A change is ready when the offline suite passes and both production files
still compile.

## Before opening a pull request

```sh
make test-all
owl-check widget/my-match.optimized.owl
owl-check widget/prematch.owl
```

If `owl-check` is not installed, run the offline suite at minimum and say so in
the pull request.

## Guidelines

- Do not add secrets, tokens, personal paths or private IP addresses.
- Do not make the live tile depend on a network call that can fail: keep the
  cache-first fallback.
- Keep scripts POSIX/bash compatible with the Linux guest of Omalauncher.
- Document a new data source, its cache path, its refresh budget and its failure
  mode in `docs/architecture.md` and `docs/data-notice.md`.
- Preserve the MIT licence for code and the attribution for data, crests and
  trademarks.
- Keep screenshots in `docs/assets/screens/` and diagrams in
  `docs/assets/diagrams/`; they are part of the product documentation.

## Commit style

Use a short, scoped message, for example:

```text
feat(v5.22.9): 20-match xG trajectory and pre-match handoff
fix(prematch): keep the selected match on a warm app
docs(readme): explain the data pipeline
```
