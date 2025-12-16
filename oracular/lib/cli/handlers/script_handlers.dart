import 'dart:io';

import '../../services/script_runner.dart';

final _runner = ScriptRunner();

/// List available scripts
Future<void> handleScriptsList() async {
  _runner.listScripts();
}

/// Execute a script
Future<void> handleScriptsExec(Map<String, dynamic> args, Map<String, dynamic> flags) async {
  final script = args['script'] as String?;
  if (script == null) {
    _runner.listScripts();
    return;
  }

  final stream = flags['stream'] == true;
  final exitCode = stream
      ? await _runner.runStreaming(script)
      : await _runner.run(script);

  if (exitCode != 0) {
    exit(exitCode);
  }
}
