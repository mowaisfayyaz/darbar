import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/api_service.dart';
import '../services/theme_provider.dart';
import 'app_drawer.dart';

class NotificationsScreen extends StatefulWidget {
  final String userId;
  final bool isProviderTheme;
  const NotificationsScreen({super.key, required this.userId, this.isProviderTheme = false});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final ApiService _api = ApiService();
  List<dynamic> _notifications = [];
  bool _isLoading = true;
  String? _error;
  Timer? _pollTimer;

  @override
  void initState() {
    super.initState();
    _fetchNotifications();
    // Auto-refresh every 15 seconds
    _pollTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      _silentRefresh();
    });
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  /// Silent refresh without showing loading indicator
  Future<void> _silentRefresh() async {
    try {
      final data = await _api.getNotifications(widget.userId);
      if (mounted) {
        setState(() {
          _notifications = data;
        });
      }
    } catch (_) {}
  }

  Future<void> _fetchNotifications() async {
    setState(() { _isLoading = true; _error = null; });
    try {
      final data = await _api.getNotifications(widget.userId);
      if (mounted) {
        setState(() {
          _notifications = data;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Failed to load notifications.';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _markAsRead(String id) async {
    try {
      await _api.markNotificationRead(id);
      _fetchNotifications();
    } catch (_) {}
  }

  Future<void> _dismissNotification(int index) async {
    final removed = _notifications[index];
    setState(() => _notifications.removeAt(index));
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Notification dismissed'),
        action: SnackBarAction(
          label: 'Undo',
          onPressed: () {
            setState(() => _notifications.insert(index, removed));
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final appState = Provider.of<AppStateProvider>(context);
    final isDark = appState.isDarkMode;
    final primaryColor = widget.isProviderTheme ? Colors.green : const Color(0xFF1565C0);
    
    return Scaffold(
      drawer: AppDrawer(isProviderTheme: widget.isProviderTheme),
      backgroundColor: isDark ? const Color(0xFF121212) : const Color(0xFFF5F7FA),
      appBar: AppBar(
        leading: Builder(
          builder: (context) => IconButton(
            icon: const Icon(Icons.menu),
            onPressed: () => Scaffold.of(context).openDrawer(),
          ),
        ),
        title: const Text('Notifications', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _fetchNotifications),
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
                      Text(_error!, textAlign: TextAlign.center, style: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey, fontSize: 16)),
                      const SizedBox(height: 24),
                      Center(child: ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: primaryColor),
                        onPressed: _fetchNotifications,
                        child: const Text('Try Again'),
                      )),
                    ],
                  )
                : _notifications.isEmpty
                    ? ListView(
                        padding: const EdgeInsets.all(24),
                        children: [
                          const SizedBox(height: 80),
                          Container(
                            padding: const EdgeInsets.all(28),
                            decoration: BoxDecoration(
                              color: primaryColor.withOpacity(isDark ? 0.12 : 0.08),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(Icons.notifications_none_outlined, size: 56, color: primaryColor),
                          ),
                          const SizedBox(height: 24),
                          Text(
                            'All caught up! 🎉',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Notifications about booking status, agent findings, and confirmations will appear here.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey, fontSize: 14, height: 1.4),
                          ),
                        ],
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _notifications.length,
                        itemBuilder: (context, index) {
                          final n = _notifications[index];
                          final isRead = n['is_read'] ?? false;

                          return Dismissible(
                            key: Key(n['id'] ?? index.toString()),
                            direction: DismissDirection.endToStart,
                            onDismissed: (_) => _dismissNotification(index),
                            background: Container(
                              alignment: Alignment.centerRight,
                              padding: const EdgeInsets.only(right: 20),
                              margin: const EdgeInsets.only(bottom: 12),
                              decoration: BoxDecoration(
                                color: Colors.red.shade400,
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: const Icon(Icons.delete_outline, color: Colors.white),
                            ),
                            child: Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(16),
                                color: isRead 
                                    ? (isDark ? const Color(0xFF1E1E1E) : Colors.white) 
                                    : (widget.isProviderTheme 
                                        ? (isDark ? Colors.green.shade900.withOpacity(0.2) : Colors.green.shade50) 
                                        : (isDark ? const Color(0xFF1565C0).withOpacity(0.12) : const Color(0xFFE3F2FD))),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(isDark ? 0.12 : 0.04),
                                    blurRadius: 6,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: ListTile(
                                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                leading: CircleAvatar(
                                  backgroundColor: isRead ? (isDark ? Colors.grey[800] : Colors.grey[200]) : primaryColor.withOpacity(0.12),
                                  child: Icon(
                                    _getNotificationIcon(n['title'] ?? ''),
                                    color: isRead ? Colors.grey : primaryColor,
                                    size: 22,
                                  ),
                                ),
                                title: Text(
                                  n['title'] ?? 'Notification',
                                  style: TextStyle(
                                    fontWeight: isRead ? FontWeight.normal : FontWeight.bold,
                                    fontSize: 15,
                                    color: isDark ? Colors.white : Colors.black87,
                                  ),
                                ),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const SizedBox(height: 4),
                                    Text(
                                      n['body'] ?? '',
                                      style: TextStyle(
                                        color: isDark ? Colors.white70 : Colors.black87,
                                        fontSize: 13,
                                        height: 1.3,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      _formatTimestamp(n['created_at']?.toString() ?? ''),
                                      style: TextStyle(fontSize: 11, color: isDark ? Colors.grey[600] : Colors.grey),
                                    ),
                                  ],
                                ),
                                onTap: isRead ? null : () => _markAsRead(n['id']),
                              ),
                            ),
                          );
                        },
                      ),
      ),
    );
  }

  IconData _getNotificationIcon(String title) {
    if (title.contains('Confirmed') || title.contains('🎉')) return Icons.check_circle;
    if (title.contains('Request')) return Icons.send;
    if (title.contains('Update')) return Icons.update;
    if (title.contains('Cancelled') || title.contains('Declined')) return Icons.cancel;
    return Icons.notifications;
  }

  String _formatTimestamp(String timestamp) {
    if (timestamp.length < 16) return timestamp;
    try {
      final dt = DateTime.parse(timestamp);
      final now = DateTime.now();
      final diff = now.difference(dt);
      if (diff.inMinutes < 1) return 'Just now';
      if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
      if (diff.inHours < 24) return '${diff.inHours}h ago';
      if (diff.inDays < 7) return '${diff.inDays}d ago';
      return '${dt.day}/${dt.month}/${dt.year}';
    } catch (_) {
      return timestamp.substring(0, 16);
    }
  }
}
