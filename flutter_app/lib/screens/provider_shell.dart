import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/theme_provider.dart';
import 'provider_dashboard.dart';
import 'notifications_screen.dart';
import 'settings_screen.dart';
import 'provider_profile_screen.dart';
import 'app_drawer.dart';

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
      ProviderDashboard(providerId: widget.providerId, providerName: widget.providerName),
      NotificationsScreen(userId: widget.providerId, isProviderTheme: true),
      ProviderProfileScreen(providerId: widget.providerId, isEditable: true),
      SettingsScreen(userId: widget.providerId, userName: widget.providerName, isProviderTheme: true),
    ];
  }

  @override
  Widget build(BuildContext context) {
     final appState = Provider.of<AppStateProvider>(context);
     final isDark = appState.isDarkMode;
     final isDesktop = MediaQuery.of(context).size.width > 800;

     final rail = NavigationRail(
       groupAlignment: 0.0,
       selectedIndex: _currentIndex,
       onDestinationSelected: (i) => setState(() => _currentIndex = i),
       backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
       elevation: 8,
       indicatorColor: isDark ? Colors.green.shade900.withOpacity(0.4) : Colors.green.shade100,
       labelType: NavigationRailLabelType.all,
       selectedLabelTextStyle: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 13),
       unselectedLabelTextStyle: TextStyle(color: isDark ? Colors.white70 : Colors.black87, fontSize: 12),
       destinations: [
         NavigationRailDestination(
           icon: Icon(Icons.work_outline, color: isDark ? Colors.white70 : Colors.black87),
           selectedIcon: const Icon(Icons.work, color: Colors.green),
           label: const Text('Requests'),
         ),
         NavigationRailDestination(
           icon: Icon(Icons.notifications_outlined, color: isDark ? Colors.white70 : Colors.black87),
           selectedIcon: const Icon(Icons.notifications, color: Colors.green),
           label: const Text('Alerts'),
         ),
         NavigationRailDestination(
           icon: Icon(Icons.person_outline, color: isDark ? Colors.white70 : Colors.black87),
           selectedIcon: const Icon(Icons.person, color: Colors.green),
           label: const Text('Profile'),
         ),
         NavigationRailDestination(
           icon: Icon(Icons.settings_outlined, color: isDark ? Colors.white70 : Colors.black87),
           selectedIcon: const Icon(Icons.settings, color: Colors.green),
           label: const Text('Settings'),
         ),
       ],
     );

     return Scaffold(
       drawer: const AppDrawer(isProviderTheme: true),
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
                   icon: Icon(Icons.person_outline, color: isDark ? Colors.white70 : Colors.black87),
                   selectedIcon: const Icon(Icons.person, color: Colors.green),
                   label: 'Profile',
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
