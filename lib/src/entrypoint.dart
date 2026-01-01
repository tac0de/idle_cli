import 'dart:convert';
import 'dart:io';

import 'package:args/args.dart';
import 'package:idle_save/idle_save.dart';

import 'io.dart';
import 'snapshot.dart';
import 'game.dart';
import 'save.dart';

Future<int> runIdleCli(List<String> args, {CliIo? io}) async {
  final effectiveIo = io ?? CliIo.system();
  var debug = false;
  try {
    final parser = _buildParser();
    final results = parser.parse(args);
    debug = results['debug'] == true;

    if (results['help'] == true || results.command == null) {
      effectiveIo.writeJson(_helpJson(command: results.command?.name));
      return 0;
    }

    final command = results.command!;
    if (command['help'] == true) {
      effectiveIo.writeJson(_helpJson(command: command.name));
      return 0;
    }

    final action = switch (command.name) {
      'create' => _create(command, effectiveIo),
      'tick' => _tick(command, effectiveIo),
      'analyze' => _analyze(command, effectiveIo),
      'save' => _save(command, effectiveIo),
      'load' => _load(command, effectiveIo),
      'help' => _help(command, effectiveIo),
      _ => Future.value(
        _fail(
          effectiveIo,
          message: 'Unknown command: ${command.name}',
          details: {
            'command': command.name,
            'supported': const [
              'create',
              'tick',
              'analyze',
              'save',
              'load',
              'help',
            ],
          },
          debug: debug,
        ),
      ),
    };
    return await action;
  } on FormatException catch (e, st) {
    return _fail(
      effectiveIo,
      message: e.message,
      error: e,
      stackTrace: st,
      debug: debug,
    );
  } on ArgumentError catch (e, st) {
    return _fail(
      effectiveIo,
      message: e.message ?? 'Invalid argument',
      error: e,
      stackTrace: st,
      debug: debug,
    );
  } catch (e, st) {
    return _fail(
      effectiveIo,
      message: 'Unhandled error',
      error: e,
      stackTrace: st,
      debug: debug,
    );
  }
}

ArgParser _buildParser() {
  final parser = ArgParser()
    ..addFlag('help', abbr: 'h', negatable: false)
    ..addFlag('debug', negatable: false);

  parser.addCommand('help').addFlag('help', abbr: 'h', negatable: false);

  parser.addCommand('create')
    ..addFlag('help', abbr: 'h', negatable: false)
    ..addOption('dtMs', defaultsTo: '1000')
    ..addOption('miners', defaultsTo: '1')
    ..addOption('gold', defaultsTo: '0');

  parser.addCommand('tick')
    ..addFlag('help', abbr: 'h', negatable: false)
    ..addOption('count', defaultsTo: '1')
    ..addOption('in');

  parser.addCommand('analyze')
    ..addFlag('help', abbr: 'h', negatable: false)
    ..addOption('in');

  parser.addCommand('save')
    ..addFlag('help', abbr: 'h', negatable: false)
    ..addOption('path')
    ..addOption('backup')
    ..addOption('in');

  parser.addCommand('load')
    ..addFlag('help', abbr: 'h', negatable: false)
    ..addOption('path');

  return parser;
}

Future<int> _help(ArgResults _, CliIo io) async {
  io.writeJson(_helpJson(command: null));
  return 0;
}

