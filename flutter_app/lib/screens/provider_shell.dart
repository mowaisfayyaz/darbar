import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/theme_provider.dart';
import 'provider_dashboard.dart';
import 'notifications_screen.dart';
import 'settings_screen.dart';

class ProviderShell extends StatefulWidget {
  final String providerId;
  final String providerName;
  const ProviderShell({super.key, required this.providerId, required this.providerName});

  @override
  State<ProviderShell> createState() => _ProviderShellState();
}

class _ProviderShellState extends State<ProviderShell> {
  int _currentIndex = 0;

  late final List<Widget> _pages;

  @override
  void initState() {
    super.initState();
    _pages = [
      const ProviderDashboard(),
      NotificationsScreen(userId: widget.providerId, isProviderTheme: true),
      SettingsScreen(userId: widget.providerId, userName: widget.providerName, isProviderTheme: true),
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
        indicatorColor: isDark ? Colors.green.shade900.withOpacity(0.4) : Colors.green.shade100,
        destinations: [
          NavigationDestination(
            icon: Icon(Icons.work_outline, color: isDark ? Colors.white70 : Colors.black87),
            selectedIcon: const Icon(Icons.work, color: Colors.green),
            label: 'Requests',
          ),
          NavigationDestination(
            icon: Icon(Icons.notifications_outlined, color: isDark ? Colors.white70 : Colors.black87),
            selectedIcon: const Icon(Icons.notifications, color: Colors.green),
            label: 'Alerts',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined, color: isDark ? Colors.white70 : Colors.black87),
            selectedIcon: const Icon(Icons.settings, color: Colors.green),
            label: 'Settings',
          ),
        ],
      ),
    );
  }
}
