// lib/splash_screen.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'login_screen.dart'; // <<< مهم: به LoginScreen هدایت می‌کند

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  bool _isVisible = false;

  @override
  void initState() {
    super.initState();
    Timer(const Duration(milliseconds: 300), () {
      if (mounted) {
        setState(() {
          _isVisible = true;
        });
      }
    });

    Timer(const Duration(seconds: 3), () { // مجموع زمان نمایش
      if (mounted) {
        setState(() {
          _isVisible = false;
        });
        Timer(const Duration(milliseconds: 700), () { // زمان fade-out
           if (mounted) {
             // <<< تغییر ناوبری به LoginScreen >>>
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(builder: (context) => const LoginScreen()), // به صفحه ورود برو
            );
           }
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color.fromRGBO(24, 30, 38, 1), // یا رنگ دلخواه تم شما
      body: Center(
        child: AnimatedOpacity(
          opacity: _isVisible ? 1.0 : 0.0,
          duration: const Duration(milliseconds: 700),
          child: SizedBox(
            width: 150,
            height: 150,
            child: Image.asset(
              'assets/Shinap.png', // مطمئن شوید لوگو در assets هست
              fit: BoxFit.contain,
            ),
          ),
        ),
      ),
    );
  }
}