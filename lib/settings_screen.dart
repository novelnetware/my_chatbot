// lib/settings_screen.dart
import 'package:flutter/material.dart';
import 'account_screen.dart'; // <<< فایل جدید را وارد کن

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('تنظیمات', style: TextStyle(fontFamily: 'Vazir')),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: ListView(
        children: [
          ListTile(
            leading: const Icon(Icons.person),
            title: const Text('حساب کاربری', style: TextStyle(fontFamily: 'Vazir')),
            // --- تغییر در اینجا ---
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (context) => const AccountScreen()),
              );
            },
            // ---------------------
          ),
          const ListTile(
            leading: Icon(Icons.notifications),
            title: Text('اعلان‌ها', style: TextStyle(fontFamily: 'Vazir')),
          ),
          const ListTile(
            leading: Icon(Icons.palette),
            title: Text('ظاهر برنامه', style: TextStyle(fontFamily: 'Vazir')),
          ),
        ],
      ),
    );
  }
}