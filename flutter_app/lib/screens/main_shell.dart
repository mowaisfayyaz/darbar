import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/theme_provider.dart';
import 'home_screen.dart';
import 'bookings_screen.dart';
import 'notifications_screen.dart';
import 'settings_screen.dart';

class MainShell extends StatefulWidget {
  final String userId;
  final String userName;
  const MainShell({super.key, required this.userId, required this.userName});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _currentIndex = 0;

  late final List<Widget> _pages;

  @override
  void initState() {
    super.initState();
    _pages = [
      HomeScreen(userId: widget.userId, userName: widget.userName),
      BookingsScreen(userId: widget.userId),
      NotificationsScreen(userId: widget.userId),
      SettingsScreen(userId: widget.userId, userName: widget.userName),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final appState = Provider.of<AppStateProvider>(context);
    final isDark = appState.isDarkMode;

    return Scaffold(
      body: IndexedStack(index: _currentIndex, children: _pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (i) => setState(() => _currentIndex = i),
        backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        elevation: 8,
        indicatorColor: isDark ? const Color(0xFF1565C0).withOpacity(0.3) : const Color(0xFF1565C0).withOpacity(0.1),
        destinations: [
          NavigationDestination(
            icon: Icon(Icons.chat_bubble_outline, color: isDark ? Colors.white70 : Colors.black87),
            selectedIcon: const Icon(Icons.chat_bubble, color: Color(0xFF1565C0)),
            label: 'Agent',
          ),
          NavigationDestination(
            icon: Icon(Icons.bookmark_border, color: isDark ? Colors.white70 : Colors.black87),
            selectedIcon: const Icon(Icons.bookmark, color: Color(0xFF1565C0)),
            label: 'Bookings',
          ),
          NavigationDestination(
            icon: Icon(Icons.notifications_outlined, color: isDark ? Colors.white70 : Colors.black87),
            selectedIcon: const Icon(Icons.notifications, color: Color(0xFF1565C0)),
            label: 'Alerts',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined, color: isDark ? Colors.white70 : Colors.black87),
            selectedIcon: const Icon(Icons.settings, color: Color(0xFF1565C0)),
            label: 'Settings',
          ),
        ],
      ),
    );
  }
}
