import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'app/app_route_factory.dart';
import 'app/app_routes.dart';
import 'features/auth/presentation/auth_gate.dart';
import 'core/notifications/vm_push_notification_service.dart';
import 'firebase_options.dart';

final GlobalKey<NavigatorState> rootNavigatorKey = GlobalKey<NavigatorState>();
final GlobalKey<ScaffoldMessengerState> rootScaffoldMessengerKey =
    GlobalKey<ScaffoldMessengerState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await VmPushNotificationService.instance.initialize();
  runApp(const VibeMatchApp());
}

class VibeMatchApp extends StatelessWidget {
  const VibeMatchApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'FunKey',
      debugShowCheckedModeBanner: false,
      navigatorKey: rootNavigatorKey,
      scaffoldMessengerKey: rootScaffoldMessengerKey,
      initialRoute: VmRoutes.auth,
      onGenerateRoute: AppRouteFactory.onGenerateRoute,
      theme: ThemeData(
        useMaterial3: true,
        fontFamily: 'Roboto',
        visualDensity: VisualDensity.compact,
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF12C7B7),
          brightness: Brightness.light,
        ),
        scaffoldBackgroundColor: const Color(0xFFFAF7F1),
        iconTheme: const IconThemeData(size: 18),
        iconButtonTheme: IconButtonThemeData(
          style: IconButton.styleFrom(
            iconSize: 18,
            minimumSize: const Size(34, 34),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            padding: const EdgeInsets.all(6),
          ),
        ),
      ),
      builder: (context, child) {
        final media = MediaQuery.of(context);
        return MediaQuery(
          data: media.copyWith(
            textScaler: media.textScaler.clamp(
              minScaleFactor: 0.85,
              maxScaleFactor: 1.0,
            ),
          ),
          child: child ?? const AuthGate(),
        );
      },
    );
  }
}
