import 'package:fast_log/fast_log.dart';

/// Say hello with optional customization
Future<void> handleGreet(Map<String, dynamic> args, Map<String, dynamic> flags) async {
  final name = args['name'] as String? ?? 'World';
  final times = flags['times'] == true ? 3 : 1;
  final enthusiastic = flags['enthusiastic'] == true;

  info("Executing greet command for: $name");

  final punctuation = enthusiastic ? '!' : '.';
  final greeting = 'Hello, $name$punctuation';

  for (int i = 0; i < times; i++) {
    print(greeting);
  }

  success("Greeted $name $times time${times == 1 ? '' : 's'}");
}

/// Display version information
void handleVersion() {
  print('arcane_cli_app CLI v1.0.0');
  print('Built with Arcane Templates');
}
