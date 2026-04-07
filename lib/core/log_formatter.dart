// Copyright (c) 2026 Alex Laird. MIT License.

import 'package:logging/logging.dart';

class LogColors {
  static const String severe = '\x1B[91m'; // Light red
  static const String warning = '\x1B[33m'; // Yellow
  static const String info = '\x1B[36m'; // Cyan
  static const String debug = '\x1B[90m'; // Grey
  static const String reset = '\x1B[0m';

  static String forLevel(Level level) {
    if (level >= Level.SEVERE) {
      return severe;
    } else if (level >= Level.WARNING) {
      return warning;
    } else if (level >= Level.INFO) {
      return info;
    } else {
      return debug;
    }
  }
}

class LogFormatter {
  static String format(LogRecord record) {
    final colorCode = LogColors.forLevel(record.level);
    const resetCode = LogColors.reset;

    final buffer = StringBuffer();
    buffer.write(
      '$colorCode${record.level.name}$resetCode: ${record.time}: [${record.loggerName}] ${record.message}',
    );

    if (record.error != null) {
      buffer.write('\n${colorCode}Error$resetCode: ${record.error}');
    }
    if (record.stackTrace != null) {
      buffer.write('\n${colorCode}Stack Trace:$resetCode\n${record.stackTrace}');
    }

    return buffer.toString();
  }
}
