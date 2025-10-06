import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:tasktracker/pages/splash_screen.dart';
import 'package:provider/provider.dart';
import 'package:tasktracker/state/theme_notifier.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  await Supabase.initialize(
    url: 'https://tqjxlbquonanziuiambr.supabase.co',
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRxanhsYnF1b25hbnppdWlhbWJyIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTY3MTcyMzgsImV4cCI6MjA3MjI5MzIzOH0.45-sgVsP8MBFYngSu66I4BYGrp1Ay4JNjrD4gTDfSq8',
  );
  
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => AppSettings(),
      child: Consumer<AppSettings>(
        builder: (context, settings, _) {
          final baseLight = ThemeData(
            colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepOrange),
            useMaterial3: true,
          );
          final baseDark = ThemeData(
            colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepOrange, brightness: Brightness.dark),
            useMaterial3: true,
          );
          return MaterialApp(
            title: 'Task Tracker',
            theme: baseLight.copyWith(
              snackBarTheme: const SnackBarThemeData(behavior: SnackBarBehavior.floating),
            ),
            darkTheme: baseDark.copyWith(
              snackBarTheme: const SnackBarThemeData(behavior: SnackBarBehavior.floating),
            ),
            themeMode: settings.themeMode,
            debugShowCheckedModeBanner: false,
            home: const SplashScreen(),
          );
        },
      ),
    );
  }
}
