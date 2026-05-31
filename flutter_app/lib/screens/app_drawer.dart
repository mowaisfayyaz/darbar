import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'info_screens.dart';
import 'login_screen.dart';
import '../services/theme_provider.dart';

class AppDrawer extends StatelessWidget {
  final bool isProviderTheme;
  const AppDrawer({super.key, this.isProviderTheme = false});

  @override
  Widget build(BuildContext context) {
    final themeColor = isProviderTheme ? Colors.green : const Color(0xFF1565C0);
    final headerGradient = isProviderTheme
        ? LinearGradient(colors: [Colors.green.shade700, Colors.green.shade500])
        : const LinearGradient(colors: [Color(0xFF0D47A1), Color(0xFF1976D2)]);

    return Drawer(
      child: Column(
        children: [
          // Drawer Header
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
            decoration: BoxDecoration(
              gradient: headerGradient,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                const CircleAvatar(
                  radius: 36,
                  backgroundColor: Colors.white24,
                  child: Icon(Icons.music_note, color: Colors.white, size: 40),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Darbar Orchestra',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  isProviderTheme ? 'Service Partner Portal' : 'Smart Service Orchestration',
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),

          // Menu Items
          _buildDrawerItem(
            context,
            icon: Icons.info_outline,
            label: 'About Us',
            color: themeColor,
            destination: AboutUsScreen(themeColor: themeColor),
          ),
          _buildDrawerItem(
            context,
            icon: Icons.contact_support_outlined,
            label: 'Contact Us',
            color: themeColor,
            destination: ContactUsScreen(themeColor: themeColor),
          ),
          _buildDrawerItem(
            context,
            icon: Icons.help_outline_outlined,
            label: 'FAQ & Support',
            color: themeColor,
            destination: FaqScreen(themeColor: themeColor),
          ),

          const Divider(),
          ListTile(
            leading: const Icon(Icons.logout, color: Colors.red),
            title: const Text(
              'Logout',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: Colors.red,
              ),
            ),
            trailing: const Icon(Icons.chevron_right, size: 18, color: Colors.red),
            onTap: () {
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Logout'),
                  content: const Text('Are you sure you want to sign out of Darbar?'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Cancel'),
                    ),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                      onPressed: () async {
                        Navigator.pop(context); // Close dialog
                        Navigator.pop(context); // Close drawer
                        final appState = Provider.of<AppStateProvider>(context, listen: false);
                        await appState.clearSession();
                        Navigator.pushAndRemoveUntil(
                          context,
                          MaterialPageRoute(builder: (context) => const LoginScreen()),
                          (route) => false,
                        );
                      },
                      child: const Text('Logout'),
                    ),
                  ],
                ),
              );
            },
          ),

          const Spacer(),
          // Footer
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(
              'v1.2.0 • Powered by Darbar',
              style: TextStyle(color: Colors.grey.shade500, fontSize: 11),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDrawerItem(
    BuildContext context, {
    required IconData icon,
    required String label,
    required Color color,
    required Widget destination,
  }) {
    return ListTile(
      leading: Icon(icon, color: color),
      title: Text(
        label,
        style: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w600,
        ),
      ),
      trailing: const Icon(Icons.chevron_right, size: 18),
      onTap: () {
        Navigator.pop(context); // Close drawer
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => destination),
        );
      },
    );
  }
}
