import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'app/app_route_factory.dart';
import 'app/app_routes.dart';
import 'features/auth/presentation/auth_gate.dart';
import 'core/notifications/vm_push_notification_service.dart';
import 'firebase_options.dart';

final GlobalKey<NavigatorState> rootNavigatorKey = GlobalKey<NavigatorState>();
final GlobalKey<ScaffoldMessengerState> rootScaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await VmPushNotificationService.instance.initialize();
  runApp(const VibeMatchApp());
}

class VibeMatchApp extends StatelessWidget {
  const VibeMatchApp({super.key});

  static const Color _aqua = Color(0xFF12C7B7);
  static const Color _deepPlum = Color(0xFF251538);
  static const Color _surface = Color(0xFFFAF7F1);
  static const Color _bodyText = Color(0xFF18131F);

  ThemeData _theme() {
    final base = ThemeData(
      useMaterial3: true,
      fontFamily: 'Roboto',
      visualDensity: VisualDensity.compact,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      colorScheme: ColorScheme.fromSeed(seedColor: _aqua, brightness: Brightness.light),
      scaffoldBackgroundColor: _surface,
    );

    const compactText = TextTheme(
      displayLarge: TextStyle(color: _deepPlum, fontSize: 24, height: 1.05, fontWeight: FontWeight.w700, letterSpacing: -0.6),
      displayMedium: TextStyle(color: _deepPlum, fontSize: 22, height: 1.05, fontWeight: FontWeight.w700, letterSpacing: -0.5),
      displaySmall: TextStyle(color: _deepPlum, fontSize: 20, height: 1.05, fontWeight: FontWeight.w700, letterSpacing: -0.35),
      headlineLarge: TextStyle(color: _deepPlum, fontSize: 19, height: 1.08, fontWeight: FontWeight.w700, letterSpacing: -0.3),
      headlineMedium: TextStyle(color: _deepPlum, fontSize: 18, height: 1.08, fontWeight: FontWeight.w700, letterSpacing: -0.25),
      headlineSmall: TextStyle(color: _deepPlum, fontSize: 17, height: 1.08, fontWeight: FontWeight.w700, letterSpacing: -0.2),
      titleLarge: TextStyle(color: _deepPlum, fontSize: 16, height: 1.08, fontWeight: FontWeight.w700, letterSpacing: -0.1),
      titleMedium: TextStyle(color: _bodyText, fontSize: 14, height: 1.10, fontWeight: FontWeight.w600),
      titleSmall: TextStyle(color: _bodyText, fontSize: 12, height: 1.10, fontWeight: FontWeight.w600),
      bodyLarge: TextStyle(color: _bodyText, fontSize: 13, height: 1.16, fontWeight: FontWeight.w400),
      bodyMedium: TextStyle(color: _bodyText, fontSize: 12, height: 1.15, fontWeight: FontWeight.w400),
      bodySmall: TextStyle(color: _bodyText, fontSize: 10.5, height: 1.12, fontWeight: FontWeight.w400),
      labelLarge: TextStyle(color: _bodyText, fontSize: 12, height: 1.05, fontWeight: FontWeight.w600),
      labelMedium: TextStyle(color: _bodyText, fontSize: 10.5, height: 1.05, fontWeight: FontWeight.w600),
      labelSmall: TextStyle(color: _bodyText, fontSize: 9, height: 1.0, fontWeight: FontWeight.w600),
    );

    return base.copyWith(
      textTheme: compactText,
      primaryTextTheme: compactText,
      iconTheme: const IconThemeData(size: 17),
      appBarTheme: const AppBarTheme(
        centerTitle: false,
        elevation: 0,
        scrolledUnderElevation: 0,
        titleTextStyle: TextStyle(color: _deepPlum, fontSize: 17, height: 1.05, fontWeight: FontWeight.w700, letterSpacing: -0.25),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        contentTextStyle: compactText.bodySmall?.copyWith(color: Colors.white, fontWeight: FontWeight.w600),
      ),
      chipTheme: base.chipTheme.copyWith(labelStyle: compactText.labelMedium, padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), side: BorderSide.none),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(iconSize: 17, minimumSize: const Size(30, 30), tapTargetSize: MaterialTapTargetSize.shrinkWrap, padding: const EdgeInsets.all(5)),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(minimumSize: const Size(44, 34), padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8), tapTargetSize: MaterialTapTargetSize.shrinkWrap),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(minimumSize: const Size(38, 30), padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6), tapTargetSize: MaterialTapTargetSize.shrinkWrap),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'FunKey',
      debugShowCheckedModeBanner: false,
      navigatorKey: rootNavigatorKey,
      scaffoldMessengerKey: rootScaffoldMessengerKey,
      initialRoute: VmRoutes.auth,
      onGenerateRoute: AppRouteFactory.onGenerateRoute,
      theme: _theme(),
      builder: (context, child) {
        final media = MediaQuery.of(context);
        return MediaQuery(
          data: media.copyWith(textScaler: media.textScaler.clamp(minScaleFactor: 0.82, maxScaleFactor: 0.92)),
          child: child ?? const AuthGate(),
        );
      },
    );
  }
}