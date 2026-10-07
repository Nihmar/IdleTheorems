# Idle Theorems

An idle / incremental game about doing mathematics. You grind counting
arguments and proofs, publish papers, climb the academic career ladder,
discover conjectures — and eventually face the seven open problems of
mathematics.

The design source of truth is [`Idle Theorems.md`](Idle%20Theorems.md):
mechanics, balance numbers and the save format all live there. Balance
values are a v0 draft — proportions matter, absolute values are validated
by playtest (§13.11).

## Playing the loop

- **Research** generates *Counting* and *Proofing*; spend them on
  producers, schools, upgrades and publications.
- **Publish** papers to earn Fame and advance your career: Student →
  Postdoc → Assistant Professor → Associate Professor → Full Professor →
  Distinguished Professor → Professor Emeritus.
- **Discover conjectures** per subject, each paying out tier rewards and
  permanent multipliers. Tier 5 holds the seven famous open problems.
- **Manage burnout**: stress accumulates from publication desks and
  retracts; take a paid sabbatical or ride it out.
- **Hire apprentices** once you reach Professor: narrated researchers who
  add flat Counting/s before every multiplier.
- **Take on challenge runs** (Constructivist, No Paper, Encrypted):
  self-imposed restrictions for a one-time Legacy bonus and a permanent
  completion multiplier.
- **Prestige** at any time: banked Fame becomes *Legacy*, a permanent
  global multiplier, and restarts the run.

Progress persists locally as JSON, including offline earnings credited at
your passive rate while away.

## Stack

- Flutter + Dart
- [Flame](https://flamengine.com/) for the board canvas
- Riverpod for state (`lib/providers`)
- KaTeX rendering for theorem statements
- Local `json` saves with schema-version migration (`SaveData.version`)

Layout: pure models/services under `lib/domain`, Flame systems under
`lib/game`, widgets and theme under `lib/ui`.

## Developing

```sh
flutter pub get
flutter analyze        # keep it clean
dart fix --apply       # after batch changes
flutter test           # domain + widget tests
flutter run            # device/emulator
```

Release builds need an Android signing keystore configured in
`android/app/build.gradle.kts`; debug APKs build unsigned by default:

```sh
flutter build apk --debug
```

## Contributing conventions

See [AGENTS.md](AGENTS.md): English-first code and commits, one branch
per feature, frequent small commits, PRs via the `gh` CLI.
