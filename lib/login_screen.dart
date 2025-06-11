// lib/login_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'chat_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _codeController = TextEditingController();
  final TextEditingController _firstNameController = TextEditingController();
  final TextEditingController _lastNameController = TextEditingController();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  
  String? _authToken;
  bool _isLoading = false;
  bool _showCodeField = false;
  bool _showRegisterFields = false;
  String? _verificationPhone;

  @override
  void initState() {
    super.initState();
    _checkSavedAuth();
  }

  Future<void> _checkSavedAuth() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');
    
    if (token != null) {
      setState(() {
        _isLoading = true;
      });
      
      final isValid = await _validateAuthToken(token);
      
      if (isValid) {
        _navigateToChat();
      } else {
        await prefs.remove('auth_token');
      }
    }
    
    setState(() {
      _isLoading = false;
    });
  }

  Future<bool> _validateAuthToken(String token) async {
    try {
      final response = await http.post(
        Uri.parse('https://shinap.ir/wp-json/user-phone/v1/validate-token'),
        body: {'auth_token': token},
      );
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['status'] == 'success';
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  Future<void> _submitPhone() async {
    if (!_formKey.currentState!.validate()) return;
    
    setState(() {
      _isLoading = true;
    });
    
    final phoneNumber = _phoneController.text;
    
    try {
      final response = await http.post(
        Uri.parse('https://shinap.ir/wp-json/user-phone/v1/check-user'),
        body: {'phone': phoneNumber},
      );
      
      final data = jsonDecode(response.body);
      
      if (response.statusCode == 200) {
        if (data['status'] == 'codex') {
          // کاربر وجود دارد - درخواست کد تأیید
          setState(() {
            _showCodeField = true;
            _verificationPhone = phoneNumber;
          });
        } else if (data['status'] == 'reg') {
          // کاربر جدید - کد ارسال شده
          setState(() {
            _showCodeField = true;
            _verificationPhone = phoneNumber;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('کد تأیید به شماره شما ارسال شد')),
          );
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(data['message'] ?? 'خطا در ارتباط با سرور')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('خطا در ارتباط با سرور')),
      );
    }
    
    setState(() {
      _isLoading = false;
    });
  }

  Future<void> _verifyCode() async {
    if (!_formKey.currentState!.validate()) return;
    
    setState(() {
      _isLoading = true;
    });
    
    try {
      final response = await http.post(
        Uri.parse('https://shinap.ir/wp-json/user-phone/v1/verify-code'),
        body: {
          'phone': _verificationPhone,
          'code': _codeController.text,
        },
      );
      
      final data = jsonDecode(response.body);
      
      if (response.statusCode == 200 && data['status'] == 'success') {
        _authToken = data['auth_token'];
        
        if (data['user_exists'] == true) {
          // ذخیره توکن و ورود به سیستم
          await _saveAuthTokenAndLogin(_authToken!);
        } else {
          // نمایش فرم ثبت نام
          setState(() {
            _showRegisterFields = true;
          });
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(data['message'] ?? 'کد تأیید نامعتبر است')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('خطا در ارتباط با سرور')),
      );
    }
    
    setState(() {
      _isLoading = false;
    });
  }

  Future<void> _registerUser() async {
    if (!_formKey.currentState!.validate()) return;
    
    setState(() {
      _isLoading = true;
    });
    
    try {
      final response = await http.post(
        Uri.parse('https://shinap.ir/wp-json/user-phone/v1/register'),
        body: {
          'phone': _verificationPhone,
          'first_name': _firstNameController.text,
          'last_name': _lastNameController.text,
          'auth_token': _authToken,
        },
      );
      
      final data = jsonDecode(response.body);
      
      if (response.statusCode == 200 && data['status'] == 'success') {
        // ذخیره توکن و ورود به سیستم
        await _saveAuthTokenAndLogin(_authToken!);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(data['message'] ?? 'خطا در ثبت نام')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('خطا در ارتباط با سرور')),
      );
    }
    
    setState(() {
      _isLoading = false;
    });
  }

  Future<void> _saveAuthTokenAndLogin(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('auth_token', token);
    _navigateToChat();
  }

  void _navigateToChat() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (context) => const ChatScreen()),
    );
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _codeController.dispose();
    _firstNameController.dispose();
    _lastNameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: _isLoading
              ? const CircularProgressIndicator()
              : SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 30.0, vertical: 20.0),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: <Widget>[
                        Image.asset(
                          'assets/Shinap.png',
                          height: 180,
                        ),
                        const SizedBox(height: 40),
                        
                        if (!_showCodeField && !_showRegisterFields) ...[
                          // صفحه اول - دریافت شماره تلفن
                          TextFormField(
                            controller: _phoneController,
                            keyboardType: TextInputType.phone,
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontSize: 16, letterSpacing: 2, fontFamily: 'VazirD'),
                            decoration: InputDecoration(
                              hintText: '09120000000',
                              hintStyle: TextStyle(
                                fontSize: 16,
                                color: Colors.grey.shade500,
                                fontFamily: 'VazirD',
                              ),
                              prefixIcon: Icon(
                                Icons.phone_android,
                                color: Colors.grey.shade500,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12.0),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12.0),
                                borderSide: BorderSide(color: Colors.grey.shade700),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12.0),
                                borderSide: BorderSide(color: theme.colorScheme.primary, width: 1.5),
                              ),
                              filled: true,
                              fillColor: Colors.black.withOpacity(0.1),
                              contentPadding: const EdgeInsets.symmetric(vertical: 15),
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'لطفاً شماره موبایل را وارد کنید';
                              }
                              if (value.length != 11) {
                                return 'شماره موبایل باید 11 رقم باشد';
                              }
                              return null;
                            },
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                              LengthLimitingTextInputFormatter(11),
                            ],
                          ),
                          const SizedBox(height: 30),
                          ElevatedButton(
                            onPressed: _submitPhone,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color.fromARGB(255, 41, 98, 255),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(5.0),
                              ),
                              elevation: 5,
                            ),
                            child: const Text(
                              'ورود / عضویت',
                              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w500, fontFamily: 'Vazir'),
                            ),
                          ),
                        ],
                        
                        if (_showCodeField && !_showRegisterFields) ...[
                          // صفحه دوم - دریافت کد تأیید
                          Text(
                            'کد تأیید به شماره ${_verificationPhone} ارسال شد',
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontSize: 16),
                          ),
                          const SizedBox(height: 20),
                          TextFormField(
                            controller: _codeController,
                            keyboardType: TextInputType.number,
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontSize: 16, letterSpacing: 2, fontFamily: 'VazirD'),
                            decoration: InputDecoration(
                              hintText: 'کد تأیید',
                              hintStyle: TextStyle(
                                fontSize: 18,
                                color: Colors.grey.shade500,
                                fontFamily: 'VazirD',
                              ),
                              prefixIcon: Icon(
                                Icons.sms,
                                color: Colors.grey.shade500,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12.0),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12.0),
                                borderSide: BorderSide(color: Colors.grey.shade700),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12.0),
                                borderSide: BorderSide(color: theme.colorScheme.primary, width: 1.5),
                              ),
                              filled: true,
                              fillColor: Colors.black.withOpacity(0.1),
                              contentPadding: const EdgeInsets.symmetric(vertical: 15),
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'لطفاً کد تأیید را وارد کنید';
                              }
                              if (value.length != 4) {
                                return 'کد تأیید باید 4 رقم باشد';
                              }
                              return null;
                            },
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                              LengthLimitingTextInputFormatter(4),
                            ],
                          ),
                          const SizedBox(height: 30),
                          ElevatedButton(
                            onPressed: _verifyCode,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color.fromARGB(255, 41, 98, 255),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(5.0),
                              ),
                              elevation: 5,
                            ),
                            child: const Text(
                              'تأیید کد',
                              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w500, fontFamily: 'Vazir'),
                            ),
                          ),
                        ],
                        
                        if (_showRegisterFields) ...[
                          // صفحه سوم - ثبت نام کاربر جدید
                          TextFormField(
                            controller: _firstNameController,
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontSize: 16, letterSpacing: 1, fontFamily: 'VazirD'),
                            decoration: InputDecoration(
                              hintText: 'نام',
                              hintStyle: TextStyle(
                                fontSize: 16,
                                color: Colors.grey.shade500,
                                fontFamily: 'VazirD',
                              ),
                              prefixIcon: Icon(
                                Icons.person,
                                color: Colors.grey.shade500,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12.0),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12.0),
                                borderSide: BorderSide(color: Colors.grey.shade700),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12.0),
                                borderSide: BorderSide(color: theme.colorScheme.primary, width: 1.5),
                              ),
                              filled: true,
                              fillColor: Colors.black.withOpacity(0.1),
                              contentPadding: const EdgeInsets.symmetric(vertical: 15),
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'لطفاً نام خود را وارد کنید';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 20),
                          TextFormField(
                            controller: _lastNameController,
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontSize: 16, letterSpacing: 1, fontFamily: 'VazirD'),
                            decoration: InputDecoration(
                              hintText: 'نام خانوادگی',
                              hintStyle: TextStyle(
                                fontSize: 16,
                                color: Colors.grey.shade500,
                                fontFamily: 'VazirD',
                              ),
                              prefixIcon: Icon(
                                Icons.person_outline,
                                color: Colors.grey.shade500,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12.0),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12.0),
                                borderSide: BorderSide(color: Colors.grey.shade700),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12.0),
                                borderSide: BorderSide(color: theme.colorScheme.primary, width: 1.5),
                              ),
                              filled: true,
                              fillColor: Colors.black.withOpacity(0.1),
                              contentPadding: const EdgeInsets.symmetric(vertical: 15),
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'لطفاً نام خانوادگی خود را وارد کنید';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 30),
                          ElevatedButton(
                            onPressed: _registerUser,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color.fromARGB(255, 41, 98, 255),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(5.0),
                              ),
                              elevation: 5,
                            ),
                            child: const Text(
                              'تکمیل ثبت نام',
                              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w500, fontFamily: 'Vazir'),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
        ),
      ),
    );
  }
}