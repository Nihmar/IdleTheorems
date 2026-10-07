# Agent guidelines

## Language

- **English first.** All code, comments, UI copy, logs, commit messages and PR descriptions are in English.
- Other languages come later via an i18n layer; until then never hardcode non-English strings.

## Design source of truth

- `Idle Theorems.md` is the game design doc (mechanics, balance numbers, save format).
  Read the relevant sections before changing mechanics. Balance values there are a **v0 draft**:
  proportions matter, absolute values get validated by playtest (doc §13.11).

## Git workflow

- **Commit messages must be in English.** Keep them short and imperative (e.g. `Add theorem X`, not `Aggiunto il teorema X`).
- **Commit often.** Commit after every meaningful step (a new theorem, a bug fix, a small refactor) rather than batching large amounts of work into one commit.
- **One branch per feature.** For any non-trivial change, create a dedicated branch from `main` before starting work (e.g. `feature/add-theorem-x`). Small fixes may go directly on `main`.
- Push branches and open PRs against `main`.

## Interfacing with GitHub

Use the `gh` CLI for all interactions with GitHub (PRs, issues, checks, releases):

```bash
gh pr create --fill          # open a PR
gh pr list / gh pr view      # inspect PRs
gh run list                  # CI status
gh issue create              # report an issue
```

Do not use raw HTTPS calls or the web UI; prefer `gh` commands.

## Theme

- The light paper-and-ink palette lives in `lib/ui/theme/palette.dart`
  (paper background, ink text, gold accents). Use its constants everywhere;
  never hardcode raw colors in widgets.

## Code quality

- Follow `analysis_options.yaml`; no dead code, no unresolved TODOs.
- **Run `flutter analyze` and `dart fix --apply` often** — after every file
  change or batch of changes, not just at the end. Fix analyzer findings as
  you go; never accumulate warnings.
