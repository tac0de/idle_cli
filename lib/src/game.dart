import 'package:idle_core/idle_core.dart';

import 'snapshot.dart';

class IdleLabState extends IdleState {
  final int ticks;
  final int gold;
  final int miners;

  const IdleLabState({
    required this.ticks,
    required this.gold,
    required this.miners,
  });

  factory IdleLabState.initial({required int miners, required int gold}) {
    if (miners < 0) {
      throw ArgumentError.value(miners, 'miners', 'Must be >= 0');
    }
    if (gold < 0) {
      throw ArgumentError.value(gold, 'gold', 'Must be >= 0');
    }
    return IdleLabState(ticks: 0, gold: gold, miners: miners);
  }

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

  @override
  Map<String, dynamic> toJson() => {
    'ticks': ticks,
    'gold': gold,
    'miners': miners,
  };
}

class IdleLabGame {
  static const String gameId = 'idle_cli.lab';

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
