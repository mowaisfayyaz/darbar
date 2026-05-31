import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/api_service.dart';
import '../services/theme_provider.dart';
import 'login_screen.dart';
import 'app_drawer.dart';

class SettingsScreen extends StatefulWidget {
  final String userId;
  final String userName;
  final bool isProviderTheme;
  const SettingsScreen({super.key, required this.userId, required this.userName, this.isProviderTheme = false});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _pushNotifications = true;
  bool _smsAlerts = true;
  bool _googleLinked = false;
  String? _googleEmail;
  bool _loadingGoogle = true;
  final _api = ApiService();

  bool _apifyEnabledByAdmin = false;
  bool _apifyEnabledForUser = false;
  bool _loadingApify = true;

  @override
  void initState() {
    super.initState();
    _checkGoogleStatus();
    _loadApifySettings();
  }

  Future<void> _checkGoogleStatus() async {
    setState(() => _loadingGoogle = true);
    try {
      final role = widget.isProviderTheme ? 'provider' : 'customer';
      final data = await _api.getGoogleAuthStatus(userId: widget.userId, role: role);
      setState(() {
        _googleLinked = data['linked'] ?? false;
        _googleEmail = data['email'];
        _loadingGoogle = false;
      });
    } catch (e) {
      setState(() => _loadingGoogle = false);
    }
  }

  Future<void> _loadApifySettings() async {
    setState(() => _loadingApify = true);
    try {
      final role = widget.isProviderTheme ? 'provider' : 'customer';
      final config = await _api.getSystemConfig(userId: widget.userId, role: role);
      setState(() {
        _apifyEnabledByAdmin = config['apify_enabled_by_admin'] ?? false;
        _apifyEnabledForUser = config['user_apify_enabled'] ?? false;
        _loadingApify = false;
      });
    } catch (e) {
      setState(() => _loadingApify = false);
    }
  }

  Future<void> _toggleUserApifySetting(bool value) async {
    try {
      final role = widget.isProviderTheme ? 'provider' : 'customer';
      final res = await _api.updateUserApifySetting(
        userId: widget.userId,
        role: role,
        enabled: value,
      );
      setState(() {
        _apifyEnabledForUser = res['is_apify_enabled'] ?? value;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to update Apify setting.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _connectGoogle() async {
    try {
      final role = widget.isProviderTheme ? 'provider' : 'customer';
      final url = await _api.getGoogleAuthUrl(userId: widget.userId, role: role);
      if (url != null) {
        final uri = Uri.parse(url);
        await launchUrl(uri, mode: LaunchMode.externalApplication);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Opening Google OAuth in a new tab...'),
              backgroundColor: Colors.blue,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Google OAuth not configured yet. You can set it up later.'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    }
  }

  Future<void> _disconnectGoogle() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Disconnect Google'),
        content: const Text('Are you sure you want to disconnect your Google account from Darbar?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Disconnect'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _loadingGoogle = true);
    try {
      final role = widget.isProviderTheme ? 'provider' : 'customer';
      await _api.disconnectGoogle(userId: widget.userId, role: role);
      setState(() {
        _googleLinked = false;
        _googleEmail = null;
        _loadingGoogle = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Google account disconnected successfully.'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      setState(() => _loadingGoogle = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to disconnect Google: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _logout() {
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
              Navigator.pop(context);
              final appState = Provider.of<AppStateProvider>(context, listen: false);
              await appState.clearSession();
              if (mounted) {
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (context) => const LoginScreen()),
                  (route) => false,
                );
              }
            },
            child: const Text('Logout'),
          ),
        ],
      ),
    );
  }

  Future<void> _pickImage(AppStateProvider appState) async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 85,
      );
      
