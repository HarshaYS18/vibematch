import 'package:flutter/material.dart';

import 'app/app_route_factory.dart';
import 'app/app_routes.dart';
import 'features/auth/presentation/auth_gate.dart';

final GlobalKey<NavigatorState> rootNavigatorKey = GlobalKey<NavigatorState>();
final GlobalKey<ScaffoldMessengerState> rootScaffoldMessengerKey =
    GlobalKey<ScaffoldMessengerState>();

void main() {
  runApp(const VibeMatchApp());
}

class VibeMatchApp extends StatelessWidget {
  const VibeMatchApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Vibe Match',
      debugShowCheckedModeBanner: false,
      navigatorKey: rootNavigatorKey,
      scaffoldMessengerKey: rootScaffoldMessengerKey,
      initialRoute: VmRoutes.auth,
      onGenerateRoute: AppRouteFactory.onGenerateRoute,
      theme: ThemeData(
        useMaterial3: true,
        fontFamily: 'Roboto',
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF12C7B7),
          brightness: Brightness.light,
        ),
        scaffoldBackgroundColor: const Color(0xFFFAF7F1),
      ),
      builder: (context, child) {
        return child ?? const AuthGate();
      },
    );
  }
}
