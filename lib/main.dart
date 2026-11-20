import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'backup.dart';
import 'db.dart';
import 'l10n.dart';
import 'notifier.dart';
import 'screens/home_screen.dart';
import 'settings.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Draw the app behind the status bar, camera cut-out and gesture bar so the
  // whole screen looks like part of the app (needed on Android 11-14).
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    systemNavigationBarColor: Colors.transparent,
    systemNavigationBarDividerColor: Colors.transparent,
    systemNavigationBarContrastEnforced: false,
    systemNavigationBarIconBrightness: Brightness.dark,
  ));

  await AppDb.instance.init();
  await Settings.instance.load();
  await L10n.instance.load();
  await Notifier.instance.init();

  // Re-plan reminders whenever data, reminder settings or the language change.
  Future<void> replan() => Notifier.instance.reschedule();
  AppDb.instance.revision.addListener(replan);
  Settings.instance.addListener(replan);
  L10n.instance.addListener(replan);
  replan();

  // Back up automatically when signed in and online.
  SyncService.instance.start();

  runApp(const TailorBookApp());
}

class TailorBookApp extends StatelessWidget {
  const TailorBookApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: L10n.instance,
      builder: (context, _) => MaterialApp(
        // The key rebuilds every screen with the new language when it changes.
        key: ValueKey(L10n.instance.lang),
        title: 'Tailor Book',
        debugShowCheckedModeBanner: false,
        locale: L10n.instance.materialLocale,
        supportedLocales: const [Locale('en'), Locale('fr')],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        theme: ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF7A3E2B)),
          inputDecorationTheme: const InputDecorationTheme(
            border: OutlineInputBorder(),
            isDense: true,
          ),
        ),
        home: const HomeScreen(),
      ),
    );
  }
}
