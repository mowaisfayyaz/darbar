import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:dio/dio.dart';
import '../services/theme_provider.dart';
import 'booking_confirmed_screen.dart';

class HomeScreen extends StatefulWidget {
  final String? userId;
  final String? userName;
  const HomeScreen({super.key, this.userId, this.userName});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final TextEditingController _controller = TextEditingController();
  final List<Map<String, String>> _messages = [];
  final ScrollController _scroll = ScrollController();
  bool _isTyping = false;

  void _sendMessage() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    setState(() {
      _messages.add({'role': 'user', 'text': text});
      _isTyping = true;
    });
    _controller.clear();
    _scrollToBottom();

    try {
      final dio = Dio();
      final response = await dio.post(
        'http://127.0.0.1:8000/api/request/',
        data: {
          'user_id': widget.userId ?? '147bbe81-5547-431e-b41a-93bceb0cae5f', // Fallback to primary clear uuid
          'text': text,
        },
      );

      final data = response.data;
      
      if (!mounted) return;

      setState(() {
        _isTyping = false;
      });

      if (data['status'] == 'clarification') {
        setState(() {
          _messages.add({'role': 'agent', 'text': data['message']});
        });
        _scrollToBottom();
      } else if (data['status'] == 'processing') {
        setState(() {
          _messages.add({
            'role': 'agent', 
            'text': 'Matches found! Booking confirmed with ${data['provider_name']}.'
          });
        });
        _scrollToBottom();

        // Navigate to the beautiful booking confirmed screen directly
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => BookingConfirmedScreen(
              bookingData: {
                'provider_name': data['provider_name'],
                'provider_rating': data['provider_rating'],
                'message': data['message'],
              },
            ),
          ),
        );
      } else {
        setState(() {
          _messages.add({'role': 'agent', 'text': data['reason'] ?? 'Failed to process request.'});
        });
        _scrollToBottom();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isTyping = false;
          _messages.add({
            'role': 'agent',
            'text': 'Connection error. Please make sure the Django server is running locally on port 8000.'
          });
        });
        _scrollToBottom();
      }
    }
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scroll.hasClients) {
        _scroll.animateTo(
          _scroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final appState = Provider.of<AppStateProvider>(context);
    final isDark = appState.isDarkMode;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF121212) : const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: Column(
          children: [
            const Text('Darbar Agent', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
            Text('Hello, ${widget.userName ?? 'User'}', style: const TextStyle(fontSize: 12, color: Colors.white70)),
          ],
        ),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 12),
            child: appState.customAvatarBytes != null
                ? CircleAvatar(
                    backgroundImage: MemoryImage(appState.customAvatarBytes!),
                  )
                : CircleAvatar(
                    backgroundColor: Colors.white24,
                    child: Icon(
                      appState.currentAvatarIcon,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
          )
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: _messages.isEmpty
                ? _buildEmptyState(isDark)
                : ListView.builder(
                    controller: _scroll,
                    padding: const EdgeInsets.all(16),
                    itemCount: _messages.length,
                    itemBuilder: (context, index) => _buildMessage(_messages[index], isDark),
                  ),
          ),
          if (_isTyping)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
              child: Row(
                children: [
                  const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF1565C0)),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'Agent is thinking...',
                    style: TextStyle(fontSize: 12, color: isDark ? Colors.grey[400] : Colors.grey[600]),
                  ),
                ],
              ),
            ),
          _buildInputBar(isDark),
        ],
      ),
    );
  }

  Widget _buildEmptyState(bool isDark) {
    return Center(
      child: SingleChildScrollView(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: const Color(0xFF1565C0).withOpacity(0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.smart_toy_outlined, size: 60, color: Color(0xFF1565C0)),
            ),
            const SizedBox(height: 20),
            Text(
              'Your AI Booking Agent',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40),
              child: Text(
                'Describe the service you need in any language — English, Urdu, or Roman Urdu.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: isDark ? Colors.grey[400] : Colors.grey[600],
                  fontSize: 14,
                ),
              ),
            ),
            const SizedBox(height: 32),
            _suggestionChip('Hi', isDark),
            _suggestionChip('What can you do for me?', isDark),
            _suggestionChip('Mujhe AC technician chahiye G-13 mein', isDark),
          ],
        ),
      ),
    );
  }

  Widget _suggestionChip(String text, bool isDark) {
    return GestureDetector(
      onTap: () {
        _controller.text = text;
        _sendMessage();
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: const Color(0xFF1565C0).withOpacity(isDark ? 0.4 : 0.25),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(isDark ? 0.15 : 0.04),
              blurRadius: 4,
              offset: const Offset(0, 2),
            )
          ],
        ),
        child: Text(
          text,
          style: const TextStyle(color: Color(0xFF1565C0), fontSize: 13, fontWeight: FontWeight.w500),
        ),
      ),
    );
  }

  Widget _buildMessage(Map<String, String> msg, bool isDark) {
    final isUser = msg['role'] == 'user';
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
        decoration: BoxDecoration(
          color: isUser 
              ? const Color(0xFF1565C0) 
              : (isDark ? const Color(0xFF1E1E1E) : Colors.white),
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(18),
            topRight: const Radius.circular(18),
            bottomLeft: Radius.circular(isUser ? 18 : 4),
            bottomRight: Radius.circular(isUser ? 4 : 18),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(isDark ? 0.15 : 0.05),
              blurRadius: 6,
              offset: const Offset(0, 2),
            )
          ],
        ),
        child: Text(
          msg['text'] ?? '',
          style: TextStyle(
            color: isUser ? Colors.white : (isDark ? Colors.white.withOpacity(0.9) : Colors.black87),
            fontSize: 15,
          ),
        ),
      ),
    );
  }

  Widget _buildInputBar(bool isDark) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.2 : 0.05),
            blurRadius: 8,
            offset: const Offset(0, -2),
          )
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _controller,
              maxLines: null,
              style: TextStyle(color: isDark ? Colors.white : Colors.black87),
              decoration: InputDecoration(
                hintText: 'Type your request...',
                hintStyle: TextStyle(color: isDark ? Colors.grey[500] : Colors.grey[600]),
                filled: true,
                fillColor: isDark ? const Color(0xFF2C2C2C) : const Color(0xFFF5F7FA),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
                contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              ),
              onSubmitted: (_) => _sendMessage(),
            ),
          ),
          const SizedBox(width: 10),
          GestureDetector(
            onTap: _sendMessage,
            child: Container(
              width: 48, height: 48,
              decoration: const BoxDecoration(color: Color(0xFF1565C0), shape: BoxShape.circle),
              child: const Icon(Icons.send, color: Colors.white, size: 22),
            ),
          ),
        ],
      ),
    );
  }
}
