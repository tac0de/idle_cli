import 'package:idle_core/idle_core.dart';

import 'snapshot.dart';

/// Minimal state used by the `idle_cli` lab game.
///
/// This is intentionally small and deterministic so the CLI can serve as a
/// stable automation surface. Real games should define their own `IdleState`
/// in a shared package used by both the CLI and any app UI.
class IdleLabState extends IdleState {
  /// Number of ticks applied to reach this state.
  final int ticks;

  /// Current gold resource amount.
  final int gold;

  /// Number of miners; each tick adds `miners` gold.
  final int miners;

  /// Creates a new lab state with explicit fields.
  const IdleLabState({
    required this.ticks,
    required this.gold,
    required this.miners,
  });

  /// Creates the initial lab state, validating non-negative inputs.
  factory IdleLabState.initial({required int miners, required int gold}) {
    if (miners < 0) {
      throw ArgumentError.value(miners, 'miners', 'Must be >= 0');
    }
    if (gold < 0) {
      throw ArgumentError.value(gold, 'gold', 'Must be >= 0');
    }
    return IdleLabState(ticks: 0, gold: gold, miners: miners);
  }

  /// Decodes a lab state from JSON.
  ///
  /// Throws [FormatException] when required fields are missing or invalid.
  factory IdleLabState.fromJson(Map<String, dynamic> json) {
    final ticks = json['ticks'];
    final gold = json['gold'];
    final miners = json['miners'];
    if (ticks is! int || ticks < 0) {
      throw const FormatException('Invalid state.ticks');
    }
    if (gold is! int || gold < 0) {
      throw const FormatException('Invalid state.gold');
    }
    if (miners is! int || miners < 0) {
      throw const FormatException('Invalid state.miners');
    }
    return IdleLabState(ticks: ticks, gold: gold, miners: miners);
  }

  /// Encodes this state to JSON.
  @override
  Map<String, dynamic> toJson() => {
    'ticks': ticks,
    'gold': gold,
    'miners': miners,
  };
}

/// The built-in lab game reducer/engine for `idle_cli`.
class IdleLabGame {
  /// Identifier for this built-in game.
  static const String gameId = 'idle_cli.lab';

  /// Creates an [IdleEngine] configured to tick the given [snapshot].
  static IdleEngine<IdleLabState> createEngine({
    required IdleCliSnapshot snapshot,
  }) {
    return IdleEngine<IdleLabState>(
      config: IdleConfig<IdleLabState>(
        dtMs: snapshot.dtMs,
        resourceDelta: (before, after) => {'gold': after.gold - before.gold},
      ),
      reducer: reducer,
      state: snapshot.state,
    );
  }

  /// Reducer for the lab game.
  static IdleLabState reducer(IdleLabState state, IdleAction action) {
    if (action is IdleTickAction) {
      return IdleLabState(
        ticks: state.ticks + 1,
        gold: state.gold + state.miners,
        miners: state.miners,
      );
    }
    return state;
  }
}
