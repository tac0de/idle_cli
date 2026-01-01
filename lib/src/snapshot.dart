import 'game.dart';

/// A portable snapshot of an `idle_cli` simulation.
///
/// Snapshots are intended to be deterministic and composable:
/// - Produced and consumed as JSON (stdin/stdout and files).
/// - Identified by [format] and [version] for safe decoding.
class IdleCliSnapshot {
  /// Snapshot discriminator used in JSON under the `format` key.
  static const String format = 'idle_cli.snapshot';

  /// Snapshot schema version used in JSON under the `version` key.
  static const int version = 1;

  /// Tick duration in milliseconds.
  final int dtMs;

  /// Total elapsed simulation time in milliseconds since the snapshot origin.
  final int lastSeenMs;

  /// The current game state payload for this snapshot.
  final IdleLabState state;

  /// Creates a snapshot with explicit fields.
  const IdleCliSnapshot({
    required this.dtMs,
    required this.lastSeenMs,
    required this.state,
  });

  /// Creates an initial snapshot with [lastSeenMs] set to `0`.
  ///
  /// Throws [ArgumentError] if [dtMs] is not positive.
  factory IdleCliSnapshot.create({
    required int dtMs,
    required IdleLabState state,
  }) {
    if (dtMs <= 0) {
      throw ArgumentError.value(dtMs, 'dtMs', 'Must be > 0');
    }
    return IdleCliSnapshot(dtMs: dtMs, lastSeenMs: 0, state: state);
  }

  /// Decodes a snapshot from JSON.
  ///
  /// Validates [format], [version], and the expected field types.
  /// Throws [FormatException] when the input is invalid.
  factory IdleCliSnapshot.fromJson(Map<String, dynamic> json) {
    final format = json['format'];
    if (format != IdleCliSnapshot.format) {
      throw const FormatException('Invalid snapshot.format');
    }
    final version = json['version'];
    if (version != IdleCliSnapshot.version) {
      throw const FormatException('Invalid snapshot.version');
    }
    final dtMs = json['dtMs'];
    final lastSeenMs = json['lastSeenMs'];
    final stateJson = json['state'];

    if (dtMs is! int || dtMs <= 0) {
      throw const FormatException('Invalid snapshot.dtMs');
    }
    if (lastSeenMs is! int || lastSeenMs < 0) {
      throw const FormatException('Invalid snapshot.lastSeenMs');
    }
    if (stateJson is! Map) {
      throw const FormatException('Invalid snapshot.state');
    }

    return IdleCliSnapshot(
      dtMs: dtMs,
      lastSeenMs: lastSeenMs,
      state: IdleLabState.fromJson(Map<String, dynamic>.from(stateJson)),
    );
  }

  /// Returns a copy of this snapshot with selected fields replaced.
  IdleCliSnapshot copyWith({int? dtMs, int? lastSeenMs, IdleLabState? state}) {
    return IdleCliSnapshot(
      dtMs: dtMs ?? this.dtMs,
      lastSeenMs: lastSeenMs ?? this.lastSeenMs,
      state: state ?? this.state,
    );
  }

  /// Encodes this snapshot to JSON.
  Map<String, dynamic> toJson() => {
    'format': format,
    'version': version,
    'dtMs': dtMs,
    'lastSeenMs': lastSeenMs,
    'state': state.toJson(),
  };
}
