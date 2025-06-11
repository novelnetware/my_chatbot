// lib/settings_screen.dart
import 'package:flutter/material.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('تنظیمات', style: TextStyle(fontFamily: 'Vazir')),
      ),
      body: ListView(
        children: const [
          ListTile(
            leading: Icon(Icons.person),
            title: Text('حساب کاربری', style: TextStyle(fontFamily: 'Vazir')),
          ),
          ListTile(
            leading: Icon(Icons.notifications),
            title: Text('اعلان‌ها', style: TextStyle(fontFamily: 'Vazir')),
          ),
          ListTile(
            leading: Icon(Icons.palette),
            title: Text('ظاهر برنامه', style: TextStyle(fontFamily: 'Vazir')),
          ),
        ],
      ),
    );
  }
}