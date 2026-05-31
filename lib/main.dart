import 'package:flutter/material.dart';
import 'theme.dart';
import 'package:provider/provider.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'services/api_service.dart';
import 'services/websocket_service.dart';
import 'services/webrtc_service.dart';
import 'services/group_webrtc_service.dart';
import 'screens/splash_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Load environment variables
  await dotenv.load(fileName: ".env");

  // Initialize services
  final wsService = WebSocketService();

  runApp(
    MultiProvider(
      providers: [
        Provider<ApiService>(create: (_) => ApiService()),
        ChangeNotifierProvider<WebSocketService>.value(value: wsService),
        ChangeNotifierProvider<WebRTCService>(
          create: (_) => WebRTCService(wsService),
        ),
        ChangeNotifierProvider<GroupWebRTCService>(
          create: (_) => GroupWebRTCService(wsService),
        ),
      ],
      child: const SocialApp(),
    ),
  );
}

class SocialApp extends StatelessWidget {
  const SocialApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Social App',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.system,
      home: const SplashScreen(),
    );
  }
}