Map<String, dynamic> _helpJson({required String? command}) {
  return {
    'ok': true,
    'command': 'help',
    if (command != null) 'for': command,
    'globalFlags': {
      '--help': 'Prints JSON help.',
      '--debug': 'Includes stack traces in error JSON.',
    },
    'exitCodes': {
      '0': 'Success',
      '1': 'CLI/runtime error',
      '2': 'Save/load failure',
    },
    'inputFormats': {
      'snapshot': 'Raw snapshot JSON with format=${IdleCliSnapshot.format}.',
      'commandOutput': 'Previous command JSON that contains {snapshot: ...}.',
    },
    'commands': {
      'create': {
        'args': {
          '--dtMs': 'Tick size in ms (default: 1000).',
          '--miners': 'Starting miners (default: 1).',
          '--gold': 'Starting gold (default: 0).',
        },
        'output': 'IdleCliSnapshot JSON',
      },
      'tick': {
        'args': {
          '--count': 'Number of ticks to apply (default: 1).',
          '--in': 'Optional JSON file path for snapshot input.',
        },
        'input': 'Snapshot JSON or {snapshot: ...} (stdin or --in)',
        'output': 'IdleCliSnapshot JSON',
      },
      'analyze': {
        'args': {'--in': 'Optional JSON file path for snapshot input.'},
        'input': 'Snapshot JSON or {snapshot: ...} (stdin or --in)',
        'output': 'Metrics JSON',
      },
      'save': {
        'args': {
          '--path': 'File path to write envelope JSON.',
          '--backup': 'Optional backup file path.',
          '--in': 'Optional JSON file path for snapshot input.',
        },
        'input': 'Snapshot JSON or {snapshot: ...} (stdin or --in)',
        'output': 'Save metadata JSON',
      },
      'load': {
        'args': {'--path': 'File path to read envelope JSON.'},
        'output': 'IdleCliSnapshot JSON',
      },
    },
    'examples': {
      'compileOnce': ['dart compile exe bin/idle.dart -o idle', './idle help'],
      'pipe': [
        './idle create | ./idle tick --count 10 | ./idle analyze',
        './idle create | ./idle save --path save.json',
      ],
      'files': [
        './idle create > s.json',
        './idle tick --count 10 --in s.json > s2.json',
        './idle analyze --in s2.json',
      ],
    },
    'notes': [
      'All stdout is JSON only.',
      'Errors are JSON written to stderr with non-zero exit code.',
      'Commands are composable via stdin/stdout.',
    ],
  };
}

Future<int> _create(ArgResults args, CliIo io) async {
  final dtMs = int.parse(args['dtMs'] as String);
  final miners = int.parse(args['miners'] as String);
  final gold = int.parse(args['gold'] as String);

  final snapshot = IdleCliSnapshot.create(
    dtMs: dtMs,
    state: IdleLabState.initial(miners: miners, gold: gold),
  );

  io.writeJson({
    'ok': true,
    'command': 'create',
    'snapshot': snapshot.toJson(),
  });
  return 0;
}

Future<int> _tick(ArgResults args, CliIo io) async {
  final count = int.parse(args['count'] as String);
  if (count < 0) {
    throw ArgumentError.value(count, 'count', 'Must be >= 0');
  }

  final snapshot = await _readSnapshot(io, inputPath: args['in'] as String?);
  final engine = IdleLabGame.createEngine(snapshot: snapshot);
  final tickResult = engine.tick(count: count);

  final next = snapshot.copyWith(
    lastSeenMs: snapshot.lastSeenMs + (count * snapshot.dtMs),
    state: tickResult.state,
  );

  io.writeJson({
    'ok': true,
    'command': 'tick',
    'ticksApplied': tickResult.ticksApplied,
    'resourcesDelta': tickResult.resourcesDelta,
    'snapshot': next.toJson(),
  });
  return 0;
}

Future<int> _analyze(ArgResults args, CliIo io) async {
  final snapshot = await _readSnapshot(io, inputPath: args['in'] as String?);
  final state = snapshot.state;
  final goldPerTick = state.miners;
  final goldPerSecond = goldPerTick * (1000 / snapshot.dtMs);

  io.writeJson({
    'ok': true,
    'command': 'analyze',
    'analysis': {
      'dtMs': snapshot.dtMs,
      'lastSeenMs': snapshot.lastSeenMs,
      'ticks': state.ticks,
      'gold': state.gold,
      'miners': state.miners,
      'goldPerTick': goldPerTick,
      'goldPerSecond': goldPerSecond,
    },
  });
  return 0;
}

Future<int> _save(ArgResults args, CliIo io) async {
  final path = args['path'] as String?;
  if (path == null || path.isEmpty) {
    throw const FormatException('Missing required --path');
  }

  final snapshot = await _readSnapshot(io, inputPath: args['in'] as String?);

  final manager = IdleCliSave.managerForPath(
    path: path,
    backupPath: args['backup'] as String?,
    nowMs: snapshot.lastSeenMs,
  );

  final result = await manager.save(
    snapshot.toJson(),
    context: SaveContext(
      reason: SaveReason.manual,
      changeSet: SaveChangeSet.unknown(note: 'idle_cli.save'),
    ),
  );

  io.writeJson({
    'ok': result is SaveSuccess,
    'command': 'save',
    'path': path,
    'result': _saveResultJson(result),
  });

  return result is SaveSuccess ? 0 : 2;
}

