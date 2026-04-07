import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'theme/app_theme.dart';
import 'providers/auth_provider.dart';
import 'providers/connection_provider.dart';
import 'screens/splash_screen.dart';
import 'screens/login_screen.dart';
import 'screens/signup_screen.dart';
import 'screens/home_screen.dart';
import 'screens/connect_screen.dart';
import 'screens/video_call_screen.dart';
import 'screens/file_transfer_screen.dart';
import 'screens/messages_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => ConnectionProvider()),
      ],
      child: const RemoteApp(),
    ),
  );
}

class RemoteApp extends StatelessWidget {
  const RemoteApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'RemoteApp',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,
      initialRoute: '/',
      routes: {
        '/': (_) => const SplashScreen(),
        '/login': (_) => const LoginScreen(),
        '/signup': (_) => const SignupScreen(),
        '/home': (_) => const HomeScreen(),
        '/connect': (_) => const ConnectScreen(),
        '/call': (_) => const VideoCallScreen(),
        '/files': (_) => const FileTransferScreen(),
        '/messages': (_) => const MessagesScreen(),
      },
    );
  }
}
