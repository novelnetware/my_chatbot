// lib/main.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'splash_screen.dart'; // <<< وارد کردن صفحه اسپلش
// import 'chat_ui.dart'; // دیگر نیازی به وارد کردن مستقیم ChatScreen اینجا نیست

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp])
      .then((_) {
    runApp(const MyApp());
  });
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'ShinAp Ai',
      theme: ThemeData.dark().copyWith(
        
        // تم شما بدون تغییر باقی می‌ماند
        scaffoldBackgroundColor: const Color(0xFF181E26),
        appBarTheme: const AppBarTheme(
           backgroundColor: Color(0xFF181E26),
           elevation: 1,
           iconTheme: IconThemeData(color: Colors.white),
           titleTextStyle: TextStyle(color: Colors.white, fontSize: 20),
        ),
        primaryColor: Colors.blueAccent,
        colorScheme: ColorScheme.dark(
           primary: Colors.blueAccent,
           secondary: Colors.blueAccent[100]!,
           background: const Color(0xFF181E26),
           surface: Color.fromARGB(24, 30, 38, 1),
           onPrimary: Colors.white,
           onSecondary: Colors.black,
           onBackground: Colors.white,
           onSurface: Colors.white,
           onError: Colors.white,
           error: Colors.redAccent,
        ),
      ),
      // <<< تغییر صفحه شروع به SplashScreen >>>
      home: const SplashScreen(),
    );
  }
}