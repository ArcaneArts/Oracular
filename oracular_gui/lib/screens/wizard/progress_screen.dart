import 'package:arcane/arcane.dart';

import '../../services/project_service.dart';

class ProgressScreen extends StatelessWidget {
  final double progress;
  final List<LogEntry> logs;

  const ProgressScreen({
    super.key,
    required this.progress,
    required this.logs,
  });

  IconData _getLogIcon(LogLevel level) {
    return switch (level) {
      LogLevel.info => Icons.info,
      LogLevel.success => Icons.check_circle,
      LogLevel.warning => Icons.warning,
      LogLevel.error => Icons.x_circle,
      LogLevel.verbose => Icons.dots_three,
    };
  }

  Color _getLogColor(ThemeData theme, LogLevel level) {
    return switch (level) {
      LogLevel.info => theme.colorScheme.foreground,
      LogLevel.success => Colors.green,
      LogLevel.warning => Colors.orange,
      LogLevel.error => theme.colorScheme.destructive,
      LogLevel.verbose => theme.colorScheme.mutedForeground,
    };
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Collection(
      children: [
        Basic(
          leading: CircularProgressIndicator(size: 24),
          title: Text('Creating Project...',
              style: theme.typography.h4.copyWith(color: theme.colorScheme.foreground)),
          subtitle: Text('Please wait while we set everything up',
              style: TextStyle(color: theme.colorScheme.mutedForeground)),
        ),
        const Gap(32),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Progress',
                        style: TextStyle(fontWeight: FontWeight.w600, color: theme.colorScheme.foreground)),
                    Text('${progress.toInt()}%',
                        style: TextStyle(fontWeight: FontWeight.bold, color: theme.colorScheme.primary)),
                  ],
                ),
                const Gap(12),
                SizedBox(
                  width: double.infinity,
                  child: Progress(progress: progress, min: 0, max: 100),
                ),
              ],
            ),
          ),
        ),
        const Gap(24),
        CardSection(
          titleText: 'Build Log',
          leadingIcon: Icons.terminal,
          children: [
            Container(
              height: 280,
              padding: const EdgeInsets.all(16),
              child: ListView.builder(
                itemCount: logs.length,
                itemBuilder: (context, index) {
                  final log = logs[index];
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(_getLogIcon(log.level), size: 14, color: _getLogColor(theme, log.level)),
                        const Gap(8),
                        Expanded(
                          child: Text(
                            log.message,
                            style: TextStyle(
                              fontFamily: 'monospace',
                              fontSize: 12,
                              color: _getLogColor(theme, log.level),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ],
    );
  }
}
