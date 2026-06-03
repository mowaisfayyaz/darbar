import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/api_service.dart';
import '../services/theme_provider.dart';
import 'login_screen.dart';

class AdminPanelScreen extends StatefulWidget {
  final String adminId;
  final String adminName;
  const AdminPanelScreen({super.key, required this.adminId, required this.adminName});

  @override
  State<AdminPanelScreen> createState() => _AdminPanelScreenState();
}

class _AdminPanelScreenState extends State<AdminPanelScreen> {
  final _api = ApiService();
  bool _isLoading = true;
  String? _error;

  int _customerCount = 0;
  int _providerCount = 0;
  bool _apifyEnabledByAdmin = true;

  List<dynamic> _customers = [];
  List<dynamic> _providers = [];
  List<dynamic> _filteredCustomers = [];
  List<dynamic> _filteredProviders = [];

  final _customerSearchController = TextEditingController();
  final _providerSearchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _customerSearchController.addListener(_filterCustomers);
    _providerSearchController.addListener(_filterProviders);
    _fetchStats();
  }

  @override
  void dispose() {
    _customerSearchController.dispose();
    _providerSearchController.dispose();
    super.dispose();
  }

  Future<void> _fetchStats() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final stats = await _api.getAdminStats();
      final usersRes = await _api.getAdminUsers();
      setState(() {
        _customerCount = stats['customer_count'] ?? 0;
        _providerCount = stats['provider_count'] ?? 0;
        _apifyEnabledByAdmin = stats['apify_enabled_by_admin'] ?? true;

        _customers = usersRes['customers'] ?? [];
        _providers = usersRes['providers'] ?? [];

        _filterCustomers();
        _filterProviders();

        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to load admin data. Please try again.';
        _isLoading = false;
      });
    }
  }

  void _filterCustomers() {
    final query = _customerSearchController.text.toLowerCase();
    setState(() {
      _filteredCustomers = _customers.where((c) {
        final name = (c['name'] ?? '').toLowerCase();
        final email = (c['email'] ?? '').toLowerCase();
        final phone = (c['phone'] ?? '').toLowerCase();
        final location = (c['location'] ?? '').toLowerCase();
        return name.contains(query) || email.contains(query) || phone.contains(query) || location.contains(query);
      }).toList();
    });
  }

  void _filterProviders() {
    final query = _providerSearchController.text.toLowerCase();
    setState(() {
      _filteredProviders = _providers.where((p) {
        final name = (p['name'] ?? '').toLowerCase();
        final email = (p['email'] ?? '').toLowerCase();
        final phone = (p['phone'] ?? '').toLowerCase();
        final category = (p['category'] ?? '').toLowerCase();
        final city = (p['city'] ?? '').toLowerCase();
        final area = (p['area'] ?? '').toLowerCase();
        return name.contains(query) ||
            email.contains(query) ||
            phone.contains(query) ||
            category.contains(query) ||
            city.contains(query) ||
            area.contains(query);
      }).toList();
    });
  }

  Future<void> _toggleApify() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final res = await _api.toggleApifyGlobally();
      setState(() {
        _apifyEnabledByAdmin = res['apify_enabled_by_admin'] ?? !_apifyEnabledByAdmin;
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _apifyEnabledByAdmin
                  ? 'Apify API Integration enabled globally.'
                  : 'Apify API Integration disabled globally.',
            ),
            backgroundColor: Colors.blue,
          ),
        );
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to update Apify API Integration setting.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _deleteUser(String id, String role, String name) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Delete'),
        content: Text('Are you sure you want to delete the $role "$name"? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      setState(() => _isLoading = true);
      try {
        await _api.adminDeleteUser(id, role);
        await _fetchStats();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('$role deleted successfully.')),
          );
        }
      } catch (e) {
        setState(() => _isLoading = false);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to delete. Please try again.'), backgroundColor: Colors.red),
          );
        }
      }
    }
  }

  void _showCustomerDialog({Map<String, dynamic>? customer}) {
    final isEdit = customer != null;
    final nameController = TextEditingController(text: isEdit ? customer['name'] : '');
    final emailController = TextEditingController(text: isEdit ? customer['email'] : '');
    final phoneController = TextEditingController(text: isEdit ? customer['phone'] : '');
    final passwordController = TextEditingController();
    final locationController = TextEditingController(text: isEdit ? customer['location'] : '');

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        title: Text(isEdit ? 'Edit Customer' : 'Add New Customer'),
        content: SizedBox(
          width: MediaQuery.of(context).size.width > 480 ? 440 : MediaQuery.of(context).size.width * 0.9,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(labelText: 'Name *'),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: emailController,
                  decoration: const InputDecoration(labelText: 'Email'),
                  keyboardType: TextInputType.emailAddress,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: phoneController,
                  decoration: const InputDecoration(labelText: 'Phone *'),
                  keyboardType: TextInputType.phone,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: passwordController,
                  obscureText: true,
                  decoration: InputDecoration(
                    labelText: isEdit ? 'New Password (leave blank to keep)' : 'Password *',
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: locationController,
                  decoration: const InputDecoration(labelText: 'Location'),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final name = nameController.text.trim();
              final phone = phoneController.text.trim();
              final password = passwordController.text.trim();

              if (name.isEmpty || phone.isEmpty || (!isEdit && password.isEmpty)) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Name, Phone and Password are required.')),
                );
                return;
              }

              Navigator.pop(context);
              setState(() => _isLoading = true);

              try {
                final payload = {
                  'role': 'customer',
                  'name': name,
                  'email': emailController.text.trim(),
                  'phone': phone,
                  'password': password,
                  'location': locationController.text.trim(),
                };
                if (isEdit) {
                  payload['id'] = customer['id'];
                  await _api.adminUpdateUser(payload);
                } else {
                  await _api.adminCreateUser(payload);
                }
                await _fetchStats();
              } catch (e) {
                setState(() => _isLoading = false);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Error saving customer.'), backgroundColor: Colors.red),
                  );
                }
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showProviderDialog({Map<String, dynamic>? provider}) {
    final isEdit = provider != null;
    final nameController = TextEditingController(text: isEdit ? provider['name'] : '');
    final emailController = TextEditingController(text: isEdit ? provider['email'] : '');
    final phoneController = TextEditingController(text: isEdit ? provider['phone'] : '');
    final passwordController = TextEditingController();
    final categoryController = TextEditingController(text: isEdit ? provider['category'] : 'General');
    final cityController = TextEditingController(text: isEdit ? provider['city'] : 'Islamabad');
    final areaController = TextEditingController(text: isEdit ? provider['area'] : '');
    final websiteController = TextEditingController(text: isEdit ? provider['website'] : '');
    final ratingController = TextEditingController(text: isEdit ? provider['rating']?.toString() : '0.0');
    final reviewsController = TextEditingController(text: isEdit ? provider['review_count']?.toString() : '0');

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        title: Text(isEdit ? 'Edit Provider' : 'Add New Provider'),
        content: SizedBox(
          width: MediaQuery.of(context).size.width > 480 ? 440 : MediaQuery.of(context).size.width * 0.9,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(labelText: 'Business Name *'),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: emailController,
                  decoration: const InputDecoration(labelText: 'Email'),
                  keyboardType: TextInputType.emailAddress,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: phoneController,
                  decoration: const InputDecoration(labelText: 'Phone *'),
                  keyboardType: TextInputType.phone,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: passwordController,
                  obscureText: true,
                  decoration: InputDecoration(
                    labelText: isEdit ? 'New Password (leave blank to keep)' : 'Password *',
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: categoryController,
                  decoration: const InputDecoration(labelText: 'Category *'),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: cityController,
                  decoration: const InputDecoration(labelText: 'City *'),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: areaController,
                  decoration: const InputDecoration(labelText: 'Area *'),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: websiteController,
                  decoration: const InputDecoration(labelText: 'Website'),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: ratingController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: const InputDecoration(labelText: 'Rating'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: reviewsController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: 'Reviews'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final name = nameController.text.trim();
              final phone = phoneController.text.trim();
              final password = passwordController.text.trim();
              final category = categoryController.text.trim();
              final city = cityController.text.trim();
              final area = areaController.text.trim();

              if (name.isEmpty || phone.isEmpty || (!isEdit && password.isEmpty) || category.isEmpty || city.isEmpty || area.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Please fill all required fields (*)')),
                );
                return;
              }

              Navigator.pop(context);
              setState(() => _isLoading = true);

              try {
                final payload = {
                  'role': 'provider',
                  'name': name,
                  'email': emailController.text.trim(),
                  'phone': phone,
                  'password': password,
                  'category': category,
                  'city': city,
                  'area': area,
                  'website': websiteController.text.trim(),
                  'rating': double.tryParse(ratingController.text) ?? 0.0,
                  'review_count': int.tryParse(reviewsController.text) ?? 0,
                };
                if (isEdit) {
                  payload['id'] = provider['id'];
                  await _api.adminUpdateUser(payload);
                } else {
                  await _api.adminCreateUser(payload);
                }
                await _fetchStats();
              } catch (e) {
                setState(() => _isLoading = false);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Error saving provider.'), backgroundColor: Colors.red),
                  );
                }
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _logout() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to sign out of the Admin Panel?'),
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

  @override
  Widget build(BuildContext context) {
    final appState = Provider.of<AppStateProvider>(context);
    final isDark = appState.isDarkMode;
    const primaryColor = Color(0xFF1565C0);
    const accentColor = Color(0xFF0D47A1);

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        backgroundColor: isDark ? const Color(0xFF121212) : const Color(0xFFF5F7FA),
        appBar: AppBar(
          title: const Text(
            'Darbar Admin Panel',
            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
          ),
          backgroundColor: primaryColor,
          elevation: 4,
          actions: [
            IconButton(
              icon: const Icon(Icons.logout, color: Colors.white),
              onPressed: _logout,
            ),
          ],
          bottom: const TabBar(
            indicatorColor: Colors.white,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            tabs: [
              Tab(icon: Icon(Icons.dashboard), text: 'Dashboard'),
              Tab(icon: Icon(Icons.people), text: 'Customers'),
              Tab(icon: Icon(Icons.handyman), text: 'Providers'),
            ],
          ),
        ),
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 850),
            child: TabBarView(
              children: [
                _buildDashboardTab(isDark, primaryColor, accentColor),
                _buildCustomersTab(isDark, primaryColor),
                _buildProvidersTab(isDark, primaryColor),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDashboardTab(bool isDark, Color primaryColor, Color accentColor) {
    return RefreshIndicator(
      onRefresh: _fetchStats,
      child: _isLoading && _customerCount == 0 && _providerCount == 0
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
              children: [
                // Hero Header Card
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [primaryColor, accentColor],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: primaryColor.withOpacity(0.3),
                        blurRadius: 15,
                        offset: const Offset(0, 6),
                      )
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.admin_panel_settings_outlined,
                        color: Colors.white,
                        size: 40,
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Welcome, Administrator',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        widget.adminName,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 30),

                // Section Title
                const Text(
                  'SYSTEM METRICS',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 12),

                // Metrics grid
                Row(
                  children: [
                    Expanded(
                      child: _buildMetricCard(
                        title: 'Customers',
                        count: _customerCount,
                        icon: Icons.people,
                        iconColor: Colors.blue,
                        isDark: isDark,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _buildMetricCard(
                        title: 'Providers',
                        count: _providerCount,
                        icon: Icons.handyman,
                        iconColor: Colors.green,
                        isDark: isDark,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 30),

                // Configuration Section
                const Text(
                  'SYSTEM CONFIGURATIONS',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 12),

                // Configuration Card
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(isDark ? 0.3 : 0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      )
                    ],
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: primaryColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Icon(
                              Icons.api_outlined,
                              color: primaryColor,
                            ),
                          ),
                          const SizedBox(width: 16),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Apify API Integration',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                SizedBox(height: 4),
                                Text(
                                  'Toggle visibility of Apify controls in user settings screens globally.',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      const Divider(height: 1),
                      const SizedBox(height: 12),
                      SwitchListTile(
                        value: _apifyEnabledByAdmin,
                        onChanged: (_) => _toggleApify(),
                        title: const Text(
                          'Enable Apify Option Globally',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                        subtitle: const Text(
                          'When active, users can manually enable/disable Apify. When disabled, the option is completely hidden.',
                          style: TextStyle(fontSize: 11),
                        ),
                        activeColor: primaryColor,
                        contentPadding: EdgeInsets.zero,
                      ),
                    ],
                  ),
                ),

                if (_error != null) ...[
                  const SizedBox(height: 24),
                  Center(
                    child: Text(
                      _error!,
                      style: const TextStyle(color: Colors.red),
                    ),
                  ),
                ],
              ],
            ),
    );
  }

  Widget _buildCustomersTab(bool isDark, Color primaryColor) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showCustomerDialog(),
        backgroundColor: primaryColor,
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _customerSearchController,
              decoration: InputDecoration(
                hintText: 'Search customers by name, phone or email...',
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _fetchStats,
              child: _filteredCustomers.isEmpty
                  ? Center(
                      child: Text(
                        _isLoading ? 'Loading customers...' : 'No customers found',
                        style: const TextStyle(color: Colors.grey),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: _filteredCustomers.length,
                      itemBuilder: (context, index) {
                        final c = _filteredCustomers[index];
                        return Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Row(
                              children: [
                                CircleAvatar(
                                  backgroundColor: primaryColor.withOpacity(0.1),
                                  child: Icon(Icons.person, color: primaryColor),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        c['name'] ?? '',
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                      ),
                                      const SizedBox(height: 4),
                                      Text('Phone: ${c['phone'] ?? ''}', style: const TextStyle(fontSize: 13)),
                                      if (c['email'] != null && c['email'].toString().isNotEmpty)
                                        Text('Email: ${c['email']}', style: const TextStyle(fontSize: 13)),
                                      if (c['location'] != null && c['location'].toString().isNotEmpty)
                                        Text('Location: ${c['location']}', style: const TextStyle(fontSize: 13)),
                                    ],
                                  ),
                                ),
                                Column(
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.edit, color: Colors.blue),
                                      onPressed: () => _showCustomerDialog(customer: c),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.delete, color: Colors.red),
                                      onPressed: () => _deleteUser(c['id'], 'customer', c['name']),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProvidersTab(bool isDark, Color primaryColor) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showProviderDialog(),
        backgroundColor: Colors.green,
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _providerSearchController,
              decoration: InputDecoration(
                hintText: 'Search providers by name, phone or category...',
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _fetchStats,
              child: _filteredProviders.isEmpty
                  ? Center(
                      child: Text(
                        _isLoading ? 'Loading providers...' : 'No providers found',
                        style: const TextStyle(color: Colors.grey),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: _filteredProviders.length,
                      itemBuilder: (context, index) {
                        final p = _filteredProviders[index];
                        final rating = p['rating']?.toString() ?? '0.0';
                        final reviews = p['review_count']?.toString() ?? '0';

                        return Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Row(
                              children: [
                                CircleAvatar(
                                  backgroundColor: Colors.green.withOpacity(0.1),
                                  child: const Icon(Icons.handyman, color: Colors.green),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Wrap(
                                        spacing: 8,
                                        runSpacing: 4,
                                        crossAxisAlignment: WrapCrossAlignment.center,
                                        children: [
                                          Text(
                                            p['name'] ?? '',
                                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                          ),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: Colors.green.withOpacity(0.1),
                                              borderRadius: BorderRadius.circular(8),
                                            ),
                                            child: Text(
                                              p['category'] ?? 'General',
                                              style: const TextStyle(
                                                fontSize: 10,
                                                fontWeight: FontWeight.w600,
                                                color: Colors.green,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 6),
                                      Text('Phone: ${p['phone'] ?? ''}', style: const TextStyle(fontSize: 13)),
                                      if (p['email'] != null && p['email'].toString().isNotEmpty)
                                        Text('Email: ${p['email']}', style: const TextStyle(fontSize: 13)),
                                      Text(
                                        'City/Area: ${p['city'] ?? ''}, ${p['area'] ?? ''}',
                                        style: const TextStyle(fontSize: 13),
                                      ),
                                      Row(
                                        children: [
                                          const Icon(Icons.star, color: Colors.amber, size: 16),
                                          const SizedBox(width: 4),
                                          Text(
                                            '$rating ($reviews reviews)',
                                            style: const TextStyle(fontSize: 12, color: Colors.grey),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Column(
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.edit, color: Colors.blue),
                                      onPressed: () => _showProviderDialog(provider: p),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.delete, color: Colors.red),
                                      onPressed: () => _deleteUser(p['id'], 'provider', p['name']),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricCard({
    required String title,
    required int count,
    required IconData icon,
    required Color iconColor,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.3 : 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey,
                ),
              ),
              Icon(icon, color: iconColor),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            count.toString(),
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
