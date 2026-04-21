import 'dart:developer' as dev;

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:logging/logging.dart';
import 'package:provider/provider.dart';

import 'app_lifecycle/app_lifecycle.dart';
import 'audio/audio_controller.dart';
import 'firebase_options.dart';
import 'l10n/app_localizations.dart';
import 'l10n/localization_service.dart';
import 'login/user_session.dart';
import 'router.dart';
import 'settings/settings.dart';
import 'style/palette.dart';

void main() async {
  // Basic logging setup.
  Logger.root.level = kDebugMode ? Level.FINE : Level.INFO;
  Logger.root.onRecord.listen((record) {
    dev.log(
      record.message,
      time: record.time,
      level: record.level.value,
      name: record.loggerName,
    );
  });
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (e) {
    dev.log('Firebase initialization failed: $e', level: Level.WARNING.value);
  }

  // Put game into full screen mode on mobile devices.
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  // Lock the game to portrait mode on mobile devices.
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return AppLifecycleObserver(
      child: MultiProvider(
        // This is where you add objects that you want to have available
        // throughout your game.
        //
        // Every widget in the game can access these objects by calling
        // `context.watch()` or `context.read()`.
        // See `lib/main_menu/main_menu_screen.dart` for example usage.
        providers: [
          Provider(create: (context) => SettingsController()),
          Provider(create: (context) => Palette()),
          ChangeNotifierProvider(create: (context) => LocalizationService()),
          ChangeNotifierProvider(create: (context) => UserSession()),
          // Set up audio.
          ProxyProvider2<AppLifecycleStateNotifier, SettingsController, AudioController>(
            create: (context) => AudioController(),
            update: (context, lifecycleNotifier, settings, audio) {
              audio!.attachDependencies(lifecycleNotifier, settings);
              return audio;
            },
            dispose: (context, audio) => audio.dispose(),
            // Ensures that music starts immediately.
            lazy: false,
          ),
          // Set up lifecycle management for UserSession
          ChangeNotifierProxyProvider<AppLifecycleStateNotifier, UserSession>(
            create: (context) => UserSession(),
            update: (context, lifecycleNotifier, userSession) {
              // Listen to app lifecycle changes
              lifecycleNotifier.addListener(() {
                userSession!.handleAppLifecycleChange(lifecycleNotifier.value);
              });
              return userSession!;
            },
          ),
        ],
        child: Builder(builder: (context) {
          final palette = context.watch<Palette>();
          final localizationService = context.watch<LocalizationService>();

          return MaterialApp.router(
            title: 'Cardinyoli',
            locale: localizationService.currentLocale,
            localizationsDelegates: const [
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            supportedLocales: const [
              Locale('ca'),
              Locale('en'),
            ],
            theme: ThemeData.from(
              colorScheme: ColorScheme.fromSeed(
                seedColor: palette.darkPen,
                surface: palette.backgroundMain,
              ),
              textTheme: TextTheme(
                bodyMedium: TextStyle(color: palette.ink),
              ),
              useMaterial3: true,
            ).copyWith(
              // Make buttons more fun.
              filledButtonTheme: FilledButtonThemeData(
                style: FilledButton.styleFrom(
                  textStyle: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 20,
                  ),
                ),
              ),
            ),
            routerConfig: router,
          );
        }),
      ),
    );
  }
}
