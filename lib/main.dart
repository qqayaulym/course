import 'package:flutter/material.dart';
import 'package:flutter_application_5/screens/home.dart';
import 'package:flutter_application_5/screens/splash.dart';
import 'package:flutter_application_5/services/supabase_service.dart';
import 'main_page.dart';
import 'theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await SupabaseService.init();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final bool isLoggedIn = SupabaseService.client.auth.currentSession != null;

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'duty turn',
      theme: AppTheme.light(),
      home: SplashScreen(
        next: isLoggedIn ? const HomeScreen() : const MainPage(),
      ),
    );
  }
}
