/// Deterministic, JSON-only CLI for `idle_core` simulations.
///
/// This package is designed to be an automation-friendly execution surface:
/// state flows through stdin/stdout as JSON, and time advances only via `tick`.
///
/// The public API exposes:
/// - [runIdleCli] — the CLI entrypoint used by `bin/idle.dart`.
/// - [IdleCliSnapshot] — a portable snapshot schema for piping and save/load.
library;

export 'src/entrypoint.dart' show runIdleCli;
export 'src/snapshot.dart' show IdleCliSnapshot;
