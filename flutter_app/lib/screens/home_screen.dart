import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/api_service.dart';
import '../services/theme_provider.dart';
import 'processing_screen.dart';

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
  final ApiService _api = ApiService();

  // Multi-turn context tracking
  String? _pendingService;
  String? _pendingLocation;
  String? _pendingTime;

  void _sendMessage() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _isTyping) return;

    final now = TimeOfDay.now();
    final timeStr = '${now.hourOfPeriod == 0 ? 12 : now.hourOfPeriod}:${now.minute.toString().padLeft(2, '0')} ${now.period == DayPeriod.am ? 'AM' : 'PM'}';
    setState(() {
      _messages.add({'role': 'user', 'text': text, 'time': timeStr});
      _isTyping = true;
    });
    _controller.clear();
    _scrollToBottom();

    try {
      final data = await _api.submitRequest(
        userId: widget.userId ?? '',
        text: text,
      );
      
      if (!mounted) return;

      setState(() => _isTyping = false);

      if (data['status'] == 'clarification') {
        // Track partial intent from clarification responses
        final intent = data['intent'];
        if (intent != null) {
          _pendingService ??= intent['service_type'];
          _pendingLocation ??= intent['location'];
          _pendingTime ??= intent['time_preference'];
        }

        final agentTime = TimeOfDay.now();
        final agentTimeStr = '${agentTime.hourOfPeriod == 0 ? 12 : agentTime.hourOfPeriod}:${agentTime.minute.toString().padLeft(2, '0')} ${agentTime.period == DayPeriod.am ? 'AM' : 'PM'}';
        setState(() {
          _messages.add({'role': 'agent', 'text': data['message'], 'time': agentTimeStr});
        });
        _scrollToBottom();
      } else if (data['status'] == 'processing') {
        setState(() {
          _messages.add({
            'role': 'agent', 
            'text': '✅ Match found! Navigating to booking details...'
          });
        });
        _scrollToBottom();

        // Clear context on successful booking
        _pendingService = null;
        _pendingLocation = null;
        _pendingTime = null;

        // Navigate to the processing screen with real data
        await Future.delayed(const Duration(milliseconds: 600));
        if (mounted) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ProcessingScreen(
                bookingData: {
                  'booking_id': data['booking_id'],
                  'human_booking_id': data['human_booking_id'],
                  'provider_name': data['provider_name'],
                  'provider_rating': data['provider_rating'],
                  'provider_phone': data['provider_phone'],
                  'provider_area': data['provider_area'],
                  'provider_reviews': data['provider_reviews'],
                  'service_type': data['service_type'],
                  'location': data['location'],
                  'message': data['message'],
                },
              ),
            ),
          );
        }
      } else {
        setState(() {
          _messages.add({'role': 'agent', 'text': data['reason'] ?? 'Could not process your request.'});
        });
        _scrollToBottom();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isTyping = false;
          _messages.add({
            'role': 'agent',
            'text': '⚠️ Connection error. Please make sure the backend server is running on port 8000.'
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
          duration: const Duration(milliseconds: 300),
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
            Text('Hello, ${widget.userName ?? 'User'}', style: TextStyle(fontSize: 12, color: Colors.white.withOpacity(0.7))),
          ],
        ),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 12),
            child: appState.customAvatarBytes != null
                ? CircleAvatar(backgroundImage: MemoryImage(appState.customAvatarBytes!))
                : CircleAvatar(
                    backgroundColor: Colors.white24,
                    child: Icon(appState.currentAvatarIcon, color: Colors.white, size: 20),
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
          if (_isTyping) _buildTypingIndicator(isDark),
          _buildInputBar(isDark),
        ],
      ),
    );
  }

  Widget _buildTypingIndicator(bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFF1565C0).withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const SizedBox(
              width: 14, height: 14,
              child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF1565C0)),
            ),
          ),
          const SizedBox(width: 10),
          Text(
            'Agent is processing your request...',
            style: TextStyle(fontSize: 12, color: isDark ? Colors.grey[400] : Colors.grey[600], fontStyle: FontStyle.italic),
          ),
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
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    const Color(0xFF1565C0).withOpacity(isDark ? 0.2 : 0.1),
                    const Color(0xFF1976D2).withOpacity(isDark ? 0.1 : 0.05),
                  ],
                ),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.smart_toy_outlined, size: 56, color: Color(0xFF1565C0)),
            ),
            const SizedBox(height: 24),
            Text(
              'Your AI Booking Agent',
              style: TextStyle(
                fontSize: 22,
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
                style: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[600], fontSize: 14, height: 1.4),
              ),
            ),
            const SizedBox(height: 32),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 8,
              runSpacing: 8,
              children: [
                _suggestionChip('👋 Hi', isDark),
                _suggestionChip('What can you do?', isDark),
                _suggestionChip('AC technician G-13 abhi', isDark),
                _suggestionChip('Plumber chahiye E-11', isDark),
              ],
            ),
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
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFF1565C0).withOpacity(isDark ? 0.4 : 0.25)),
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
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.78),
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
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              msg['text'] ?? '',
              style: TextStyle(
                color: isUser ? Colors.white : (isDark ? Colors.white.withOpacity(0.9) : Colors.black87),
                fontSize: 15,
                height: 1.4,
              ),
            ),
            if (msg['time'] != null) ...[
              const SizedBox(height: 4),
              Text(
                msg['time']!,
                style: TextStyle(
                  fontSize: 10,
                  color: isUser ? Colors.white.withOpacity(0.6) : (isDark ? Colors.grey[600] : Colors.grey[400]),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildInputBar(bool isDark) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A1A1A) : Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.25 : 0.06),
            blurRadius: 10,
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
                hintText: 'Describe the service you need...',
                hintStyle: TextStyle(color: isDark ? Colors.grey[500] : Colors.grey[500]),
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
            onTap: _isTyping ? null : _sendMessage,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 48, height: 48,
              decoration: BoxDecoration(
                color: _isTyping ? Colors.grey : const Color(0xFF1565C0),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.send_rounded, color: Colors.white, size: 22),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    _scroll.dispose();
    super.dispose();
  }
}