Future<int> _load(ArgResults args, CliIo io) async {
  final path = args['path'] as String?;
  if (path == null || path.isEmpty) {
    throw const FormatException('Missing required --path');
  }

  final manager = IdleCliSave.managerForPath(path: path, nowMs: 0);
  final result = await manager.load();

  if (result case LoadSuccess<Map<String, dynamic>>(
    :final value,
    :final envelope,
    :final migrated,
    :final fromBackup,
  )) {
    final snapshot = IdleCliSnapshot.fromJson(value);
    io.writeJson({
      'ok': true,
      'command': 'load',
      'envelope': envelope.toJson(),
      'migrated': migrated,
      'fromBackup': fromBackup,
      'snapshot': snapshot.toJson(),
    });
    return 0;
  }

  final failure = result as LoadFailure;
  io.writeJson({
    'ok': false,
    'command': 'load',
    'error': {
      'reason': failure.reason.name,
      if (failure.error != null) 'error': failure.error.toString(),
    },
  }, toStderr: true);
  return 2;
}

Map<String, dynamic> _saveResultJson(SaveResult result) {
  return switch (result) {
    SaveSuccess(
      :final envelope,
      :final context,
      :final backupWritten,
      :final raw,
    ) =>
      {
        'type': 'success',
        'envelope': envelope.toJson(),
        'context': _saveContextJson(context),
        'backupWritten': backupWritten,
        'rawLength': raw.length,
      },
    SaveFailure(
      :final reason,
      :final context,
      :final backupWritten,
      :final primaryWritten,
      :final error,
      :final envelope,
      :final raw,
    ) =>
      {
        'type': 'failure',
        'reason': reason.name,
        'context': _saveContextJson(context),
        'backupWritten': backupWritten,
        'primaryWritten': primaryWritten,
        if (error != null) 'error': error.toString(),
        if (envelope != null) 'envelope': envelope.toJson(),
        if (raw != null) 'rawLength': raw.length,
      },
  };
}

Map<String, dynamic> _saveContextJson(SaveContext context) {
  return {
    'reason': context.reason.value,
    'changeSet': context.changeSet.toJson(),
  };
}

Future<IdleCliSnapshot> _readSnapshot(CliIo io, {String? inputPath}) async {
  if (inputPath == null && io.stdinHasTerminal) {
    throw const FormatException(
      'Missing input snapshot. Provide stdin (pipe) or pass --in <snapshot.json>.',
    );
  }
  final raw = inputPath != null
      ? await File(inputPath).readAsString()
      : await io.readStdinOrFail();
  final decoded = _decodeJsonFromPossiblyNoisyInput(raw);
  if (decoded is! Map) {
    throw const FormatException(
      'Expected a JSON object (snapshot JSON or {snapshot: ...}).',
    );
  }
  return _snapshotFromCommandOrSnapshotJson(Map<String, dynamic>.from(decoded));
}

Object _decodeJsonFromPossiblyNoisyInput(String raw) {
  final trimmed = raw.trim();
  if (trimmed.isEmpty) {
    throw const FormatException('Empty input.');
  }

  try {
    return jsonDecode(trimmed);
  } on FormatException {
    final lines = const LineSplitter().convert(raw);
    for (final line in lines.reversed) {
      final candidate = line.trim();
      if (candidate.isEmpty) continue;
      if (!candidate.startsWith('{') && !candidate.startsWith('[')) continue;
      try {
        return jsonDecode(candidate);
      } on FormatException {
        continue;
      }
    }
    throw const FormatException(
      'Input is not valid JSON. If using `dart run`, build logs may be mixed '
      'into stdout; prefer a compiled `idle` executable or pass `--in`.',
    );
  }
}

IdleCliSnapshot _snapshotFromCommandOrSnapshotJson(Map<String, dynamic> json) {
  final snapshot = json['snapshot'];
  if (snapshot is Map) {
    return IdleCliSnapshot.fromJson(Map<String, dynamic>.from(snapshot));
  }

  try {
    return IdleCliSnapshot.fromJson(json);
  } on FormatException {
    final keys = json.keys.toList(growable: false);
    throw FormatException(
      'Expected snapshot JSON (format=${IdleCliSnapshot.format}) or command '
      'output JSON with a {snapshot: ...} field. Got keys: $keys',
    );
  }
}

int _fail(
  CliIo io, {
  required String message,
  Object? error,
  StackTrace? stackTrace,
  Map<String, dynamic>? details,
  required bool debug,
}) {
  io.writeJson({
    'ok': false,
    'error': {
      'message': message,
      if (details != null) 'details': details,
      if (error != null) 'type': error.runtimeType.toString(),
      if (error != null) 'error': error.toString(),
      if (debug && stackTrace != null) 'stackTrace': stackTrace.toString(),
    },
  }, toStderr: true);
  return 1;
}
