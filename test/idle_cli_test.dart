import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:idle_cli/idle_cli.dart';
import 'package:idle_cli/src/game.dart';
import 'package:idle_cli/src/io.dart';
import 'package:test/test.dart';

void main() {
  test('help is valid JSON and includes examples', () async {
    final stdoutLines = <String>[];
    final stderrLines = <String>[];
    final io = CliIo.forTesting(
      stdin: const Stream<List<int>>.empty(),
      stdinHasTerminal: true,
      writeStdoutLine: stdoutLines.add,
      writeStderrLine: stderrLines.add,
    );

    final code = await runIdleCli(['help'], io: io);

    expect(code, 0);
    expect(stderrLines, isEmpty);
    final decoded = jsonDecode(stdoutLines.single) as Map<String, dynamic>;
    expect(decoded['ok'], true);
    expect(decoded['command'], 'help');
    expect(decoded['exitCodes'], isA<Map>());
    expect(decoded['examples'], isA<Map>());
  });

  test('create output can be piped into tick', () async {
    final createStdout = <String>[];
    final createStderr = <String>[];
    final createIo = CliIo.forTesting(
      stdin: const Stream<List<int>>.empty(),
      stdinHasTerminal: true,
      writeStdoutLine: createStdout.add,
      writeStderrLine: createStderr.add,
    );

    final createCode = await runIdleCli(['create'], io: createIo);
    expect(createCode, 0);
    expect(createStderr, isEmpty);
    expect(createStdout, hasLength(1));

    final tickStdout = <String>[];
    final tickStderr = <String>[];
    final tickIo = CliIo.forTesting(
      stdin: Stream<List<int>>.fromIterable([utf8.encode(createStdout.single)]),
      stdinHasTerminal: false,
      writeStdoutLine: tickStdout.add,
      writeStderrLine: tickStderr.add,
    );

    final tickCode = await runIdleCli(['tick', '--count', '10'], io: tickIo);
    expect(tickCode, 0);
    expect(tickStderr, isEmpty);

    final decoded = jsonDecode(tickStdout.single) as Map<String, dynamic>;
    final next = IdleCliSnapshot.fromJson(
      Map<String, dynamic>.from(decoded['snapshot'] as Map),
    );
    expect(next.state.ticks, 10);
  });

  test('parser ignores leading non-JSON lines', () async {
    final noisy = [
      'Building package executable...',
      'Built idle_cli:idle.',
      jsonEncode({
        'ok': true,
        'command': 'create',
        'snapshot': IdleCliSnapshot.create(
          dtMs: 1000,
          state: IdleLabState.initial(miners: 1, gold: 0),
        ).toJson(),
      }),
    ].join('\n');

    final stdoutLines = <String>[];
    final stderrLines = <String>[];
    final io = CliIo.forTesting(
      stdin: Stream<List<int>>.fromIterable([utf8.encode(noisy)]),
      stdinHasTerminal: false,
      writeStdoutLine: stdoutLines.add,
      writeStderrLine: stderrLines.add,
    );

    final code = await runIdleCli(['tick'], io: io);
    expect(code, 0);
    expect(stderrLines, isEmpty);
  });

  test('create outputs a snapshot JSON', () async {
    final stdoutLines = <String>[];
    final stderrLines = <String>[];
    final io = CliIo.forTesting(
      stdin: const Stream<List<int>>.empty(),
      stdinHasTerminal: true,
      writeStdoutLine: stdoutLines.add,
      writeStderrLine: stderrLines.add,
    );

    final code = await runIdleCli(['create'], io: io);

    expect(code, 0);
    expect(stderrLines, isEmpty);
    expect(stdoutLines, hasLength(1));

    final decoded = jsonDecode(stdoutLines.single) as Map<String, dynamic>;
    expect(decoded['ok'], true);
    expect(decoded['command'], 'create');
    expect(decoded['snapshot'], isA<Map>());

    final snapshot = IdleCliSnapshot.fromJson(
      Map<String, dynamic>.from(decoded['snapshot'] as Map),
    );
    expect(snapshot.dtMs, 1000);
    expect(snapshot.lastSeenMs, 0);
    expect(snapshot.state.ticks, 0);
  });

  test('tick fails if stdin is missing', () async {
    final stdoutLines = <String>[];
    final stderrLines = <String>[];
    final io = CliIo.forTesting(
      stdin: const Stream<List<int>>.empty(),
      stdinHasTerminal: true,
      writeStdoutLine: stdoutLines.add,
      writeStderrLine: stderrLines.add,
    );

    final code = await runIdleCli(['tick'], io: io);

    expect(code, isNonZero);
    expect(stdoutLines, isEmpty);
    expect(stderrLines, hasLength(1));
    final decoded = jsonDecode(stderrLines.single) as Map<String, dynamic>;
    expect(decoded['ok'], false);
  });

  test('tick advances state deterministically', () async {
    final snapshotJson = IdleCliSnapshot.create(
      dtMs: 1000,
      state: IdleLabState.initial(miners: 2, gold: 5),
    ).toJson();

    final input = utf8.encode(jsonEncode(snapshotJson));
    final stdoutLines = <String>[];
    final stderrLines = <String>[];
    final io = CliIo.forTesting(
      stdin: Stream<List<int>>.fromIterable([input]),
      stdinHasTerminal: false,
      writeStdoutLine: stdoutLines.add,
      writeStderrLine: stderrLines.add,
    );

    final code = await runIdleCli(['tick', '--count', '3'], io: io);

    expect(code, 0);
    expect(stderrLines, isEmpty);
    final decoded = jsonDecode(stdoutLines.single) as Map<String, dynamic>;
    final next = IdleCliSnapshot.fromJson(
      Map<String, dynamic>.from(decoded['snapshot'] as Map),
    );
    expect(next.state.ticks, 3);
    expect(next.state.gold, 5 + (2 * 3));
    expect(next.lastSeenMs, 3 * 1000);
  });

  test('save and load round-trip snapshot', () async {
    final tmpDir = Directory(
      '.dart_tool/idle_cli_test_${DateTime.now().microsecondsSinceEpoch}',
    )..createSync(recursive: true);
    addTearDown(() async {
      if (tmpDir.existsSync()) {
        await tmpDir.delete(recursive: true);
      }
    });
    final savePath = '${tmpDir.path}${Platform.pathSeparator}save.json';

    final snapshot = IdleCliSnapshot.create(
      dtMs: 1000,
      state: IdleLabState.initial(miners: 1, gold: 0),
    );

    final saveStdout = <String>[];
    final saveStderr = <String>[];
    final saveIo = CliIo.forTesting(
      stdin: Stream<List<int>>.fromIterable([
        utf8.encode(jsonEncode(snapshot.toJson())),
      ]),
      stdinHasTerminal: false,
      writeStdoutLine: saveStdout.add,
      writeStderrLine: saveStderr.add,
    );

    final saveCode = await runIdleCli(['save', '--path', savePath], io: saveIo);
    expect(saveCode, 0);
    expect(saveStderr, isEmpty);
    expect(File(savePath).existsSync(), true);

    final loadStdout = <String>[];
    final loadStderr = <String>[];
    final loadIo = CliIo.forTesting(
      stdin: const Stream<List<int>>.empty(),
      stdinHasTerminal: true,
      writeStdoutLine: loadStdout.add,
      writeStderrLine: loadStderr.add,
    );
    final loadCode = await runIdleCli(['load', '--path', savePath], io: loadIo);
    expect(loadCode, 0);
    expect(loadStderr, isEmpty);

    final decoded = jsonDecode(loadStdout.single) as Map<String, dynamic>;
    final loaded = IdleCliSnapshot.fromJson(
      Map<String, dynamic>.from(decoded['snapshot'] as Map),
    );
    expect(loaded.toJson(), snapshot.toJson());
  });
}