      if (image != null) {
        final bytes = await image.readAsBytes();
        appState.setCustomAvatarBytes(bytes);
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Success! Custom image uploaded as avatar.'),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to select image: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showAvatarSelector(AppStateProvider appState, Color primaryColor) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        final isDark = appState.isDarkMode;
        return Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Choose Avatar',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  if (appState.customAvatarBytes != null)
                    TextButton(
                      onPressed: () {
                        appState.clearCustomAvatar();
                        Navigator.pop(context);
                      },
                      child: const Text('Reset to Icon', style: TextStyle(color: Colors.red)),
                    ),
                ],
              ),
              const SizedBox(height: 18),
              
              // SECTION 1: PRE-BUILT ICON LIST
              const Text(
                'SELECT ICON AVATAR',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 1.1),
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 120,
                child: GridView.builder(
                  shrinkWrap: true,
                  physics: const ClampingScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 6,
                    crossAxisSpacing: 8,
                    mainAxisSpacing: 8,
                  ),
                  itemCount: appState.avatarIcons.length,
                  itemBuilder: (context, index) {
                    final icon = appState.avatarIcons[index];
                    final isSelected = appState.customAvatarBytes == null && appState.avatarIndex == index;
                    return GestureDetector(
                      onTap: () {
                        appState.changeAvatar(index);
                        Navigator.pop(context);
                      },
                      child: Container(
                        decoration: BoxDecoration(
                          color: isSelected 
                              ? primaryColor.withOpacity(0.12) 
                              : (isDark ? const Color(0xFF2C2C2C) : Colors.grey[100]),
                          border: Border.all(
                            color: isSelected ? primaryColor : Colors.transparent,
                            width: 2,
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Center(
                          child: Icon(
                            icon,
                            color: isSelected ? primaryColor : (isDark ? Colors.white70 : Colors.black54),
                            size: 28,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 20),
              
              // SECTION 2: UPLOAD IMAGE BUTTON
              const Text(
                'UPLOAD CUSTOM IMAGE',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 1.1),
              ),
              const SizedBox(height: 10),
              InkWell(
                onTap: () {
                  Navigator.pop(context);
                  _pickImage(appState);
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF2C2C2C) : const Color(0xFFF5F7FA),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: primaryColor.withOpacity(0.3), width: 1.5),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.cloud_upload_outlined, color: primaryColor),
                      const SizedBox(width: 10),
                      Text(
                        'Upload Custom Photo',
                        style: TextStyle(color: primaryColor, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final appState = Provider.of<AppStateProvider>(context);
    final isDark = appState.isDarkMode;
    final primaryColor = widget.isProviderTheme ? Colors.green : const Color(0xFF1565C0);

    Widget avatarWidget;
    if (appState.customAvatarBytes != null) {
      avatarWidget = CircleAvatar(
        radius: 36,
        backgroundImage: MemoryImage(appState.customAvatarBytes!),
      );
    } else {
      avatarWidget = CircleAvatar(
        radius: 36,
        backgroundColor: primaryColor.withOpacity(0.15),
        child: Center(
          child: Icon(
            appState.currentAvatarIcon,
            size: 36,
            color: primaryColor,
          ),
        ),
      );
    }

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
        title: const Text('Settings', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: primaryColor,
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 850),
          child: ListView(
            children: [
          const SizedBox(height: 20),
          
          // Profile Details Card
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(isDark ? 0.2 : 0.04),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                )
              ],
            ),
            child: Row(
              children: [
                GestureDetector(
                  onTap: () => _showAvatarSelector(appState, primaryColor),
                  child: Stack(
                    children: [
                      avatarWidget,
                      Positioned(
                        right: 0,
                        bottom: 0,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: primaryColor,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.edit,
                            size: 12,
                            color: Colors.white,
                          ),
                        ),
                      )
                    ],
                  ),
                ),
                const SizedBox(width: 18),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.userName,
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'User ID: ${widget.userId.substring(0, 8)}...',
                        style: const TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Tap photo to edit avatar',
                        style: TextStyle(fontSize: 11, color: primaryColor, fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 28),
          
          // PREFERENCES SECTION
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 24, vertical: 8),
            child: Text(
              'PREFERENCES',
              style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold, fontSize: 11, letterSpacing: 1.1),
            ),
          ),
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              children: [
                SwitchListTile(
                  value: _pushNotifications,
                  onChanged: (val) => setState(() => _pushNotifications = val),
                  title: const Text('Push Notifications'),
                  secondary: Icon(Icons.notifications_active_outlined, color: primaryColor),
                  activeColor: primaryColor,
                ),
                const Divider(height: 1),
                SwitchListTile(
                  value: _smsAlerts,
                  onChanged: (val) => setState(() => _smsAlerts = val),
                  title: const Text('SMS Reminders & Alerts'),
                  secondary: Icon(Icons.sms_outlined, color: primaryColor),
                  activeColor: primaryColor,
                ),
                const Divider(height: 1),
                SwitchListTile(
                  value: appState.isDarkMode,
                  onChanged: (val) => appState.toggleTheme(val),
                  title: const Text('Dark Mode'),
                  secondary: Icon(Icons.dark_mode_outlined, color: primaryColor),
                  activeColor: primaryColor,
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 28),

          // GOOGLE SERVICES SECTION
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 24, vertical: 8),
            child: Text(
              'GOOGLE SERVICES INTEGRATION',
              style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold, fontSize: 11, letterSpacing: 1.1),
            ),
          ),
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
              borderRadius: BorderRadius.circular(20),
            ),
            child: _loadingGoogle
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.all(16.0),
                      child: CircularProgressIndicator(),
                    ),
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: _googleLinked ? Colors.green.withOpacity(0.1) : primaryColor.withOpacity(0.1),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              _googleLinked ? Icons.mark_email_read_outlined : Icons.mail_outline_rounded,
                              color: _googleLinked ? Colors.green : primaryColor,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Gmail Dispatch Authorization',
                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  _googleLinked 
                                      ? 'Linked: $_googleEmail' 
                                      : 'Not connected. Link to dispatch live email confirmations.',
                                  style: TextStyle(
                                    fontSize: 12, 
                                    color: _googleLinked ? Colors.green : Colors.grey,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _googleLinked ? Colors.red.withOpacity(0.1) : primaryColor,
                            foregroundColor: _googleLinked ? Colors.red : Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          onPressed: _googleLinked ? _disconnectGoogle : _connectGoogle,
                          child: Text(
                            _googleLinked ? 'Disconnect Google Account' : 'Connect Google Account',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                      if (!_googleLinked) ...[
                        const SizedBox(height: 8),
                        Center(
                          child: TextButton.icon(
                            onPressed: _checkGoogleStatus,
                            icon: const Icon(Icons.refresh, size: 14),
                            label: const Text('Refresh Link Status', style: TextStyle(fontSize: 12)),
                          ),
                        ),
                      ],
                    ],
                  ),
          ),
          
          if (_apifyEnabledByAdmin) ...[
            const SizedBox(height: 28),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 24, vertical: 8),
              child: Text(
                'APIFY SEARCH INTEGRATION',
                style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold, fontSize: 11, letterSpacing: 1.1),
              ),
            ),
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                borderRadius: BorderRadius.circular(20),
              ),
              child: _loadingApify
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.all(16.0),
                        child: CircularProgressIndicator(),
                      ),
                    )
                  : SwitchListTile(
                      value: _apifyEnabledForUser,
                      onChanged: (val) => _toggleUserApifySetting(val),
                      title: const Text(
                        'Apify Google Maps Data Search',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                      ),
                      subtitle: const Text(
                        'Enable background scraping using Apify for highly accurate local recommendations.',
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                      secondary: Icon(Icons.api_outlined, color: primaryColor),
                      activeColor: primaryColor,
                      contentPadding: EdgeInsets.zero,
                    ),
            ),
          ],
          
          const SizedBox(height: 28),
          
          // ACCOUNT ACTIONS SECTION
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 24, vertical: 8),
            child: Text(
              'ACCOUNT ACTIONS',
              style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold, fontSize: 11, letterSpacing: 1.1),
            ),
          ),
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              children: [
                ListTile(
                  leading: Icon(Icons.person_outline, color: primaryColor),
                  title: const Text('Edit Profile Details'),
                  trailing: const Icon(Icons.chevron_right, color: Colors.grey),
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Profile edit is placeholder for Hackathon demo.')),
                    );
                  },
                ),
                const Divider(height: 1),
                ListTile(
                  leading: Icon(Icons.help_outline, color: primaryColor),
                  title: const Text('Help & Support'),
                  trailing: const Icon(Icons.chevron_right, color: Colors.grey),
                  onTap: () {},
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.logout, color: Colors.red),
                  title: const Text('Logout', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                  onTap: _logout,
                ),
              ],
            ),
          ),
          const SizedBox(height: 40),
          const Center(
            child: Text('Darbar v1.0.0 (Hackathon Build)', style: TextStyle(color: Colors.grey, fontSize: 12)),
          ),
          const SizedBox(height: 20),
        ],
      ),
          ),
        ),
    );
  }
}
