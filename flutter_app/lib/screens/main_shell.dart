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
    final isDesktop = MediaQuery.of(context).size.width > 800;
    final primaryColor = const Color(0xFF1565C0);

    final rail = NavigationRail(
      groupAlignment: 0.0,
      selectedIndex: _currentIndex,
      onDestinationSelected: (i) => setState(() => _currentIndex = i),
      backgroundColor: isDark ? const Color(0xFF1A1A1A) : Colors.white,
      elevation: 8,
      indicatorColor: isDark ? primaryColor.withOpacity(0.2) : const Color(0xFFE3F2FD),
      labelType: NavigationRailLabelType.all,
      selectedLabelTextStyle: TextStyle(color: primaryColor, fontWeight: FontWeight.bold, fontSize: 13),
      unselectedLabelTextStyle: TextStyle(color: isDark ? Colors.white70 : Colors.black87, fontSize: 12),
      destinations: [
        NavigationRailDestination(
          icon: Icon(Icons.chat_outlined, color: isDark ? Colors.white70 : Colors.black87),
          selectedIcon: Icon(Icons.chat, color: primaryColor),
          label: const Text('Agent'),
        ),
        NavigationRailDestination(
          icon: Icon(Icons.calendar_today_outlined, color: isDark ? Colors.white70 : Colors.black87),
          selectedIcon: Icon(Icons.calendar_today, color: primaryColor),
          label: const Text('Bookings'),
        ),
        NavigationRailDestination(
          icon: Icon(Icons.notifications_outlined, color: isDark ? Colors.white70 : Colors.black87),
          selectedIcon: Icon(Icons.notifications, color: primaryColor),
          label: const Text('Alerts'),
        ),
        NavigationRailDestination(
          icon: Icon(Icons.settings_outlined, color: isDark ? Colors.white70 : Colors.black87),
          selectedIcon: Icon(Icons.settings, color: primaryColor),
          label: const Text('Settings'),
        ),
      ],
    );

    return Scaffold(
      drawer: const AppDrawer(isProviderTheme: false),
      body: isDesktop
          ? Row(
              children: [
                rail,
                const VerticalDivider(width: 1, thickness: 1),
                Expanded(
                  child: IndexedStack(index: _currentIndex, children: _pages),
                ),
              ],
            )
          : IndexedStack(index: _currentIndex, children: _pages),
      bottomNavigationBar: isDesktop
          ? null
          : NavigationBar(
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
