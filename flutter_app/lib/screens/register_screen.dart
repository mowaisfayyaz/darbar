import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/api_service.dart';
import '../services/theme_provider.dart';
import 'login_screen.dart';
import 'main_shell.dart';
import 'provider_shell.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  String _selectedRole = 'customer';
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _categoryController = TextEditingController();
  final _cityController = TextEditingController();
  final _areaController = TextEditingController();
  
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  String? _error;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _categoryController.dispose();
    _cityController.dispose();
    _areaController.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    final name = _nameController.text.trim();
    final email = _emailController.text.trim();
    final phone = _phoneController.text.trim();
    final password = _passwordController.text;
    final confirmPassword = _confirmPasswordController.text;

    if (name.isEmpty || email.isEmpty || phone.isEmpty || password.isEmpty || confirmPassword.isEmpty) {
      setState(() => _error = 'All fields are required.');
      return;
    }

    if (!RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$').hasMatch(email)) {
      setState(() => _error = 'Please enter a valid email address.');
      return;
    }

    if (password.length < 8) {
      setState(() => _error = 'Password must be at least 8 characters.');
      return;
    }

    if (!RegExp(r'[0-9!@#$%^&*(),.?":{}|<>]').hasMatch(password)) {
      setState(() => _error = 'Password must contain at least 1 number or special character.');
      return;
    }

    if (password != confirmPassword) {
      setState(() => _error = 'Passwords do not match.');
      return;
    }

    if (_selectedRole == 'provider' && _categoryController.text.trim().isEmpty) {
      setState(() => _error = 'Service Category is required for providers.');
      return;
    }

    setState(() { _isLoading = true; _error = null; });

    try {
      final api = ApiService();
      final data = await api.register(
        name: name,
        email: email,
        phone: phone,
        password: password,
        role: _selectedRole,
        category: _selectedRole == 'provider' ? _categoryController.text.trim() : null,
        city: _selectedRole == 'provider' ? (_cityController.text.trim().isEmpty ? 'Islamabad' : _cityController.text.trim()) : null,
        area: _selectedRole == 'provider' ? _areaController.text.trim() : null,
      );

      if (!mounted) return;

      // Save session
      final appState = Provider.of<AppStateProvider>(context, listen: false);
      await appState.saveSession(
        userId: data['id'],
        userName: data['name'],
        userEmail: data['email'],
        userRole: data['role'],
      );

      if (data['role'] == 'provider') {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => ProviderShell(providerId: data['id'], providerName: data['name'])),
          (route) => false,
        );
      } else {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => MainShell(userId: data['id'], userName: data['name'])),
          (route) => false,
        );
      }
    } catch (e) {
      String msg = 'Registration failed. Please try again.';
      if (e.toString().contains('Connection refused')) {
        msg = 'Cannot connect to server. Please make sure the backend is running.';
      }
      setState(() => _error = msg);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final appState = Provider.of<AppStateProvider>(context);
    final isDark = appState.isDarkMode;
    final themeColor = _selectedRole == 'provider' ? Colors.green : const Color(0xFF1565C0);
    
    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF121212) : Colors.white,
      appBar: AppBar(
        title: const Text('Create Account'),
        backgroundColor: themeColor,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'I want to register as a...',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
            const SizedBox(height: 16),
            
            // Role Toggles
            Row(
              children: [
                Expanded(child: _roleCard('customer', 'Customer', Icons.person, const Color(0xFF1565C0), isDark)),
                const SizedBox(width: 16),
                Expanded(child: _roleCard('provider', 'Service Provider', Icons.work, Colors.green, isDark)),
              ],
            ),
            const SizedBox(height: 28),
            
            _field(_nameController, _selectedRole == 'provider' ? 'Business Name' : 'Full Name', Icons.person_outline, isDark),
            const SizedBox(height: 14),
            _field(_emailController, 'Email Address', Icons.email_outlined, isDark, keyboard: TextInputType.emailAddress),
            const SizedBox(height: 14),
            _field(_phoneController, 'Phone Number', Icons.phone_outlined, isDark, keyboard: TextInputType.phone),
            const SizedBox(height: 14),
            
            TextField(
              controller: _passwordController,
              obscureText: _obscurePassword,
              style: TextStyle(color: isDark ? Colors.white : Colors.black87),
              decoration: InputDecoration(
                labelText: 'Password',
                labelStyle: TextStyle(color: isDark ? Colors.grey[400] : null),
                prefixIcon: Icon(Icons.lock_outline, color: isDark ? Colors.grey[400] : null),
                filled: true,
                fillColor: isDark ? const Color(0xFF1E1E1E) : const Color(0xFFF5F7FA),
                suffixIcon: IconButton(
                  icon: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility, color: isDark ? Colors.grey[400] : null),
                  onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                ),
              ),
            ),
            const SizedBox(height: 14),
            
            TextField(
              controller: _confirmPasswordController,
              obscureText: _obscureConfirmPassword,
              style: TextStyle(color: isDark ? Colors.white : Colors.black87),
              decoration: InputDecoration(
                labelText: 'Confirm Password',
                labelStyle: TextStyle(color: isDark ? Colors.grey[400] : null),
                prefixIcon: Icon(Icons.lock_outline, color: isDark ? Colors.grey[400] : null),
                filled: true,
                fillColor: isDark ? const Color(0xFF1E1E1E) : const Color(0xFFF5F7FA),
                suffixIcon: IconButton(
                  icon: Icon(_obscureConfirmPassword ? Icons.visibility_off : Icons.visibility, color: isDark ? Colors.grey[400] : null),
                  onPressed: () => setState(() => _obscureConfirmPassword = !_obscureConfirmPassword),
                ),
              ),
            ),
            
            if (_selectedRole == 'provider') ...[
              const SizedBox(height: 14),
              _field(_categoryController, 'Service Category (e.g. AC Technician, Plumber)', Icons.build_outlined, isDark),
              const SizedBox(height: 14),
              _field(_cityController, 'City (default: Islamabad)', Icons.location_city_outlined, isDark),
              const SizedBox(height: 14),
              _field(_areaController, 'Area / Location (e.g. G-13)', Icons.map_outlined, isDark),
            ],
            
            if (_error != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isDark ? Colors.red.shade900.withOpacity(0.3) : Colors.red.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.red.shade300.withOpacity(0.5)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline, color: Colors.red, size: 20),
                    const SizedBox(width: 10),
                    Expanded(child: Text(_error!, style: TextStyle(color: isDark ? Colors.red[300] : Colors.red.shade700, fontSize: 13))),
                  ],
                ),
              ),
            ],
            
            const SizedBox(height: 28),
            
            SizedBox(
              height: 52,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: themeColor,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  elevation: 0,
                ),
                onPressed: _isLoading ? null : _register,
                child: _isLoading
                    ? const SizedBox(height: 22, width: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                    : const Text('Create Account', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ),
            const SizedBox(height: 20),
            
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Already have an account? ',
                  style: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[600]),
                ),
                GestureDetector(
                  onTap: () => Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const LoginScreen())),
                  child: Text('Login', style: TextStyle(color: themeColor, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _roleCard(String role, String label, IconData icon, Color color, bool isDark) {
    final selected = _selectedRole == role;
    return GestureDetector(
      onTap: () => setState(() => _selectedRole = role),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: selected
              ? color.withOpacity(isDark ? 0.15 : 0.08)
              : (isDark ? const Color(0xFF1E1E1E) : Colors.white),
          border: Border.all(
            color: selected ? color : (isDark ? Colors.grey[700]! : Colors.grey.shade300),
            width: selected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            Icon(icon, size: 36, color: selected ? color : (isDark ? Colors.grey[400] : Colors.grey)),
            const SizedBox(height: 8),
            Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 13,
                color: selected ? color : (isDark ? Colors.grey[400] : Colors.grey),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _field(TextEditingController controller, String label, IconData icon, bool isDark, {TextInputType? keyboard}) {
    return TextField(
      controller: controller,
      keyboardType: keyboard,
      style: TextStyle(color: isDark ? Colors.white : Colors.black87),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: isDark ? Colors.grey[400] : null),
        prefixIcon: Icon(icon, color: isDark ? Colors.grey[400] : null),
        filled: true,
        fillColor: isDark ? const Color(0xFF1E1E1E) : const Color(0xFFF5F7FA),
      ),
    );
  }
}
