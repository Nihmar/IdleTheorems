# Agent guidelines

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
