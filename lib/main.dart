import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'package:theatre_121/firebase_options.dart';
import 'package:theatre_121/presentation/navigation/app_router.dart';
import 'package:theatre_121/presentation/ui/theme/app_theme.dart';

void main() async {
  usePathUrlStrategy();
  WidgetsFlutterBinding.ensureInitialized();

  // Ignore this known Flutter web hot restart bug, which doesn't play nice
  // with Firestore's event listeners
  FlutterError.onError = (details) {
    final message = details.exception.toString();
    if (message.contains('disposed EngineFlutterView')) {
      return;
    }
    FlutterError.presentError(details);
  };

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  runApp(const ComeOutSinginApp());
}

class ComeOutSinginApp extends StatelessWidget {
  const ComeOutSinginApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Theatre 121',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.system,
      routerConfig: AppRouter.router,
    );
  }
}
