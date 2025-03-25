import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';
import 'screens/chat_screen.dart';
import 'theme.dart';
import 'providers/chat_provider.dart';
import 'providers/session_provider.dart';
import 'services/permission_service.dart';

void main() async {
  // Ensure Flutter is initialized
  WidgetsFlutterBinding.ensureInitialized();

  // Set preferred orientations
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Initialize date formatting for Indonesian locale
  await initializeDateFormatting('id_ID', null);

  // Request permissions on app start
  Map<String, bool> permissions = await PermissionService.requestAllPermissions();

  // Log permission status
  permissions.forEach((key, value) {
    print('Permission $key: ${value ? 'granted' : 'denied'}');
  });

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (context) => ChatProvider()),
        ChangeNotifierProvider(create: (context) => SessionProvider()),
      ],
      child: const PeTanikuApp(),
    ),
  );
}

class PeTanikuApp extends StatelessWidget {
  const PeTanikuApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PeTaniku',
      theme: appTheme,
      debugShowCheckedModeBanner: false,
      home: const ChatScreen(), // Make ChatScreen the main page
    );
  }
}

