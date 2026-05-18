import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
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
  
  // Provider-specific fields
  final _categoryController = TextEditingController();
  final _cityController = TextEditingController();
  final _areaController = TextEditingController();
  
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  String? _error;

  Future<void> _register() async {
    final name = _nameController.text.trim();
    final email = _emailController.text.trim();
    final phone = _phoneController.text.trim();
    final password = _passwordController.text;
    final confirmPassword = _confirmPasswordController.text;

    if (name.isEmpty || email.isEmpty || phone.isEmpty || password.isEmpty || confirmPassword.isEmpty) {
      setState(() => _error = 'All fields (Name, Email, Phone, Password, Confirm Password) are required.');
      return;
    }

    if (password != confirmPassword) {
      setState(() => _error = 'Passwords do not match.');
      return;
    }

    if (_selectedRole == 'provider' && _categoryController.text.trim().isEmpty) {
      setState(() => _error = 'Service Category is required for service providers.');
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final dio = Dio();
      final response = await dio.post(
        'http://127.0.0.1:8000/api/auth/register/',
        data: {
          'name': name,
          'email': email,
          'phone': phone,
          'password': password,
          'role': _selectedRole,
          if (_selectedRole == 'provider') ...{
            'category': _categoryController.text.trim(),
            'city': _cityController.text.trim().isEmpty ? 'Islamabad' : _cityController.text.trim(),
            'area': _areaController.text.trim(),
          }
        },
      );

      final data = response.data;
      if (!mounted) return;

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
    } on DioException catch (e) {
      setState(() {
        _error = e.response?.data['error'] ?? 'Registration failed. Please check details and try again.';
      });
    } catch (e) {
      setState(() {
        _error = 'An error occurred: $e';
      });
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeColor = _selectedRole == 'provider' ? Colors.green : const Color(0xFF1565C0);
    
    return Scaffold(
      backgroundColor: Colors.white,
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
            const Text(
              'I want to register as a...',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            
            // Role Toggles
            Row(
              children: [
                Expanded(child: _roleCard('customer', 'Customer', Icons.person, const Color(0xFF1565C0))),
                const SizedBox(width: 16),
                Expanded(child: _roleCard('provider', 'Service Provider', Icons.work, Colors.green)),
              ],
            ),
            const SizedBox(height: 28),
            
            _field(_nameController, _selectedRole == 'provider' ? 'Business Name' : 'Full Name', Icons.person_outline),
            const SizedBox(height: 14),
            _field(_emailController, 'Email Address', Icons.email_outlined, keyboard: TextInputType.emailAddress),
            const SizedBox(height: 14),
            _field(_phoneController, 'Phone Number', Icons.phone_outlined, keyboard: TextInputType.phone),
            const SizedBox(height: 14),
            
            TextField(
              controller: _passwordController,
              obscureText: _obscurePassword,
              decoration: InputDecoration(
                labelText: 'Password',
                prefixIcon: const Icon(Icons.lock_outline),
                suffixIcon: IconButton(
                  icon: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility),
                  onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                ),
              ),
            ),
            const SizedBox(height: 14),
            
            TextField(
              controller: _confirmPasswordController,
              obscureText: _obscureConfirmPassword,
              decoration: InputDecoration(
                labelText: 'Confirm Password',
                prefixIcon: const Icon(Icons.lock_outline),
                suffixIcon: IconButton(
                  icon: Icon(_obscureConfirmPassword ? Icons.visibility_off : Icons.visibility),
                  onPressed: () => setState(() => _obscureConfirmPassword = !_obscureConfirmPassword),
                ),
              ),
            ),
            
            if (_selectedRole == 'provider') ...[
              const SizedBox(height: 14),
              _field(_categoryController, 'Service Category (e.g. AC Tech, Plumber)', Icons.build_outlined),
              const SizedBox(height: 14),
              _field(_cityController, 'City (default: Islamabad)', Icons.location_city_outlined),
              const SizedBox(height: 14),
              _field(_areaController, 'Area / Location (e.g. G-13)', Icons.map_outlined),
            ],
            
            if (_error != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.shade200),
                ),
                child: Text(_error!, style: TextStyle(color: Colors.red.shade700, fontSize: 14)),
              ),
            ],
            
            const SizedBox(height: 28),
            
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                backgroundColor: themeColor,
              ),
              onPressed: _isLoading ? null : _register,
              child: _isLoading
                  ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Text('Create Account', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ),
            const SizedBox(height: 20),
            
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text('Already have an account? '),
                GestureDetector(
                  onTap: () {
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(builder: (_) => const LoginScreen()),
                    );
                  },
                  child: Text(
                    'Login',
                    style: TextStyle(color: themeColor, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _roleCard(String role, String label, IconData icon, Color color) {
    final selected = _selectedRole == role;
    return GestureDetector(
      onTap: () => setState(() => _selectedRole = role),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: selected ? color.withOpacity(0.08) : Colors.white,
          border: Border.all(color: selected ? color : Colors.grey.shade300, width: 2),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            Icon(icon, size: 36, color: selected ? color : Colors.grey),
            const SizedBox(height: 8),
            Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: selected ? color : Colors.grey,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _field(TextEditingController controller, String label, IconData icon, {TextInputType? keyboard}) {
    return TextField(
      controller: controller,
      keyboardType: keyboard,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
      ),
    );
  }
}
