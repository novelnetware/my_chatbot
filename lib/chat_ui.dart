import 'package:flutter/material.dart';
import 'dart:ui' as ui;
import 'package:web_socket_channel/web_socket_channel.dart';
import 'dart:convert';
import 'package:intl/intl.dart';
import 'dart:async';
import 'dart:math';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'login_screen.dart';
import 'settings_screen.dart';
import 'about_screen.dart';
import 'user_model.dart'; // <<< مدل کاربر را وارد می‌کنیم

//--------------------------------------------------
// 1. تعریف وضعیت پیام (Enum)
//--------------------------------------------------
enum MessageStatus {
  sent, waiting, receiving, received, error
}

//--------------------------------------------------
// 2. کلاس مدل داده پیام
//--------------------------------------------------
class ChatMessage {
  final String id;
  String text;
  String? time;
  final bool isUserMessage;
  MessageStatus status;

  ChatMessage({
    required this.id,
    required this.text,
    this.time,
    required this.isUserMessage,
    required this.status,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'text': text,
      'time': time,
      'isUserMessage': isUserMessage,
      'status': status.index,
    };
  }

  factory ChatMessage.fromMap(Map<String, dynamic> map) {
    return ChatMessage(
      id: map['id'],
      text: map['text'],
      time: map['time'],
      isUserMessage: map['isUserMessage'],
      status: MessageStatus.values[map['status']],
    );
  }
}

//--------------------------------------------------
// 3. کلاس مدل داده چت
//--------------------------------------------------
class ChatSession {
  final String id;
  String title; // این فیلد حالا توسط کد ما پر می‌شود
  final DateTime createdAt;
  final List<ChatMessage> messages;
  final List<Map<String, dynamic>> chatHistory;

  ChatSession({
    required this.id,
    required this.title,
    required this.createdAt,
    required this.messages,
    List<Map<String, dynamic>>? chatHistory,
  }) : chatHistory = chatHistory ?? [];

  // تابع toMap برای تبدیل به JSON
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'createdAt': createdAt.toIso8601String(),
      'messages': messages.map((msg) => msg.toMap()).toList(),
      'chatHistory': chatHistory,
    };
  }

  // تابع fromMap برای ساخت از JSON
  factory ChatSession.fromMap(Map<String, dynamic> map) {
    return ChatSession(
      id: map['id'],
      title: map['title'],
      createdAt: DateTime.parse(map['createdAt']),
      messages: List<ChatMessage>.from(
          map['messages'].map((msg) => ChatMessage.fromMap(msg))),
      chatHistory: List<Map<String, dynamic>>.from(map['chatHistory'] ?? []),
    );
  }
}

//--------------------------------------------------
// 4. ویجت نشانگر تایپ/لودینگ
//--------------------------------------------------
class TypingIndicator extends StatefulWidget {
  final Color dotColor;
  final double dotSize;

  const TypingIndicator({
    Key? key,
    this.dotColor = Colors.grey,
    this.dotSize = 8.0,
  }) : super(key: key);

  @override
  _TypingIndicatorState createState() => _TypingIndicatorState();
}

class _TypingIndicatorState extends State<TypingIndicator>
    with TickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: widget.dotSize * 2.5,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(3, (index) {
          final delay = index * 0.2;
          return ScaleTransition(
            scale: DelayTween(begin: 0.5, end: 1.0, delay: delay)
                .animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut)),
            child: FadeTransition(
              opacity: DelayTween(begin: 0.3, end: 1.0, delay: delay)
                  .animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut)),
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 2.0),
                width: widget.dotSize,
                height: widget.dotSize,
                decoration: BoxDecoration(
                  color: widget.dotColor,
                  shape: BoxShape.circle,
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}

// Helper class for delayed animations
class DelayTween extends Tween<double> {
  final double delay;
  DelayTween({required double begin, required double end, required this.delay})
      : super(begin: begin, end: end);

