// lib/login_screen.dart
import 'dart:async';
import 'package:flutter/foundation.dart' show kIsWeb; // <<< برای تشخیص پلتفرم وب
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'chat_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_otp_text_field/flutter_otp_text_field.dart';
import 'utils/app_notifications.dart';
import 'package:device_info_plus/device_info_plus.dart';

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
  // --- controllers جدید برای تاریخ تولد ---
  final TextEditingController _birthDayController = TextEditingController();
  final TextEditingController _birthMonthController = TextEditingController();
  final TextEditingController _birthYearController = TextEditingController();
  // -----------------------------------------
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();


  
  String? _authToken;
  bool _isLoading = false;
  bool _showCodeField = false;
  bool _showRegisterFields = false;
  String? _verificationPhone;
  Timer? _timer;
  int _start = 60;
  bool _canResend = false;
  String _deviceInfo = "Unknown"; 

  @override
  void initState() {
    super.initState();
    _checkSavedAuth();
    _getDeviceInfo();
  }

   // --- تابع جدید برای دریافت اطلاعات دستگاه ---
  Future<void> _getDeviceInfo() async {
    DeviceInfoPlugin deviceInfoPlugin = DeviceInfoPlugin();
    String info = "Unknown";
    try {
      if (kIsWeb) {
        WebBrowserInfo webBrowserInfo = await deviceInfoPlugin.webBrowserInfo;
        info = 'Web: ${webBrowserInfo.browserName.name} on ${webBrowserInfo.platform}';
      } else {
        // چون کد شما برای اندروید و iOS است، هر دو را در نظر می‌گیریم
        if (Theme.of(context).platform == TargetPlatform.android) {
            AndroidDeviceInfo androidInfo = await deviceInfoPlugin.androidInfo;
            info = 'Android: ${androidInfo.model} (SDK ${androidInfo.version.sdkInt})';
        } else if (Theme.of(context).platform == TargetPlatform.iOS) {
            IosDeviceInfo iosInfo = await deviceInfoPlugin.iosInfo;
            info = 'iOS: ${iosInfo.utsname.machine}';
        }
      }
    } catch (e) {
      info = "Error getting device info";
    }
    if(mounted) {
      setState(() {
        _deviceInfo = info;
      });
    }
  }

  void startTimer() {
  _canResend = false;
  _start = 60;
  _timer = Timer.periodic(
    const Duration(seconds: 1),
    (Timer timer) {
      if (_start == 0) {
        setState(() {
          _canResend = true;
          timer.cancel();
        });
      } else {
        setState(() {
          _start--;
        });
      }
    },
  );
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
        body: {
          'phone': phoneNumber,
          'device_info': _deviceInfo, // <<< ارسال اطلاعات دستگاه
        },
      );
      
      final data = jsonDecode(response.body);
      
      if (response.statusCode == 200) {
        startTimer();
        if (data['status'] == 'codex') {
          // کاربر وجود دارد - درخواست کد تأیید
          setState(() {
            _showCodeField = true;
            _verificationPhone = phoneNumber;
          });
        } else if (data['status'] == 'reg') {
          startTimer();
          // کاربر جدید - کد ارسال شده
          setState(() {
            _showCodeField = true;
            _verificationPhone = phoneNumber;
          });
          AppNotifications.showSnackBar(
  context,
  'کد تأیید به شماره شما ارسال شد',
  type: NotificationType.success,
);
        }
      } else {
        AppNotifications.showSnackBar(
    context,
    'خطا در ارتباط با سرور',
    type: NotificationType.error,
  );
      }
    } catch (e) {
      AppNotifications.showSnackBar(
    context,
    'خطا در ارتباط با سرور',
    type: NotificationType.error,
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
     'code': _codeController.text, // این خط تغییر می‌کند
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
        AppNotifications.showSnackBar(
    context,
    'کد تایید نامعتبر است',
    type: NotificationType.error,
  );
      }
    } catch (e) {
      AppNotifications.showSnackBar(
    context,
    'خطا در ارتباط با سرور',
    type: NotificationType.error,
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

    final birthDate = "${_birthYearController.text}/${_birthMonthController.text}/${_birthDayController.text}";
    
    try {
      final response = await http.post(
        Uri.parse('https://shinap.ir/wp-json/user-phone/v1/register'),
        body: {
          'phone': _verificationPhone,
          'first_name': _firstNameController.text,
          'last_name': _lastNameController.text,
          'auth_token': _authToken,
          'birth_date': birthDate, // <<< ارسال تاریخ تولد به API
        },
      );
      
      final data = jsonDecode(response.body);
      
      if (response.statusCode == 200 && data['status'] == 'success') {
        // ذخیره توکن و ورود به سیستم
        await _saveAuthTokenAndLogin(_authToken!);
      } else {
        AppNotifications.showSnackBar(
    context,
    'خطا در ثبت نام کاربر',
    type: NotificationType.error,
  );
      }
    } catch (e) {
      AppNotifications.showSnackBar(
    context,
    'خطا در ارتباط با سرور',
    type: NotificationType.error,
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
    _timer?.cancel();
    _phoneController.dispose();
    _codeController.dispose();
    _firstNameController.dispose();
    _lastNameController.dispose();
    _birthDayController.dispose();
    _birthMonthController.dispose();
    _birthYearController.dispose();
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
    style: const TextStyle(fontSize: 16, fontFamily: 'Vazir'),
  ),
                          const SizedBox(height: 20),
  Directionality(
    textDirection: TextDirection.ltr, // برای چیدمان صحیح باکس‌ها
    child: OtpTextField(
      numberOfFields: 4,
      borderColor: const Color(0xFF512DA8),
      showFieldAsBox: true,
      fieldWidth: 50,
      focusedBorderColor: theme.colorScheme.primary,
      textStyle: const TextStyle(fontSize: 20, color: Colors.white),
      onCodeChanged: (String code) {
        // این تابع هر بار با تغییر کد فراخوانی می‌شود
      },
      // onSubmit کد را پس از پر شدن تمام فیلدها برمی‌گرداند
      onSubmit: (String verificationCode) {
        _codeController.text = verificationCode; // کد را در کنترلر ذخیره کن
        _verifyCode(); // تابع تایید کد را فراخوانی کن
      },
    ),
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
                          const SizedBox(height: 20),
  _canResend
      ? TextButton(
          onPressed: () {
            _submitPhone(); // تابع ارسال شماره را دوباره صدا بزن
          },
          child: const Text(
            'ارسال مجدد کد',
            style: TextStyle(fontFamily: 'Vazir'),
          ),
        )
      : Text(
          'ارسال مجدد کد تا $_start ثانیه دیگر',
          style: const TextStyle(color: Colors.grey, fontFamily: 'Vazir'),textAlign: TextAlign.center,
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
                          const SizedBox(height: 20),
                          // --- فیلدهای تاریخ تولد ---
                          const Text(
                            'تاریخ تولد',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontFamily: 'Vazir', color: Colors.white70),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: _buildBirthDateField(_birthYearController, 'سال', 4, 1300, 1400),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: _buildBirthDateField(_birthMonthController, 'ماه', 2, 1, 12),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: _buildBirthDateField(_birthDayController, 'روز', 2, 1, 31),
                              ),
                            ],
                          ),
                          // -------------------------
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
   // --- ویجت کمکی برای ساخت فیلدهای تاریخ تولد ---
  Widget _buildBirthDateField(TextEditingController controller, String hint, int length, int min, int max) {
    return TextFormField(
      controller: controller,
      textAlign: TextAlign.center,
      keyboardType: TextInputType.number,
      style: const TextStyle(fontSize: 16, fontFamily: 'VazirD'),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(fontSize: 14, color: Colors.grey.shade500, fontFamily: 'Vazir'),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12.0)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12.0),
          borderSide: BorderSide(color: Colors.grey.shade700),
        ),
        filled: true,
        fillColor: Colors.black.withOpacity(0.1),
        contentPadding: const EdgeInsets.symmetric(vertical: 12),
      ),
      inputFormatters: [
        FilteringTextInputFormatter.digitsOnly,
        LengthLimitingTextInputFormatter(length),
      ],
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'ضروری';
        }
        final num = int.tryParse(value);
        if (num == null) {
          return 'عدد';
        }
        if (num < min || num > max) {
          return 'نامعتبر';
        }
        return null;
      },
    );
  }
}