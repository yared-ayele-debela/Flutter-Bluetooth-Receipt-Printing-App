// lib/pages/login_page.dart
import 'dart:convert';
import 'dart:ui';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../services/api_service.dart';
import 'sales_dashboard.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({Key? key}) : super(key: key);

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _rememberMe = true; // Default: checked
  String? _errorMessage;

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  // Professional indigo colors (safe for const)
  static const Color primary = Color(0xFF3949AB); // indigo[700]
  static const Color primaryDark = Color(0xFF1A237E); // indigo[900]

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final response = await http.post(
        Uri.parse('https://eam.afroel.com/api/admin/login'), // Change if using local
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': _emailController.text.trim(),
          'password': _passwordController.text,
        }),
      ).timeout(const Duration(seconds: 15));

      final data = jsonDecode(response.body);

      if (response.statusCode == 200 && data['token'] != null) {
        // Save token & admin data
        await ApiService().saveToken(data['token']);
        await ApiService().saveAdmin(data['admin']); // ← This saves admin ID
        if (data['admin'] != null) await ApiService().saveAdmin(data['admin']);
        // ←←← SAVE REMEMBER ME PREFERENCE ←←←
        await ApiService().saveRememberMe(_rememberMe);

        final fcmToken = await FirebaseMessaging.instance.getToken();
        if (fcmToken != null) {
          try {
            await http.post(
              Uri.parse('https://eam.afroel.com/api/admin/update-fcm-token'),
              headers: await ApiService().getHeaders(),
              body: jsonEncode({'fcm_token': fcmToken}),
            );
          } catch (e) {
            debugPrint("Failed to update FCM token after login: $e");
          }
        }

        if (mounted) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => const SalesDashboard()),
          );
        }
      } else {
        setState(() {
          _errorMessage = data['message'] ?? 'Invalid email or password';
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'No internet connection';
      });
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Gradient Background
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [primary, primaryDark],
              ),
            ),
          ),

          FadeTransition(
            opacity: _fadeAnimation,
            child: SafeArea(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: Column(
                    children: [
                      // Logo
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.15),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.point_of_sale, size: 80, color: Colors.white),
                      ),
                      const SizedBox(height: 24),
                      const Text(
                        'POS Admin Panel',
                        style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 1.2),
                      ),
                      const SizedBox(height: 8),
                      const Text('Sign in to continue', style: TextStyle(fontSize: 16, color: Colors.white70)),
                      const SizedBox(height: 48),

                      // Glass Card
                      ClipRRect(
                        borderRadius: BorderRadius.circular(24),
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                          child: Container(
                            padding: const EdgeInsets.all(32),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(24),
                              border: Border.all(color: Colors.white.withOpacity(0.2)),
                            ),
                            child: Form(
                              key: _formKey,
                              child: Column(
                                children: [
                                  // Email
                                  TextFormField(
                                    controller: _emailController,
                                    keyboardType: TextInputType.emailAddress,
                                    style: const TextStyle(color: Colors.white),
                                    decoration: InputDecoration(
                                      labelText: 'Email Address',
                                      labelStyle: const TextStyle(color: Colors.white70),
                                      prefixIcon: const Icon(Icons.email_outlined, color: Colors.white70),
                                      filled: true,
                                      fillColor: Colors.white.withOpacity(0.1),
                                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Colors.white, width: 2)),
                                    ),
                                    validator: (v) => v?.isEmpty == true
                                        ? 'Email required'
                                        : !RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(v!)
                                        ? 'Enter valid email'
                                        : null,
                                  ),
                                  const SizedBox(height: 20),

                                  // Password
                                  TextFormField(
                                    controller: _passwordController,
                                    obscureText: _obscurePassword,
                                    style: const TextStyle(color: Colors.white),
                                    decoration: InputDecoration(
                                      labelText: 'Password',
                                      labelStyle: const TextStyle(color: Colors.white70),
                                      prefixIcon: const Icon(Icons.lock_outline, color: Colors.white70),
                                      suffixIcon: IconButton(
                                        icon: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility, color: Colors.white70),
                                        onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                                      ),
                                      filled: true,
                                      fillColor: Colors.white.withOpacity(0.1),
                                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Colors.white, width: 2)),
                                    ),
                                    validator: (v) => v?.isEmpty == true ? 'Password required' : v!.length < 6 ? 'Min 6 characters' : null,
                                  ),
                                  const SizedBox(height: 20),
                                  // ←←← REMEMBER ME + FORGOT PASSWORD ←←←
                                  // ←←← BEST & PERMANENT FIX – NO OVERFLOW EVER ←←←
                                  Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 4.0), // optional small padding
                                    child: Row(
                                      children: [
                                        // Remember me + Checkbox (takes only needed space)
                                        Checkbox(
                                          value: _rememberMe,
                                          onChanged: (val) => setState(() => _rememberMe = val ?? true),
                                          activeColor: Colors.white,
                                          checkColor: primaryDark,
                                          side: const BorderSide(color: Colors.white70, width: 2),
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                                        ),
                                        GestureDetector(
                                          onTap: () => setState(() => _rememberMe = !_rememberMe),
                                          child: const Text(
                                            'Remember me',
                                            style: TextStyle(color: Colors.white70),
                                          ),
                                        ),
                                        const Spacer(), // ← This magically pushes the right button to the end
                                        // Forgot password?
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 20),

                                  // Error Message
                                  if (_errorMessage != null) ...[
                                    Container(
                                      width: double.infinity,
                                      padding: const EdgeInsets.all(14),
                                      decoration: BoxDecoration(
                                        color: Colors.red.shade600.withOpacity(0.2),
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(color: Colors.red.shade400),
                                      ),
                                      child: Row(
                                        children: [
                                          const Icon(Icons.error_outline, color: Colors.redAccent),
                                          const SizedBox(width: 10),
                                          Expanded(child: Text(_errorMessage!, style: const TextStyle(color: Colors.white))),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(height: 20),
                                  ],

                                  // Login Button
                                  SizedBox(
                                    width: double.infinity,
                                    height: 56,
                                    child: ElevatedButton(
                                      onPressed: _isLoading ? null : _login,
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.white,
                                        foregroundColor: primaryDark,
                                        elevation: 10,
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                      ),
                                      child: _isLoading
                                          ? const SizedBox(
                                        height: 28,
                                        width: 28,
                                        child: CircularProgressIndicator(color: primaryDark, strokeWidth: 3),
                                      )
                                          : const Text('SIGN IN', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
                                    ),
                                  ),

                                  const SizedBox(height: 24),
                                  const Text('© 2025 Afroel POS System', style: TextStyle(color: Colors.white54, fontSize: 12)),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}