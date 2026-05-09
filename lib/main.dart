import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'screens/home_screen.dart';
import 'theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarBrightness: Brightness.dark,
    statusBarIconBrightness: Brightness.light,
    systemNavigationBarColor: Colors.transparent,
    systemNavigationBarDividerColor: Colors.transparent,
    systemNavigationBarContrastEnforced: false,
    systemNavigationBarIconBrightness: Brightness.light,
  ));

  runApp(const AgeVerifyApp());
}

class AgeVerifyApp extends StatefulWidget {
  const AgeVerifyApp({super.key});

  static final themeNotifier = ValueNotifier<ThemeMode>(ThemeMode.system);

  @override
  State<AgeVerifyApp> createState() => _AgeVerifyAppState();
}

class _AgeVerifyAppState extends State<AgeVerifyApp> {
  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: AgeVerifyApp.themeNotifier,
      builder: (_, themeMode, __) {
        return MaterialApp(
          title: 'Verify Age',
          debugShowCheckedModeBanner: false,
          themeMode: themeMode,
          // Smooth theme animation matching prototype (.3s)
          themeAnimationDuration: const Duration(milliseconds: 300),
          themeAnimationCurve: Curves.easeInOut,
          theme: ThemeData(
            brightness: Brightness.light,
            scaffoldBackgroundColor: AppColors.lightBg,
            useMaterial3: true,
          ),
          darkTheme: ThemeData(
            brightness: Brightness.dark,
            scaffoldBackgroundColor: AppColors.darkBg,
            useMaterial3: true,
          ),
          home: const HomeScreen(),
        );
      },
    );
  }
}
