// lib/about_screen.dart
import 'package:flutter/material.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('درباره ما', style: TextStyle(fontFamily: 'Vazir')),
        leading: IconButton( // دکمه بازگشت
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Image.asset('assets/Shinap.png', height: 150),
              const SizedBox(height: 20),
              const Text(
                'شین اَپ',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, fontFamily: 'Vazir'),
              ),
              const SizedBox(height: 10),
              const Text(
                'اولین هوش مصنوعی کاملا ایرانی. این اپلیکیشن با هدف ارائه یک دستیار هوشمند و کارآمد برای کاربران فارسی‌زبان طراحی شده است.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, fontFamily: 'Vazir'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}