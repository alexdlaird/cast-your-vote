// Copyright (c) 2026 Alex Laird. MIT License.

import 'package:flutter/foundation.dart';
import 'package:logging/logging.dart';
import 'package:cast_your_vote/core/log_formatter.dart';

class LogService {
  static final LogService _instance = LogService._internal();

  factory LogService() => _instance;

  LogService._internal();

  void init() {
    // Use --dart-define=LOG_LEVEL=FINE to set a log level in development
    const logLevelName = String.fromEnvironment(
      'LOG_LEVEL',
      defaultValue: 'INFO',
    );
    Logger.root.level = Level.LEVELS.firstWhere(
      (level) => level.name == logLevelName.toUpperCase(),
      orElse: () => Level.INFO,
    );

    // Only print logs in non-release builds (debug and profile modes)
    // In release builds, logs are handled by Sentry
    if (!kReleaseMode) {
      Logger.root.onRecord.listen((record) {
        // ignore: avoid_print
        print(LogFormatter.format(record));
      });
    }
  }
}
