import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'register_screen.dart';
import 'main_shell.dart';
import 'provider_shell.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _identifierController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isProvider = false;
  bool _isLoading = false;
  bool _obscurePassword = true;
  String? _error;

  Future<void> _login() async {
    if (_identifierController.text.trim().isEmpty || _passwordController.text.isEmpty) {
      setState(() => _error = 'Please enter your email/phone and password.');
      return;
    }
    setState(() { _isLoading = true; _error = null; });

    try {
      final dio = Dio();
      final response = await dio.post(
        'http://127.0.0.1:8000/api/auth/login/',
        data: {
          'identifier': _identifierController.text.trim(),
          'password': _passwordController.text,
          'role': _isProvider ? 'provider' : 'customer',
        },
      );
      final data = response.data;
      if (!mounted) return;

      if (data['role'] == 'provider') {
        Navigator.pushReplacement(context, MaterialPageRoute(
          builder: (_) => ProviderShell(providerId: data['id'], providerName: data['name']),
        ));
      } else {
        Navigator.pushReplacement(context, MaterialPageRoute(
          builder: (_) => MainShell(userId: data['id'], userName: data['name']),
        ));
      }
    } on DioException catch (e) {
      setState(() => _error = e.response?.data['error'] ?? 'Login failed. Please try again.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 48),
              Container(
                width: 80, height: 80,
                decoration: BoxDecoration(
                  color: const Color(0xFF1565C0),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Icon(Icons.handyman, color: Colors.white, size: 44),
              ),
              const SizedBox(height: 24),
              Text('Welcome Back', style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              const Text('Sign in to continue to Darbar', style: TextStyle(color: Colors.grey, fontSize: 16)),
              const SizedBox(height: 40),

              TextField(
                controller: _identifierController,
                decoration: const InputDecoration(labelText: 'Email or Phone Number', prefixIcon: Icon(Icons.person_outline)),
              ),
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
              const SizedBox(height: 12),

              Row(
                children: [
                  Checkbox(value: _isProvider, onChanged: (v) => setState(() => _isProvider = v ?? false)),
                  const Text('Login as Service Provider'),
                ],
              ),

              if (_error != null) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.red.shade200)),
                  child: Text(_error!, style: TextStyle(color: Colors.red.shade700, fontSize: 14)),
                ),
              ],

              const SizedBox(height: 20),

              ElevatedButton(
                style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
                onPressed: _isLoading ? null : _login,
                child: _isLoading
                    ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Text('Sign In', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
              const SizedBox(height: 20),

              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text("Don't have an account?"),
                  TextButton(
                    onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const RegisterScreen())),
                    child: const Text('Create Account', style: TextStyle(color: Color(0xFF1565C0), fontWeight: FontWeight.bold)),
                  ),
                ],
              )
            ],
          ),
        ),
      ),
    );
  }
}