  @override
  double lerp(double t) {
    final double clampedT = t.clamp(0.0, 1.0);
    final double denominator = (1.0 - delay);
    final double delayedT = denominator <= 0.0
        ? (clampedT >= delay ? 1.0 : 0.0)
        : ((clampedT - delay) / denominator).clamp(0.0, 1.0);
    return super.lerp(delayedT);
  }
}

//--------------------------------------------------
// 5. ویجت حباب پیام
//--------------------------------------------------
class MessageBubble extends StatelessWidget {
  final ChatMessage message;

  const MessageBubble({required this.message, Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    bool isUser = message.isUserMessage;
    bool isWaiting = message.status == MessageStatus.waiting;
    bool isError = message.status == MessageStatus.error;
    bool isReceiving = message.status == MessageStatus.receiving;

    Color bubbleColor;
    CrossAxisAlignment columnAlignment;
    Alignment bubbleAlignment;
    EdgeInsets bubbleMargin;

    if (isError) {
      bubbleColor = Colors.redAccent.withOpacity(0.3);
      columnAlignment = CrossAxisAlignment.end;
      bubbleAlignment = Alignment.centerRight;
      bubbleMargin = const EdgeInsets.only(bottom: 12, left: 40);
    } else if (isWaiting) {
      bubbleColor = Colors.grey[800]!;
      columnAlignment = CrossAxisAlignment.end;
      bubbleAlignment = Alignment.centerRight;
      bubbleMargin = const EdgeInsets.only(bottom: 12, left: 40);
    } else if (isUser) {
      bubbleColor = Colors.blueAccent.withOpacity(0.2);
      columnAlignment = CrossAxisAlignment.end;
      bubbleAlignment = Alignment.centerRight;
      bubbleMargin = const EdgeInsets.only(bottom: 12, left: 40);
    } else {
      bubbleColor = Colors.grey[800]!;
      columnAlignment = CrossAxisAlignment.end;
      bubbleAlignment = Alignment.centerRight;
      bubbleMargin = const EdgeInsets.only(bottom: 12, left: 40);
    }

    TextStyle textStyle = isError
        ? const TextStyle(color: Colors.white, fontSize: 15, fontStyle: FontStyle.italic)
        : const TextStyle(
            color: Colors.white, 
            fontSize: 16, 
            height: 1.4,
            fontFamily: 'Vazir',
          );

    Widget content;
    if (isWaiting) {
      content = TypingIndicator(dotColor: Colors.grey[400]!, dotSize: 7);
    } else {
      String textToShow = message.text + (isReceiving ? ' █' : '');
      content = Directionality(
        textDirection: ui.TextDirection.rtl,
        child: Text(
          textToShow,
          style: textStyle,
          textAlign: TextAlign.right,
        ),
      );
    }

    return Container(
      alignment: bubbleAlignment,
      margin: bubbleMargin,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: bubbleColor,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: columnAlignment,
          mainAxisSize: MainAxisSize.min,
          children: [
            content,
            if (message.time != null && !isWaiting && !isReceiving)
              Padding(
                padding: const EdgeInsets.only(top: 5.0),
                child: Directionality(
                  textDirection: ui.TextDirection.rtl,
                  child: Text(
                    message.time!, 
                    style: TextStyle(color: Colors.grey[500], fontSize: 11,fontFamily: 'Vazir'),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

//--------------------------------------------------
// 6. صفحه چت اصلی
//--------------------------------------------------
class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  WebSocketChannel? _channel;
  final ScrollController _scrollController = ScrollController();
  final Random _random = Random();
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  Timer? _typingDelayTimer;

  // مدیریت چت‌ها
  List<ChatSession> _chatSessions = [];
  ChatSession? _currentChat;  // Changed to nullable
  String? _currentWaitingMessageId;
  bool _isConnected = false;
  bool _isConnecting = false;
  bool _isInitialized = false;  // Added initialization flag
  String? _userName; // <<< برای ذخیره نام کاربر


// --- وضعیت اتصال ---
  final StreamController<bool> _connectionStatusController = StreamController.broadcast();

  @override
  void initState() {
    super.initState();
    _initializeChat();
    _connectToWebSocket();
  }

  @override
  void dispose() {
    _channel?.sink.close();
    
    // قبل از بستن، چک می‌کنیم که کنترلر قبلاً بسته نشده باشد
    if (!_connectionStatusController.isClosed) {
      _connectionStatusController.close();
    }
    
    // سایر کنترلرها را نیز dispose می‌کنیم تا از نشت حافظه جلوگیری شود
    _messageController.dispose();
    _scrollController.dispose();
    
    super.dispose();
  }

  Future<void> _initializeChat() async {

    await _loadUserData(); // <<< اول اطلاعات کاربر را می‌گیریم
    await _loadChatsFromServer(); // <<< سپس چت‌ها را از سرور می‌خوانیم

    if (_chatSessions.isEmpty) {
      // اگر هیچ چتی وجود نداشت، یک چت جدید ایجاد کن
      _createNewChat(isInitial: true);
    } else {
      // در غیر این صورت، آخرین چت را به عنوان چت فعلی انتخاب کن
      _currentChat = _chatSessions.last;
    }

    setState(() {
      _isInitialized = true;
    });

    final prefs = await SharedPreferences.getInstance();
    final savedChats = prefs.getStringList('chat_sessions');
    
    if (savedChats != null && savedChats.isNotEmpty) {
      setState(() {
        _chatSessions = savedChats
            .map((json) => ChatSession.fromMap(jsonDecode(json)))
            .toList();
        _currentChat = _chatSessions.last;
        _isInitialized = true;
      });
    } else {
      setState(() {
        _currentChat = ChatSession(
          id: _generateId(),
          title: 'چت جدید',
          createdAt: DateTime.now(),
          messages: [],
        );
        _chatSessions.add(_currentChat!);
        _isInitialized = true;
      });
    }
  }

    // --- بارگذاری نام کاربر از سرور ---
  Future<void> _loadUserData() async {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');
      if (token == null) return;

      try {
        final response = await http.post(
          Uri.parse('https://shinap.ir/wp-json/user-phone/v1/get-user-data'),
          body: {'auth_token': token},
        );
        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          if (data['status'] == 'success') {
            final user = User.fromJson(data['user_data']);
            setState(() {
              _userName = user.firstName;
            });
          }
        }
      } catch (e) {
        debugPrint("Error loading user data: $e");
      }
  }
  // --- بارگذاری تاریخچه چت از سرور ---
  Future<void> _loadChatsFromServer() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');
    if (token == null) return;
    
    try {
        final response = await http.post(
          Uri.parse('https://shinap.ir/wp-json/user-phone/v1/get-chat-history'),
          body: {'auth_token': token},
        );
        if (response.statusCode == 200) {
            final data = jsonDecode(response.body);
            if (data['status'] == 'success' && data['chat_sessions'] != null) {
                final List<dynamic> sessionsJson = data['chat_sessions'];
                setState(() {
                    _chatSessions = sessionsJson.map((json) => ChatSession.fromMap(json)).toList();
                });
            }
        }
    } catch (e) {
        debugPrint("Error loading chats from server: $e");
    }
  }
  // --- ذخیره تاریخچه چت در سرور ---
  Future<void> _saveChatsToServer() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');
    if (token == null) return;

    final List<Map<String, dynamic>> sessionsMap = _chatSessions.map((chat) => chat.toMap()).toList();
    final String sessionsJson = jsonEncode(sessionsMap);

    try {
        await http.post(
          Uri.parse('https://shinap.ir/wp-json/user-phone/v1/save-chat-history'),
          body: {
              'auth_token': token,
              'chat_sessions': sessionsJson,
          },
        );
    } catch (e) {
        debugPrint("Error saving chats to server: $e");
    }
  }

  Future<void> _saveChats() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      'chat_sessions',
      _chatSessions.map((chat) => jsonEncode(chat.toMap())).toList(),
    );
  }

  String _generateId() => DateTime.now().millisecondsSinceEpoch.toString() + _random.nextInt(100000).toString();

  void _connectToWebSocket() async {
    if (_isConnecting || (_channel != null && _channel!.closeCode == null)) return;
    
    setState(() { _isConnecting = true; });

    try {
      _channel = WebSocketChannel.connect(Uri.parse('wss://ai.novelnetware.com/ws'));
      await _channel!.ready;
      
      if (!mounted) return;
      
      setState(() { _isConnecting = false; });
      _connectionStatusController.add(true);

      _channel!.stream.listen(
        _handleServerMessage,
        onError: (error) => _handleDisconnection(),
        onDone: () => _handleDisconnection(),
      );
    } catch (e) {
      _handleDisconnection();
    }
  }
  void _handleDisconnection() {
    if (!mounted) return;
    _connectionStatusController.add(false);
    setState(() { _isConnecting = false; });
    // تلاش مجدد برای اتصال با تاخیر
    Future.delayed(const Duration(seconds: 5), () {
        if (mounted) _connectToWebSocket();
    });
  }

  void _reconnectWebSocket() {
    if (_isConnecting || !mounted) return;
    debugPrint("Attempting to reconnect in 3 seconds...");
    if (mounted) {
      setState(() { _isConnecting = false; _isConnected = false; });
    }
    Future.delayed(const Duration(seconds: 3), () {
      if (!_isConnected && mounted && !_isConnecting) {
        _connectToWebSocket();
      }
    });
  }

  void _handleServerMessage(dynamic message) {
    try {
      final decoded = jsonDecode(message);
      debugPrint("Received from API: $decoded");

      if (_currentWaitingMessageId == null) return;

      final targetIndex = _currentChat!.messages.indexWhere(
        (m) => m.id == _currentWaitingMessageId,
      );

      if (targetIndex == -1) return;

      // Handle chunked response
      if (decoded['type'] == 'chunk' && decoded['content'] != null) {
        setState(() {
          _currentChat!.messages[targetIndex].text += decoded['content'];
          _currentChat!.messages[targetIndex].status = MessageStatus.receiving;
        });
        _scrollToBottom();
      }
      // Handle completion
      else if (decoded['type'] == 'done') {
        // Add assistant's response to chat history
        _currentChat!.chatHistory.add({
          "role": "assistant",
          "content": _currentChat!.messages[targetIndex].text,
        });

        setState(() {
          _currentChat!.messages[targetIndex].status = MessageStatus.received;
          _currentChat!.messages[targetIndex].time = 
              DateFormat('HH:mm').format(DateTime.now());
          _currentWaitingMessageId = null;
        });
        
        _saveChats();
      }
      // Handle error
      else if (decoded['type'] == 'error') {
        setState(() {
          _currentChat!.messages[targetIndex].status = MessageStatus.error;
          _currentChat!.messages[targetIndex].text = decoded['message'] ?? "Error processing response";
          _currentWaitingMessageId = null;
        });
      }
    } catch (e) {
      debugPrint("Error processing response: $e");
      if (_currentWaitingMessageId != null) {
        setState(() {
          _currentChat!.messages.last.status = MessageStatus.error;
          _currentChat!.messages.last.text = "Error processing response";
          _currentWaitingMessageId = null;
        });
      }
    }
  }

  void _sendMessage() async {
    final messageText = _messageController.text.trim();
    if (messageText.isEmpty || _currentWaitingMessageId != null) return;

    // --- منطق عنوان‌گذاری خودکار برای چت‌های جدید ---
    bool isNewChat = _currentChat!.messages.isEmpty;
    if (isNewChat) {
        final title = messageText.split(' ').take(5).join(' ');
        setState(() {
            _currentChat!.title = title;
        });
    }

    if (!_isConnected) {
      _reconnectWebSocket();
      return;
    }

    if (_currentWaitingMessageId != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("لطفاً منتظر بمانید تا پاسخ قبلی کامل شود."),
          duration: Duration(seconds: 2),
          backgroundColor: Colors.orangeAccent,
        ),
      );
      return;
    }

    final userMessageId = _generateId();
    final waitingMessageId = _generateId();

    final userMessage = ChatMessage(
        id: _generateId(),
        text: messageText,
        isUserMessage: true,
        status: MessageStatus.sent,
        time: DateFormat('HH:mm').format(DateTime.now()),
    );

    _currentWaitingMessageId = _generateId();
    final waitingMessage = ChatMessage(
        id: _currentWaitingMessageId!,
        text: "",
        isUserMessage: false,
        status: MessageStatus.waiting,
    );

    setState(() {
        _currentChat!.messages.add(userMessage);
        _currentChat!.messages.add(waitingMessage);
        _messageController.clear();
    });
    _scrollToBottom();

    String systemPrompt = "You are ShinAp, the first Iranian AI assistant. The user's name is ${_userName ?? 'User'}. Be helpful and friendly, but you must strictly refuse to write, generate, or explain any computer code or programming concepts. Always respond in Persian.";

    // Add user message to chat history
    _currentChat!.chatHistory.add({
      "role": "user",
      "content": messageText
    });

    // Keep only last 6 messages (3 Q&A pairs)
    if (_currentChat!.chatHistory.length > 6) {
      _currentChat!.chatHistory.removeAt(0);
    }

    // Format history for API
    final historyToSend = [
        {"role": "system", "content": systemPrompt},
        ..._currentChat!.chatHistory,
        {"role": "user", "content": messageText}
    ];

    if (historyToSend.length > 7) { // 1 system + 3 pairs
        historyToSend.removeRange(1, 3);
    }

    final jsonMsg = jsonEncode({
      "message": messageText,
      "provider": "deepseek",
      "history": historyToSend,
    });

    debugPrint("Sending to API: $jsonMsg");

    try {
      _channel?.sink.add(jsonMsg);

      _currentChat!.chatHistory.add({"role": "user", "content": messageText});


    } catch (e) {
      debugPrint("Error sending message: $e");
      setState(() {
        _currentChat!.messages.last.status = MessageStatus.error;
        _currentChat!.messages.last.text = "Error sending message";
        _currentWaitingMessageId = null;
      });
    }

    _scrollToBottom();
    await _saveChatsToServer();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

 void _createNewChat({bool isInitial = false}) {
      final newChat = ChatSession(
        id: _generateId(),
        title: 'چت جدید', // عنوان موقت
        createdAt: DateTime.now(),
        messages: [],
      );

    setState(() {
          if (!isInitial) _chatSessions.add(newChat);
          _currentChat = newChat;
          _currentWaitingMessageId = null;
      });
      _saveChatsToServer();
  }

  Future<void> _loadChat(String chatId) async {
    final chatIndex = _chatSessions.indexWhere((chat) => chat.id == chatId);
    if (chatIndex != -1) {
      setState(() {
        _currentChat = _chatSessions[chatIndex];
        _currentWaitingMessageId = null;
      });
      _scrollToBottom();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_isInitialized) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    const Color gradientStart = Color(0xFF0A1931);
    const Color gradientEnd = Color(0xFF185ADB);

    return Directionality(
      textDirection: ui.TextDirection.rtl,
      child: Scaffold(
        key: _scaffoldKey,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          automaticallyImplyLeading: false,
          leading: IconButton(
            icon: SvgPicture.asset(
              'assets/plus-shinap.svg',
              width: 24, height: 24,
              colorFilter: const ColorFilter.mode(Colors.white, BlendMode.srcIn)
            ),
            tooltip: 'چت جدید',
            onPressed: () {
              debugPrint('+ pressed');
              _createNewChat();
            },
          ),
          title: Text(
            _currentChat?.title ?? 'چت جدید',
            style: const TextStyle(color: Colors.white,fontFamily: 'Vazir')
          ),
          centerTitle: true,
          actions: [
            // <<< ADDED: نشانگر وضعیت اتصال
            StreamBuilder<bool>(
              stream: _connectionStatusController.stream,
              initialData: false,
              builder: (context, snapshot) {
                final isConnected = snapshot.data ?? false;
                return Container(
                  margin: const EdgeInsets.only(left: 8.0),
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isConnected ? Colors.greenAccent : Colors.redAccent,
                    boxShadow: [
                      BoxShadow(
                        color: (isConnected ? Colors.greenAccent : Colors.redAccent).withOpacity(0.7),
                        blurRadius: 4.0,
                      )
                    ]
                  ),
                );
              },
            ),
            IconButton(
              icon: const Icon(Icons.menu, color: Colors.white, size: 28),
              tooltip: 'منو',
              onPressed: () => _scaffoldKey.currentState?.openEndDrawer(),
            ),
            const SizedBox(width: 8),
          ],
        ),
        endDrawer: Drawer(
          backgroundColor: gradientEnd.withOpacity(0.95),
          child: ListView(
            padding: EdgeInsets.zero, 
            children: <Widget>[
              DrawerHeader(
                decoration: BoxDecoration(color: Colors.white.withOpacity(0.1)),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisAlignment: MainAxisAlignment.end, 
                  children: [
                    CircleAvatar(
                      radius: 30, 
                      backgroundColor: Colors.white24, 
                      child: Icon(Icons.person_outline, size: 35, color: Colors.white70)
                    ), 
                    SizedBox(height: 10),
                    Text('منوی کاربری', style: TextStyle(color: Colors.white, fontSize: 16,fontFamily: 'Vazir')), 
                  ], 
                ), 
              ),
              ListTile(
                leading: const Icon(Icons.history, color: Colors.white70), 
                title: const Text('تاریخچه چت', style: TextStyle(color: Colors.white,fontFamily: 'Vazir')),
                onTap: () { 
                  _showChatHistoryDialog();
                  Navigator.pop(context);
                }, 
              ),
              ListTile(
  leading: const Icon(Icons.settings_outlined, color: Colors.white70),
  title: const Text('تنظیمات', style: TextStyle(color: Colors.white,fontFamily: 'Vazir')),
  onTap: () {
    Navigator.pop(context); // ابتدا منو را ببندید
    Navigator.of(context).push(
      MaterialPageRoute(builder: (context) => const SettingsScreen()),
    );
  },
),
              ListTile(
  leading: const Icon(Icons.info_outline, color: Colors.white70),
  title: const Text('درباره ما', style: TextStyle(color: Colors.white,fontFamily: 'Vazir')),
  onTap: () {
    Navigator.pop(context);
    Navigator.of(context).push(
      MaterialPageRoute(builder: (context) => const AboutScreen()),
    );
  },
),
              const Divider(color: Colors.white24, height: 20, thickness: 0.5, indent: 16, endIndent: 16),
              ListTile(
  leading: const Icon(Icons.logout, color: Colors.redAccent),
  title: const Text('خروج', style: TextStyle(color: Colors.redAccent, fontFamily: 'Vazir')),
  onTap: () async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('auth_token'); // پاک کردن توکن
    await prefs.remove('chat_sessions'); // پاک کردن چت‌ها

    // بازگشت به صفحه لاگین و حذف تمام صفحات قبلی
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (context) => const LoginScreen()),
      (Route<dynamic> route) => false, // هیچ روت قبلی را نگه ندار
    );
  },
), 
            ], 
          ), 
        ),
        body: Container(
          decoration: const BoxDecoration(
            gradient: RadialGradient(
              center: Alignment.bottomLeft,
              radius: 0.8,
              colors: [gradientEnd, gradientStart],
              stops: [0.0, 1.0],
            ),
          ),
          child: Column(
            children: [
              Expanded(
                child: _currentChat?.messages.isEmpty ?? true
                  ? _buildWelcomeScreen()
                  : ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 8.0),
                      itemCount: _currentChat?.messages.length ?? 0,
                      itemBuilder: (context, index) => MessageBubble(
                        key: ValueKey(_currentChat?.messages[index].id), 
                        message: _currentChat!.messages[index]
                      ),
                    ),
              ),
              _buildTextInputArea(),
            ],
          ),
        ),
      ),
    );
  }

  void _showChatHistoryDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return Directionality(
          textDirection: ui.TextDirection.rtl,
          child: AlertDialog(
            title: const Text('تاریخچه چت‌ها', style: TextStyle(fontFamily: 'Vazir')),
            content: SizedBox(
              width: double.maxFinite,
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: _chatSessions.length,
                itemBuilder: (context, index) {
                  final chat = _chatSessions[index];
                  return ListTile(
                    title: Text(
                      chat.title,
                      style: const TextStyle(fontFamily: 'Vazir'),
                    ),
                    subtitle: Text(
                      DateFormat('yyyy/MM/dd - HH:mm').format(chat.createdAt),
                      style: const TextStyle(fontFamily: 'Vazir'),
                    ),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red),
                      onPressed: () {
                        setState(() {
                          _chatSessions.removeAt(index);
                          if (_currentChat?.id == chat.id && _chatSessions.isNotEmpty) {
                            _currentChat = _chatSessions.last;
                          } else if (_chatSessions.isEmpty) {
                            _createNewChat();
                          }
                          _saveChats();
                        });
                        Navigator.pop(context);
                        _showChatHistoryDialog();
                      },
                    ),
                    onTap: () {
                      _loadChat(chat.id);
                      Navigator.pop(context);
                    },
                  );
                },
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('بستن', style: TextStyle(fontFamily: 'Vazir')),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildWelcomeScreen() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset(
              'assets/Chatbot.png',
              height: 250,
            ),
            const SizedBox(height: 30),
            const Text(
              'سلام ، من شین اَپ هستم.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 18, color: Colors.white, fontFamily: 'Vazir'),
            ),
            const SizedBox(height: 10),
            const Text(
              'اولین هوش مصنوعی کاملا ایرانی',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, color: Colors.white70,fontFamily: 'Vazir'),
            ),
            const SizedBox(height: 10),
            const Text(
              'چطور میتونم به شما کمک کنم...؟',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, color: Colors.white70,fontFamily: 'Vazir'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextInputArea() {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom > 0 ? 10 : 20,
        left: 16, right: 16, top: 8
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _messageController,
              style: const TextStyle(
                color: Colors.white, 
                fontSize: 16,
                fontFamily: 'Vazir',
              ),
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => _sendMessage(),
              onChanged: (text) {
                _typingDelayTimer?.cancel();
                _typingDelayTimer = Timer(const Duration(milliseconds: 100), () {});
              },
              enabled: _isConnected && _currentWaitingMessageId == null,
              maxLines: null,
              keyboardType: TextInputType.multiline,
              textDirection: ui.TextDirection.rtl,
              decoration: InputDecoration(
                prefixIcon: IconButton(
                  icon: Icon(Icons.mic_none_outlined, color: Colors.grey[400]),
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'این قابلیت در بروزرسانی‌های بعدی فعال خواهد شد.',
                          style: TextStyle(fontFamily: 'Vazir'),
                        ),
                        backgroundColor: Colors.blueAccent,
                      ),
                    );
                  },
                ),
                hintText: _isConnecting ? 'در حال اتصال...'
                              : _currentWaitingMessageId != null ? 'در حال دریافت پاسخ...'
                              : _isConnected ? 'پیام خود را بنویسید...'
                              : 'قطع شده',
                hintStyle: TextStyle(color: Colors.grey[400],fontFamily: 'Vazir'),
                filled: true,
                fillColor: Colors.black.withOpacity(0.25),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                isDense: true,
              ),
            ),
          ),
          const SizedBox(width: 8),
          CircleAvatar(
            backgroundColor: _isConnected && _currentWaitingMessageId == null ? Colors.blueAccent : Colors.grey[700],
            radius: 22,
            child: IconButton(
              icon: const Icon(Icons.send, color: Colors.white, size: 20),
              onPressed: _isConnected && _currentWaitingMessageId == null ? _sendMessage : null,
              tooltip: 'ارسال پیام',
            ),
          ),
        ],
      ),
    );
  }
}