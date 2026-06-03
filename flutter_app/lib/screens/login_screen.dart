import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../services/api_service.dart';
import '../services/theme_provider.dart';
import 'register_screen.dart';
import 'main_shell.dart';
import 'provider_shell.dart';
import 'admin_panel_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> with SingleTickerProviderStateMixin {
  final _identifierController = TextEditingController();
  final _passwordController = TextEditingController();
  final _api = ApiService();
  bool _isProvider = false;
  bool _isLoading = false;
  bool _obscurePassword = true;
  String? _error;

  String? _emailError;
  String? _passwordError;
  bool _emailTouched = false;
  bool _passwordTouched = false;
  final _emailFocus = FocusNode();
  final _passwordFocus = FocusNode();

  static final _emailRegex = RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$');

  late AnimationController _animController;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(vsync: this, duration: const Duration(milliseconds: 800));
    _fadeAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeOut),
    );
    _slideAnim = Tween<Offset>(begin: const Offset(0, 0.1), end: Offset.zero).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeOut),
    );
    _animController.forward();

    _emailFocus.addListener(() {
      if (!_emailFocus.hasFocus) {
        setState(() {
          _emailTouched = true;
          _validateEmail();
        });
      }
    });
    _passwordFocus.addListener(() {
      if (!_passwordFocus.hasFocus) {
        setState(() {
          _passwordTouched = true;
          _validatePassword();
        });
      }
    });
  }

  @override
  void dispose() {
    _animController.dispose();
    _identifierController.dispose();
    _passwordController.dispose();
    _emailFocus.dispose();
    _passwordFocus.dispose();
    super.dispose();
  }

  void _validateEmail() {
    final email = _identifierController.text.trim();
    if (email.isEmpty) {
      _emailError = 'Email address is required.';
    } else if (!_emailRegex.hasMatch(email)) {
      _emailError = 'Please enter a valid email address.';
    } else {
      _emailError = null;
    }
  }

  void _validatePassword() {
    final pass = _passwordController.text;
    if (pass.isEmpty) {
      _passwordError = 'Password is required.';
    } else {
      _passwordError = null;
    }
  }

  bool get _isFormValid => _emailError == null && _passwordError == null &&
      _identifierController.text.trim().isNotEmpty && _passwordController.text.isNotEmpty;

  Future<void> _login() async {
    setState(() {
      _emailTouched = true;
      _passwordTouched = true;
      _validateEmail();
      _validatePassword();
    });

    if (!_isFormValid) {
      setState(() => _error = 'Please resolve errors in the form.');
      return;
    }
    setState(() { _isLoading = true; _error = null; });

    try {
      final api = ApiService();
      final data = await api.login(
        identifier: _identifierController.text.trim(),
        password: _passwordController.text,
        role: _isProvider ? 'provider' : 'customer',
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

      if (data['role'] == 'admin') {
        Navigator.pushReplacement(context, MaterialPageRoute(
          builder: (_) => AdminPanelScreen(adminId: data['id'], adminName: data['name']),
        ));
      } else if (data['role'] == 'provider') {
        Navigator.pushReplacement(context, MaterialPageRoute(
          builder: (_) => ProviderShell(providerId: data['id'], providerName: data['name']),
        ));
      } else {
        Navigator.pushReplacement(context, MaterialPageRoute(
          builder: (_) => MainShell(userId: data['id'], userName: data['name']),
        ));
      }
    } catch (e) {
      String msg = 'Login failed. Please check your credentials.';
      if (e.toString().contains('Connection refused') || e.toString().contains('SocketException')) {
        msg = 'Cannot connect to server. Please make sure the backend is running.';
      }
      setState(() => _error = msg);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loginWithGoogle(AppStateProvider appState) async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final clientId = await _api.getGoogleClientId();
      final GoogleSignIn googleSignIn = GoogleSignIn(
        clientId: clientId,
        scopes: ['email', 'openid'],
      );

      // Force Google Account Chooser by signing out and disconnecting previous session
      try {
        await googleSignIn.signOut();
      } catch (_) {}
      try {
        await googleSignIn.disconnect();
      } catch (_) {}

      // Trigger the Google auth flow
      final GoogleSignInAccount? googleUser = await googleSignIn.signIn();
      
      if (googleUser == null) {
        // User cancelled the flow
        setState(() => _isLoading = false);
        return;
      }

      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final String? idToken = googleAuth.idToken;
      final String? accessToken = googleAuth.accessToken;

      if (idToken == null && accessToken == null) {
        throw Exception('Failed to retrieve Google Authentication Tokens.');
      }

      final role = _isProvider ? 'provider' : 'customer';
      
      // Send token to backend
      final data = await _api.loginWithGoogle(
        idToken: idToken,
        accessToken: accessToken,
        role: role,
      );

      // Save user session in AppStateProvider
      await appState.saveSession(userId: data['id'], userName: data['name'], userEmail: data['email'], userRole: role);

      if (mounted) {
        final actualRole = data['role'] ?? role;
        if (actualRole == 'admin') {
          Navigator.pushReplacement(context, MaterialPageRoute(
            builder: (_) => AdminPanelScreen(adminId: data['id'], adminName: data['name']),
          ));
        } else if (actualRole == 'provider') {
          Navigator.pushReplacement(context, MaterialPageRoute(
            builder: (_) => ProviderShell(providerId: data['id'], providerName: data['name']),
          ));
        } else {
          Navigator.pushReplacement(context, MaterialPageRoute(
            builder: (_) => MainShell(userId: data['id'], userName: data['name']),
          ));
        }
      }
    } catch (e) {
      print('GOOGLE SIGN IN ERROR: $e');
      String msg = 'Google Sign-In failed: $e. Please make sure your account is linked first.';
      
      // Developer bypass for easy mock login in simulators
      if (e.toString().contains('Verification') || e.toString().contains('developer') || e.toString().contains('PlatformException') || e.toString().contains('sign_in_failed')) {
        final emailInput = _identifierController.text.trim();
        if (emailInput.contains('@')) {
          try {
            final role = _isProvider ? 'provider' : 'customer';
            final data = await _api.loginWithGoogle(idToken: emailInput, role: role);
            await appState.saveSession(userId: data['id'], userName: data['name'], userEmail: data['email'], userRole: role);
            if (mounted) {
              if (role == 'provider') {
                Navigator.pushReplacement(context, MaterialPageRoute(
                  builder: (_) => ProviderShell(providerId: data['id'], providerName: data['name']),
                ));
              } else {
                Navigator.pushReplacement(context, MaterialPageRoute(
                  builder: (_) => MainShell(userId: data['id'], userName: data['name']),
                ));
              }
            }
            return;
          } catch (mockErr) {
            msg = 'Google login failed: $mockErr';
          }
        }
      }

      if (e.toString().contains('Connection refused') || e.toString().contains('SocketException')) {
        msg = 'Cannot connect to server. Please make sure the backend is running.';
      } else if (e.toString().contains('No customer account found') || e.toString().contains('No provider account found') || e.toString().contains('linked')) {
        msg = e.toString().replaceAll('Exception:', '').replaceAll('DioException:', '').trim();
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
    final primaryColor = const Color(0xFF1565C0);

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF121212) : Colors.white,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: FadeTransition(
              opacity: _fadeAnim,
          child: SlideTransition(
            position: _slideAnim,
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 40),

                  // Logo
                  Center(
                    child: Container(
                      width: 80, height: 80,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF0D47A1), Color(0xFF1976D2)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(22),
                        boxShadow: [
                          BoxShadow(
                            color: primaryColor.withOpacity(0.3),
                            blurRadius: 16,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: const Icon(Icons.handyman, color: Colors.white, size: 42),
                    ),
                  ),
                  const SizedBox(height: 28),

                  Text(
                    'Welcome Back',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Sign in to continue to Darbar',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[600], fontSize: 15),
                  ),
                  const SizedBox(height: 36),

                  // Email Address field
                  TextField(
                    controller: _identifierController,
                    focusNode: _emailFocus,
                    keyboardType: TextInputType.emailAddress,
                    style: TextStyle(color: isDark ? Colors.white : Colors.black87),
                    decoration: InputDecoration(
                      labelText: 'Email Address',
                      labelStyle: TextStyle(color: isDark ? Colors.grey[400] : null),
                      prefixIcon: Icon(Icons.email_outlined, color: isDark ? Colors.grey[400] : null),
                      filled: true,
                      fillColor: isDark ? const Color(0xFF1E1E1E) : const Color(0xFFF5F7FA),
                      errorText: _emailTouched ? _emailError : null,
                    ),
                    onChanged: (_) {
                      if (_emailTouched) {
                        setState(_validateEmail);
                      }
                    },
                  ),
                  const SizedBox(height: 14),

                  // Password field
                  TextField(
                    controller: _passwordController,
                    focusNode: _passwordFocus,
                    obscureText: _obscurePassword,
                    style: TextStyle(color: isDark ? Colors.white : Colors.black87),
                    decoration: InputDecoration(
                      labelText: 'Password',
                      labelStyle: TextStyle(color: isDark ? Colors.grey[400] : null),
                      prefixIcon: Icon(Icons.lock_outline, color: isDark ? Colors.grey[400] : null),
                      filled: true,
                      fillColor: isDark ? const Color(0xFF1E1E1E) : const Color(0xFFF5F7FA),
                      errorText: _passwordTouched ? _passwordError : null,
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscurePassword ? Icons.visibility_off : Icons.visibility,
                          color: isDark ? Colors.grey[400] : null,
                        ),
                        onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                      ),
                    ),
                    onChanged: (_) {
                      if (_passwordTouched) {
                        setState(_validatePassword);
                      }
                    },
                    onSubmitted: (_) => _login(),
                  ),
                  const SizedBox(height: 12),

                  // Provider toggle
                  Row(
                    children: [
                      Checkbox(
                        value: _isProvider,
                        onChanged: (v) => setState(() => _isProvider = v ?? false),
                        activeColor: primaryColor,
                      ),
                      Text(
                        'Login as Service Provider',
                        style: TextStyle(color: isDark ? Colors.grey[300] : Colors.black87),
                      ),
                    ],
                  ),

                  // Error display
                  if (_error != null) ...[
                    const SizedBox(height: 8),
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
                          Expanded(
                            child: Text(_error!, style: TextStyle(color: isDark ? Colors.red[300] : Colors.red.shade700, fontSize: 13)),
                          ),
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: 24),

                  // Sign In button
                  SizedBox(
                    height: 52,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryColor,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        elevation: 0,
                      ),
                      onPressed: _isLoading ? null : _login,
                      child: _isLoading
                          ? const SizedBox(height: 22, width: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                          : const Text('Sign In', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Register link
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        "Don't have an account?",
                        style: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[600]),
                      ),
                      TextButton(
                        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const RegisterScreen())),
                        child: const Text('Create Account', style: TextStyle(color: Color(0xFF1565C0), fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),

                  const SizedBox(height: 20),

                  // Dark mode toggle at bottom
                  Center(
                    child: TextButton.icon(
                      onPressed: () => appState.toggleTheme(!isDark),
                      icon: Icon(isDark ? Icons.light_mode : Icons.dark_mode, size: 18, color: Colors.grey),
                      label: Text(
                        isDark ? 'Switch to Light Mode' : 'Switch to Dark Mode',
                        style: const TextStyle(color: Colors.grey, fontSize: 12),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
          ),
        ),
      ),
    );
  }
}
