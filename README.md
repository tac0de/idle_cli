# idle_cli

Deterministic, JSON-only CLI for running `idle_core` simulations and persisting
portable snapshots via `idle_save`.

## Why this exists

`idle_cli` is designed as an automation-friendly “execution surface” for idle
game simulations:

- **Deterministic laboratory tool**: advance time only when you call `tick`.
- **Composable**: stdin/stdout JSON lets you pipe commands and build scripts.
- **MCP/agent-friendly**: a Codex agent can `create → tick → analyze → save` as a
  reproducible workflow.
- **Flutter compatibility goal**: intended to interoperate with Flutter apps
  that use `idle_core` + `idle_save` (and optionally `idle_flutter`) by sharing
  the same state schema and migration chain. For true “save file compatibility”,
  put your game’s `IdleState`/reducer/codec/migrations in a shared Dart package
  and use it from both the app and this CLI.

## Commands

- `idle create`
- `idle tick`
- `idle analyze`
- `idle save`
- `idle load`

All stdout is valid JSON. Errors are JSON written to stderr with a non-zero exit
code.

`tick`, `analyze`, and `save` accept either:

- a raw snapshot JSON (`format: "idle_cli.snapshot"`)
- or a previous command output JSON that contains `{ "snapshot": ... }`

## Quickstart (Recommended)

`dart run` may print Dart tool build logs to stdout before your program runs.
For predictable JSON-only streams (automation, piping), compile once and run the
binary:

```sh
dart compile exe bin/idle.dart -o idle
./idle help
```

If you prefer `dart run`, it still works; the CLI tolerates leading non-JSON
lines when reading from stdin.

## I/O Rules

- Commands that _consume_ state read from stdin (pipe) or `--in <path>`.
- Commands that _produce_ state return it as JSON on stdout.
- Errors are JSON on stderr; pass `--debug` to include a stack trace.

Exit codes:

- `0`: success
- `1`: CLI usage / validation / runtime error
- `2`: save/load failure (e.g. corrupt file, checksum mismatch)

## Common Workflows

### 1) Fast simulation via piping

Create → tick → analyze:

```sh
./idle create | ./idle tick --count 10 | ./idle analyze
```

### 2) File-based progression (no long pipes)

Important: `>` redirects output; it does not provide input. To _read_ from a
file, use `--in`.

```sh
./idle create > s.json
./idle tick --count 10 --in s.json > s2.json
./idle analyze --in s2.json
```

### 3) Save / load snapshots

Save current snapshot to `save.json`:

```sh
./idle create | ./idle save --path save.json
```

Load then analyze:

```sh
./idle load --path save.json | ./idle analyze
```

### 4) Branch experiments (A/B)

```sh
./idle create > base.json

./idle tick --count 10 --in base.json > a.json
./idle tick --count 100 --in base.json > b.json

./idle analyze --in a.json
./idle analyze --in b.json
```

## Command Reference

### `idle create`

Creates a new snapshot (fresh state).

- Options: `--dtMs`, `--miners`, `--gold`
- Output: `{ ok, command: "create", snapshot: IdleCliSnapshot }`

Example:

```sh
./idle create --miners 3 --gold 10 > s.json
```

### `idle tick`

Advances time by applying `--count` ticks to the input snapshot.

- Input: snapshot JSON via stdin or `--in <path>`
- Options: `--count` (default `1`), `--in`
- Output: `{ ok, command: "tick", ticksApplied, resourcesDelta, snapshot }`

Examples:

```sh
./idle create | ./idle tick --count 10 > s.json
./idle tick --count 10 --in s.json > s2.json
```

### `idle analyze`

Computes derived metrics from a snapshot.

- Input: snapshot JSON via stdin or `--in <path>`
- Output: `{ ok, command: "analyze", analysis: {...} }`

Example:

```sh
./idle analyze --in s.json
```

### `idle save`

Persists a snapshot using `idle_save` envelope + canonical JSON encoding.

- Input: snapshot JSON via stdin or `--in <path>`
- Options: `--path <file>`, optional `--backup <file>`
- Output: `{ ok, command: "save", result: {...} }`

Example:

```sh
./idle create | ./idle save --path save.json
```

### `idle load`

Loads a snapshot from a save envelope file.

- Options: `--path <file>`
- Output: `{ ok, command: "load", snapshot: IdleCliSnapshot, ... }`

Example:

```sh
./idle load --path save.json > s.json
```

## Troubleshooting

- `tick` says “Missing input snapshot”: you must pipe a snapshot or pass `--in`.
  Example: `./idle create | ./idle tick --count 10 > s.json`
- Want stack traces in errors: add `--debug` (e.g. `./idle tick --debug ...`).

## Related packages

- `idle_core`: deterministic engine primitives (state, reducer, tick/offline)
- `idle_save`: versioned envelope, migration chain, canonical JSON helpers
- `idle_flutter`: Flutter binding layer (lifecycle, stores, widgets)
