import 'dart:io';

import 'package:idle_cli/idle_cli.dart';

Future<void> main(List<String> args) async {
  final code = await runIdleCli(args);
  exitCode = code;
}
