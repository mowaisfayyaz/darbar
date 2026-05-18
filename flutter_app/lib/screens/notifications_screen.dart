import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:provider/provider.dart';
import '../services/theme_provider.dart';

class NotificationsScreen extends StatefulWidget {
  final String userId;
  final bool isProviderTheme;
  const NotificationsScreen({super.key, required this.userId, this.isProviderTheme = false});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  List<dynamic> _notifications = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchNotifications();
  }

  Future<void> _fetchNotifications() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final dio = Dio();
      final response = await dio.get('http://127.0.0.1:8000/api/notifications/${widget.userId}/');
      setState(() {
        _notifications = response.data;
        _isLoading = false;
      });
    } on DioException catch (e) {
      setState(() {
        _error = e.response?.data['error'] ?? 'Failed to load notifications.';
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Something went wrong: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _markAsRead(String id) async {
    try {
      final dio = Dio();
      await dio.post('http://127.0.0.1:8000/api/notifications/read/$id/');
      _fetchNotifications();
    } catch (e) {
      // Quiet fail
    }
  }

  @override
  Widget build(BuildContext context) {
    final appState = Provider.of<AppStateProvider>(context);
    final isDark = appState.isDarkMode;
    final primaryColor = widget.isProviderTheme ? Colors.green : const Color(0xFF1565C0);
    
    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF121212) : const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text('Notifications', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: primaryColor,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchNotifications,
          )
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _fetchNotifications,
        color: primaryColor,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? ListView(
                    padding: const EdgeInsets.all(24),
                    children: [
                      const SizedBox(height: 100),
                      const Icon(Icons.error_outline, size: 64, color: Colors.red),
                      const SizedBox(height: 16),
                      Text(
                        _error!,
                        textAlign: TextAlign.center,
                        style: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey, fontSize: 16),
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: primaryColor),
                        onPressed: _fetchNotifications,
                        child: const Text('Try Again'),
                      ),
                    ],
                  )
                : _notifications.isEmpty
                    ? ListView(
                        padding: const EdgeInsets.all(24),
                        children: [
                          const SizedBox(height: 100),
                          Container(
                            padding: const EdgeInsets.all(24),
                            decoration: BoxDecoration(
                              color: primaryColor.withOpacity(0.08),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(Icons.notifications_none_outlined, size: 64, color: primaryColor),
                          ),
                          const SizedBox(height: 24),
                          Text(
                            'All caught up!',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 20, 
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.white : Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Notifications about booking status, agent findings, and confirmation will appear here.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: isDark ? Colors.grey[400] : Colors.grey, 
                              fontSize: 15,
                            ),
                          ),
                        ],
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _notifications.length,
                        itemBuilder: (context, index) {
                          final n = _notifications[index];
                          final isRead = n['is_read'] ?? false;

                          return Card(
                            margin: const EdgeInsets.only(bottom: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            elevation: 1,
                            color: isRead 
                                ? (isDark ? const Color(0xFF1E1E1E) : Colors.white) 
                                : (widget.isProviderTheme 
                                    ? (isDark ? Colors.green.shade900.withOpacity(0.2) : Colors.green.shade50) 
                                    : (isDark ? const Color(0xFF1565C0).withOpacity(0.15) : const Color(0xFFE3F2FD))),
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: isRead ? Colors.grey[200] : primaryColor.withOpacity(0.12),
                                child: Icon(
                                  Icons.notifications,
                                  color: isRead ? Colors.grey : primaryColor,
                                ),
                              ),
                              title: Text(
                                n['title'] ?? 'Notification',
                                style: TextStyle(
                                  fontWeight: isRead ? FontWeight.normal : FontWeight.bold,
                                  fontSize: 16,
                                  color: isDark ? Colors.white : Colors.black87,
                                ),
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const SizedBox(height: 4),
                                  Text(
                                    n['body'] ?? '',
                                    style: TextStyle(color: isDark ? Colors.white70 : Colors.black87),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    n['created_at'].toString().substring(0, 16),
                                    style: const TextStyle(fontSize: 10, color: Colors.grey),
                                  ),
                                ],
                              ),
                              onTap: isRead ? null : () => _markAsRead(n['id']),
                            ),
                          );
                        },
                      ),
      ),
    );
  }
}
