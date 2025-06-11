// lib/account_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'user_model.dart';
import 'utils/app_notifications.dart';

class AccountScreen extends StatefulWidget {
  const AccountScreen({super.key});

  @override
  State<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends State<AccountScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = true;
  User? _user;

  // Controllers برای فیلدهای فرم
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _birthDayController = TextEditingController();
  final _birthMonthController = TextEditingController();
  final _birthYearController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _birthDayController.dispose();
    _birthMonthController.dispose();
    _birthYearController.dispose();
    super.dispose();
  }

  // --- تابع برای دریافت اطلاعات فعلی کاربر از سرور ---
  Future<void> _loadUserData() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');

    if (token == null) {
      // اگر توکن وجود نداشت، کاربر را به صفحه لاگین هدایت کن
      // (این حالت نباید اتفاق بیفتد اگر کاربر لاگین کرده باشد)
      if(mounted) Navigator.of(context).pop();
      return;
    }

    try {
      // !نکته: این آدرس API فرضی است. باید آن را در افزونه وردپرس خود پیاده‌سازی کنی
      final response = await http.post(
        Uri.parse('https://shinap.ir/wp-json/user-phone/v1/get-user-data'),
        body: {'auth_token': token},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['status'] == 'success') {
          setState(() {
            _user = User.fromJson(data['user_data']);
            // پر کردن فیلدها با اطلاعات کاربر
            _firstNameController.text = _user!.firstName;
            _lastNameController.text = _user!.lastName;

            final parts = _user!.birthDate.split('/');
            if (parts.length == 3) {
              _birthYearController.text = parts[0];
              _birthMonthController.text = parts[1];
              _birthDayController.text = parts[2];
            }
            _isLoading = false;
          });
        }
      } else {
        // مدیریت خطا
        if(mounted) {
            AppNotifications.showSnackBar(context, 'خطا در دریافت اطلاعات کاربر');
            setState(() => _isLoading = false);
        }
      }
    } catch (e) {
      if(mounted) {
        AppNotifications.showSnackBar(context, 'خطای ارتباط با سرور');
        setState(() => _isLoading = false);
      }
    }
  }

  // --- تابع برای بروزرسانی اطلاعات کاربر ---
  Future<void> _updateUserData() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');
    final birthDate =
        "${_birthYearController.text}/${_birthMonthController.text}/${_birthDayController.text}";

    try {
      // !نکته: این آدرس API نیز فرضی است.
      final response = await http.post(
        Uri.parse('https://shinap.ir/wp-json/user-phone/v1/update-user-data'),
        body: {
          'auth_token': token,
          'first_name': _firstNameController.text,
          'last_name': _lastNameController.text,
          'birth_date': birthDate,
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['status'] == 'success') {
          AppNotifications.showSnackBar(context, 'اطلاعات با موفقیت بروزرسانی شد', type: NotificationType.success);
          Navigator.of(context).pop();
        } else {
          AppNotifications.showSnackBar(context, data['message'] ?? 'خطا در بروزرسانی');
        }
      }
    } catch (e) {
      AppNotifications.showSnackBar(context, 'خطای ارتباط با سرور');
    }

    if(mounted) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('حساب کاربری', style: TextStyle(fontFamily: 'Vazir')),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Icon(Icons.account_circle, size: 80, color: Colors.blueAccent),
                    const SizedBox(height: 30),

                    _buildTextField(_firstNameController, 'نام', Icons.person),
                    const SizedBox(height: 20),
                    _buildTextField(_lastNameController, 'نام خانوادگی', Icons.person_outline),
                    const SizedBox(height: 20),

                    // --- فیلدهای تاریخ تولد ---
                    const Text(
                      'تاریخ تولد',
                      textAlign: TextAlign.right,
                      style: TextStyle(fontFamily: 'Vazir', color: Colors.white70, fontSize: 16),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(child: _buildBirthDateField(_birthYearController, 'سال', 4, 1300, 1400)),
                        const SizedBox(width: 10),
                        Expanded(child: _buildBirthDateField(_birthMonthController, 'ماه', 2, 1, 12)),
                        const SizedBox(width: 10),
                        Expanded(child: _buildBirthDateField(_birthDayController, 'روز', 2, 1, 31)),
                      ],
                    ),
                    // -------------------------

                    const SizedBox(height: 40),
                    ElevatedButton(
                      onPressed: _updateUserData,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blueAccent,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.0)),
                      ),
                      child: const Text('ذخیره تغییرات', style: TextStyle(fontSize: 17, fontFamily: 'Vazir')),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  // ویجت‌های کمکی برای خوانایی بهتر
  Widget _buildTextField(TextEditingController controller, String label, IconData icon) {
    return TextFormField(
      controller: controller,
      style: const TextStyle(fontFamily: 'Vazir', color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(fontFamily: 'Vazir', color: Colors.grey),
        prefixIcon: Icon(icon, color: Colors.grey),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8.0)),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8.0),
          borderSide: const BorderSide(color: Colors.blueAccent),
        ),
      ),
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'این فیلد نمی‌تواند خالی باشد';
        }
        return null;
      },
    );
  }

  Widget _buildBirthDateField(TextEditingController controller, String hint, int length, int min, int max) {
    return TextFormField(
      controller: controller,
      textAlign: TextAlign.center,
      keyboardType: TextInputType.number,
      style: const TextStyle(fontSize: 16, fontFamily: 'VazirD'),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(fontSize: 14, color: Colors.grey.shade500, fontFamily: 'Vazir'),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8.0)),
        contentPadding: const EdgeInsets.symmetric(vertical: 12),
      ),
      inputFormatters: [
        FilteringTextInputFormatter.digitsOnly,
        LengthLimitingTextInputFormatter(length),
      ],
      validator: (value) {
        if (value == null || value.isEmpty) return 'ضروری';
        final num = int.tryParse(value);
        if (num == null) return 'عدد';
        if (num < min || num > max) return 'نامعتبر';
        return null;
      },
    );
  }
}