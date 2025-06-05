import 'package:logger/logger.dart';

/// Custom logger service with meme-themed output
class LoggerService {
  static Logger createLogger() {
    return Logger(
      printer: MemePrinter(),
      level: Level.debug,
      filter: ProductionFilter(),
    );
  }
}

/// Custom printer with meme-themed log output
class MemePrinter extends LogPrinter {
  static final levelEmojis = {
    Level.trace: '🔍',
    Level.debug: '🐛',
    Level.info: '💎',
    Level.warning: '⚠️',
    Level.error: '💀',
    Level.fatal: '☠️',
  };

  static final levelPrefixes = {
    Level.trace: 'TRACE',
    Level.debug: 'DEBUG',
    Level.info: 'BASED',
    Level.warning: 'SUS',
    Level.error: 'REKT',
    Level.fatal: 'GG',
  };

  @override
  List<String> log(LogEvent event) {
    final emoji = levelEmojis[event.level] ?? '🤔';
    final prefix = levelPrefixes[event.level] ?? 'UNKNOWN';
    final time = DateTime.now().toIso8601String().split('T')[1].split('.')[0];

    final buffer = StringBuffer();
    buffer.write('$emoji [$time] $prefix: ${event.message}');

    if (event.error != null) {
      buffer.write('\n💥 Error: ${event.error}');
    }

    if (event.stackTrace != null) {
      buffer.write('\n📚 Stack trace:\n${event.stackTrace}');
    }

    return buffer.toString().split('\n');
  }
}
