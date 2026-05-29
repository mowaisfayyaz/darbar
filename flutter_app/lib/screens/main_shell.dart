import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/theme_provider.dart';
import 'home_screen.dart';
import 'bookings_screen.dart';
import 'notifications_screen.dart';
import 'settings_screen.dart';
import 'app_drawer.dart';

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
    final primaryColor = const Color(0xFF1565C0);

    return Scaffold(
      drawer: const AppDrawer(isProviderTheme: false),
      body: IndexedStack(index: _currentIndex, children: _pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (i) => setState(() => _currentIndex = i),
        backgroundColor: isDark ? const Color(0xFF1A1A1A) : Colors.white,
        elevation: 8,
        indicatorColor: isDark ? primaryColor.withOpacity(0.2) : const Color(0xFFE3F2FD),
        animationDuration: const Duration(milliseconds: 300),
        destinations: [
          NavigationDestination(
            icon: Icon(Icons.chat_outlined, color: isDark ? Colors.white70 : Colors.black87),
            selectedIcon: Icon(Icons.chat, color: primaryColor),
            label: 'Agent',
          ),
          NavigationDestination(
            icon: Icon(Icons.calendar_today_outlined, color: isDark ? Colors.white70 : Colors.black87),
            selectedIcon: Icon(Icons.calendar_today, color: primaryColor),
            label: 'Bookings',
          ),
          NavigationDestination(
            icon: Icon(Icons.notifications_outlined, color: isDark ? Colors.white70 : Colors.black87),
            selectedIcon: Icon(Icons.notifications, color: primaryColor),
            label: 'Alerts',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined, color: isDark ? Colors.white70 : Colors.black87),
            selectedIcon: Icon(Icons.settings, color: primaryColor),
            label: 'Settings',
          ),
        ],
      ),
    );
  }
}
