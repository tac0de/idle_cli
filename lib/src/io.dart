import 'dart:convert';
import 'dart:io';

import 'package:idle_save/idle_save.dart';

/// Abstraction over stdin/stdout/stderr for the JSON-only CLI.
///
/// This keeps command implementations deterministic and testable by allowing
/// stdin/stdout/stderr to be injected.
class CliIo {
  final Stream<List<int>> _stdin;
  final bool _stdinHasTerminal;
  final void Function(String) _writeStdoutLine;
  final void Function(String) _writeStderrLine;

  CliIo._({
    required Stream<List<int>> stdin,
    required bool stdinHasTerminal,
    required void Function(String) writeStdoutLine,
    required void Function(String) writeStderrLine,
  }) : _stdin = stdin,
       _stdinHasTerminal = stdinHasTerminal,
       _writeStdoutLine = writeStdoutLine,
       _writeStderrLine = writeStderrLine;

  /// Uses the process' `stdin`, `stdout`, and `stderr`.
  factory CliIo.system() {
    return CliIo._(
      stdin: stdin,
      stdinHasTerminal: stdin.hasTerminal,
      writeStdoutLine: stdout.writeln,
      writeStderrLine: stderr.writeln,
    );
  }

  /// Creates a [CliIo] instance with injectable streams/sinks (useful for tests).
  factory CliIo.forTesting({
    required Stream<List<int>> stdin,
    required bool stdinHasTerminal,
    required void Function(String) writeStdoutLine,
    required void Function(String) writeStderrLine,
  }) {
    return CliIo._(
      stdin: stdin,
      stdinHasTerminal: stdinHasTerminal,
      writeStdoutLine: writeStdoutLine,
      writeStderrLine: writeStderrLine,
    );
  }

  /// Whether stdin is connected to a terminal (i.e. not piped).
  bool get stdinHasTerminal => _stdinHasTerminal;

  /// Reads all of stdin as a string, or throws if stdin is a terminal.
  Future<String> readStdinOrFail() async {
    if (_stdinHasTerminal) {
      throw const FormatException(
        'No stdin input. Provide a snapshot via pipe or --in. '
        'Example: idle create | idle tick --count 10 > s.json '
        'or: idle tick --count 10 --in s.json > s2.json',
      );
    }
    return utf8.decode(await _stdin.expand((chunk) => chunk).toList());
  }

  /// Writes [json] using canonical JSON encoding.
  ///
  /// By default output is written to stdout; set [toStderr] to write to stderr.
  void writeJson(Map<String, dynamic> json, {bool toStderr = false}) {
    final raw = const CanonicalJsonSaveCodec().encode(json);
    (toStderr ? _writeStderrLine : _writeStdoutLine)(raw);
  }
}
