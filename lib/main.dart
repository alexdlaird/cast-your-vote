import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'package:logging/logging.dart';
import 'package:cast_your_vote/core/log_service.dart';
import 'package:cast_your_vote/core/sentry_service.dart';
import 'package:cast_your_vote/firebase_options.dart';
import 'package:cast_your_vote/presentation/navigation/app_router.dart';
import 'package:cast_your_vote/presentation/ui/theme/app_theme.dart';

final _log = Logger('main');

void main() async {
  usePathUrlStrategy();
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize logging first
  LogService().init();

  // Ignore this known Flutter web hot restart bug, which doesn't play nice
  // with Firestore's event listeners
  FlutterError.onError = (details) {
    final message = details.exception.toString();
    if (message.contains('disposed EngineFlutterView')) {
      return;
    }
    FlutterError.presentError(details);
  };

  // Initialize Sentry for error reporting in release mode
  if (!kDebugMode) {
    try {
      await SentryService().init();
    } catch (e) {
      _log.severe('Sentry initialization failed', e);
    }
  }

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Use Firestore emulator in debug mode (Auth uses real Firebase for OAuth)
  if (kDebugMode) {
    FirebaseFirestore.instance.useFirestoreEmulator('localhost', 8080);
  }

  runApp(const ComeOutSinginApp());
}

class ComeOutSinginApp extends StatelessWidget {
  const ComeOutSinginApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Cast Your Vote!',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.system,
      routerConfig: AppRouter.router,
    );
  }
}
