import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'config.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const AyeshaApp());
}

class ChatMessage {
  final String role;
  final String content;
  final DateTime time;

  ChatMessage({required this.role, required this.content, DateTime? time})
      : time = time ?? DateTime.now();

  Map<String, dynamic> toJson() => {
        'role': role,
        'content': content,
        'time': time.toIso8601String(),
      };

  factory ChatMessage.fromJson(Map<String, dynamic> json) => ChatMessage(
        role: json['role'] as String,
        content: json['content'] as String,
        time: DateTime.tryParse(json['time'] ?? '') ?? DateTime.now(),
      );
}

class AyeshaApp extends StatelessWidget {
  const AyeshaApp({super.key});

  @override
  Widget build(BuildContext context) {
    const seed = Color(0xFF8064C8);
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'আয়েশা AI',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: seed, brightness: Brightness.light),
        scaffoldBackgroundColor: const Color(0xFFF8F5FF),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFFF8F5FF),
          foregroundColor: Color(0xFF30264A),
          centerTitle: false,
        ),
      ),
      home: const ChatScreen(),
    );
  }
}

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  static const _storageKey = 'ayesha_chat_v1';
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  final List<ChatMessage> _messages = [];
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_storageKey);
    if (raw != null) {
      try {
        final list = (jsonDecode(raw) as List).cast<Map<String, dynamic>>();
        setState(() => _messages.addAll(list.map(ChatMessage.fromJson)));
      } catch (_) {
        setState(() => _error = 'আগের চ্যাট পড়া যায়নি। নতুন কথোপকথন শুরু করতে পারো।');
      }
    }
    if (mounted && _messages.isEmpty) {
      setState(() {
        _messages.add(ChatMessage(
          role: 'assistant',
          content: 'হ্যালো! আমি আয়েশা। আজ তোমার দিন কেমন যাচ্ছে? চাইলে মন খুলে কথা বলতে পারো।',
        ));
      });
      _saveHistory();
    }
  }

  Future<void> _saveHistory() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _storageKey,
      jsonEncode(_messages.map((m) => m.toJson()).toList()),
    );
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _loading) return;

    setState(() {
      _error = null;
      _messages.add(ChatMessage(role: 'user', content: text));
      _loading = true;
    });
    _controller.clear();
    await _saveHistory();
    _jumpToBottom();

    try {
      // Send the most recent messages to preserve conversation context.
      final recent = _messages.where((m) => m.role == 'user' || m.role == 'assistant').toList();
      final history = recent.length > 20 ? recent.sublist(recent.length - 20) : recent;

      final response = await http
          .post(
            Uri.parse('${AppConfig.apiBaseUrl}/chat'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'messages': history
                  .map((m) => {'role': m.role, 'content': m.content})
                  .toList(),
            }),
          )
          .timeout(const Duration(seconds: 60));

      if (response.statusCode != 200) {
        throw Exception('সার্ভার উত্তর দেয়নি (${response.statusCode})');
      }
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final reply = (data['reply'] ?? '').toString().trim();
      if (reply.isEmpty) throw Exception('খালি উত্তর পাওয়া গেছে।');

      setState(() => _messages.add(ChatMessage(role: 'assistant', content: reply)));
      await _saveHistory();
    } catch (e) {
      setState(() => _error = 'সংযোগে সমস্যা হয়েছে। ইন্টারনেট ও Backend ঠিক আছে কি না দেখো।');
    } finally {
      if (mounted) {
        setState(() => _loading = false);
        _jumpToBottom();
      }
    }
  }

  void _jumpToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _clearChat() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('চ্যাট মুছে ফেলবে?'),
        content: const Text('এই ডিভাইসে সংরক্ষিত কথোপকথনের ইতিহাস মুছে যাবে।'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('না')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('মুছে ফেলো')),
        ],
      ),
    );
    if (ok == true) {
      setState(() {
        _messages
          ..clear()
          ..add(ChatMessage(
            role: 'assistant',
            content: 'আবার শুরু করি। আজ কী নিয়ে কথা বলতে চাও?',
          ));
      });
      await _saveHistory();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(colors: [Color(0xFFBCA7F2), Color(0xFF8064C8)]),
              ),
              child: const Icon(Icons.auto_awesome, color: Colors.white),
            ),
            const SizedBox(width: 11),
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('আয়েশা', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18)),
                Text('AI Companion • অনলাইন চ্যাট', style: TextStyle(fontSize: 11, color: Colors.black54)),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'চ্যাট মুছুন',
            onPressed: _clearChat,
            icon: const Icon(Icons.delete_outline),
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            margin: const EdgeInsets.fromLTRB(14, 4, 14, 8),
            padding: const EdgeInsets.all(11),
            decoration: BoxDecoration(
              color: const Color(0xFFEDE6FC),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Text(
              'আমি কথা শুনতে ও ভাবনা গুছিয়ে নিতে সাহায্য করতে পারি। বাস্তব জীবনের বিশ্বস্ত মানুষদের সঙ্গেও যোগাযোগ রেখো।',
              style: TextStyle(fontSize: 12, color: Color(0xFF51436E)),
              textAlign: TextAlign.center,
            ),
          ),
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.fromLTRB(14, 8, 14, 12),
              itemCount: _messages.length + (_loading ? 1 : 0),
              itemBuilder: (context, index) {
                if (_loading && index == _messages.length) {
                  return const Align(
                    alignment: Alignment.centerLeft,
                    child: Padding(
                      padding: EdgeInsets.all(12),
                      child: Text('আয়েশা লিখছে…', style: TextStyle(color: Colors.black54)),
                    ),
                  );
                }
                final message = _messages[index];
                final isUser = message.role == 'user';
                return Align(
                  alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * .82),
                    margin: const EdgeInsets.symmetric(vertical: 5),
                    padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 11),
                    decoration: BoxDecoration(
                      color: isUser ? const Color(0xFF8064C8) : Colors.white,
                      borderRadius: BorderRadius.only(
                        topLeft: const Radius.circular(18),
                        topRight: const Radius.circular(18),
                        bottomLeft: Radius.circular(isUser ? 18 : 5),
                        bottomRight: Radius.circular(isUser ? 5 : 18),
                      ),
                      boxShadow: const [BoxShadow(color: Color(0x10000000), blurRadius: 7, offset: Offset(0, 2))],
                    ),
                    child: Text(
                      message.content,
                      style: TextStyle(
                        color: isUser ? Colors.white : const Color(0xFF30264A),
                        fontSize: 15,
                        height: 1.45,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Text(_error!, style: const TextStyle(color: Colors.red, fontSize: 12)),
            ),
          SafeArea(
            top: false,
            child: Container(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
              color: const Color(0xFFF8F5FF),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      minLines: 1,
                      maxLines: 5,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _send(),
                      decoration: InputDecoration(
                        hintText: 'আয়েশাকে কিছু বলো…',
                        filled: true,
                        fillColor: Colors.white,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 17, vertical: 13),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(26),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  CircleAvatar(
                    radius: 24,
                    backgroundColor: const Color(0xFF8064C8),
                    child: IconButton(
                      onPressed: _loading ? null : _send,
                      icon: const Icon(Icons.send_rounded, color: Colors.white, size: 21),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
