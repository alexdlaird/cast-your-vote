// Copyright (c) 2026 Alex Laird. MIT License.

import 'package:flutter/foundation.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

class SentryService {
  static final SentryService _instance = SentryService._internal();

  factory SentryService() => _instance;

  SentryService._internal();

  Future<void> init() async {
    await SentryFlutter.init((options) {
      options.dsn =
          'https://c280729f87a67691dafcf705a3fe8bb8@o4511037784915968.ingest.us.sentry.io/4511037795336192';

      const release = String.fromEnvironment('RELEASE_VERSION');
      const dist = String.fromEnvironment('SENTRY_DIST');
      const environment = String.fromEnvironment('SENTRY_ENVIRONMENT');
      if (release.isNotEmpty) {
        options.release = release;
        options.environment = environment.isNotEmpty ? environment : 'prod';
      } else if (environment.isNotEmpty) {
        options.environment = environment;
      }
      if (dist.isNotEmpty) {
        options.dist = dist;
      }

      // Performance monitoring
      options.tracesSampleRate = 0.1;

      // Track user interactions and navigation
      options.enableAutoPerformanceTracing = true;
      options.enableUserInteractionTracing = true;

      options.beforeSend = _beforeSend;
    });

    if (kDebugMode) {
      debugPrint('Sentry initialized successfully');
    }
  }

  SentryEvent? _beforeSend(SentryEvent event, Hint? hint) {
    // Filter Google OAuth/sign-in related errors that are user-initiated cancellations
    if (event.exceptions != null) {
      for (final exception in event.exceptions!) {
        final value = exception.value?.toLowerCase() ?? '';
        if (value.contains('sign-in') ||
            value.contains('signin') ||
            value.contains('cancelled') ||
            value.contains('canceled') ||
            value.contains('popup closed') ||
            value.contains('access denied')) {
          return null;
        }
      }
    }

    return event;
  }
}
