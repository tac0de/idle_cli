import 'dart:io';

import 'package:idle_cli/idle_cli.dart';

/// Minimal example that forwards args to [runIdleCli].
///
/// Run:
/// - `dart run example/main.dart help`
/// - `dart run example/main.dart create`
Future<void> main(List<String> args) async {
  final exit = await runIdleCli(args.isEmpty ? const ['help'] : args);
  exitCode = exit;
}
