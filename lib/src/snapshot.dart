import 'game.dart';

class IdleCliSnapshot {
  static const String format = 'idle_cli.snapshot';
  static const int version = 1;

  final int dtMs;
  final int lastSeenMs;
  final IdleLabState state;

  const IdleCliSnapshot({
    required this.dtMs,
    required this.lastSeenMs,
    required this.state,
  });

  factory IdleCliSnapshot.create({
    required int dtMs,
    required IdleLabState state,
  }) {
    if (dtMs <= 0) {
      throw ArgumentError.value(dtMs, 'dtMs', 'Must be > 0');
    }
    return IdleCliSnapshot(dtMs: dtMs, lastSeenMs: 0, state: state);
  }

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

  IdleCliSnapshot copyWith({int? dtMs, int? lastSeenMs, IdleLabState? state}) {
    return IdleCliSnapshot(
      dtMs: dtMs ?? this.dtMs,
      lastSeenMs: lastSeenMs ?? this.lastSeenMs,
      state: state ?? this.state,
    );
  }

  Map<String, dynamic> toJson() => {
    'format': format,
    'version': version,
    'dtMs': dtMs,
    'lastSeenMs': lastSeenMs,
    'state': state.toJson(),
  };
}
