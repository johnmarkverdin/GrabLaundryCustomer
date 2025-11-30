import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../supabase_config.dart';
import '../pages/customer_home_page.dart';
import 'dart:ui';

class CustomerAuthPage extends StatefulWidget {
  const CustomerAuthPage({super.key});

  @override
  State<CustomerAuthPage> createState() => _CustomerAuthPageState();
}

class _CustomerAuthPageState extends State<CustomerAuthPage> {
  final _nameCtl = TextEditingController();
  final _phoneCtl = TextEditingController();
  final _emailCtl = TextEditingController();
  final _passwordCtl = TextEditingController();
  final _confirmCtl = TextEditingController();

  bool _loading = false;
  bool _isSignUp = false;
  bool _showPassword = false;

  // Remember me
  bool _rememberMe = false;

  @override
  void initState() {
    super.initState();
    _loadRememberedUser();
  }

  Future<void> _loadRememberedUser() async {
    final prefs = await SharedPreferences.getInstance();
    final remember = prefs.getBool('customer_remember_me') ?? false;
    final email = prefs.getString('customer_email');

    if (!mounted) return;

    setState(() {
      _rememberMe = remember;
      if (remember && email != null) {
        _emailCtl.text = email;
      }
    });

    // Auto-skip login when already signed in and remembered
    if (remember) {
      final session = supabase.auth.currentSession;
      if (session != null && mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const CustomerHomePage()),
        );
      }
    }
  }

  @override
  void dispose() {
    _nameCtl.dispose();
    _phoneCtl.dispose();
    _emailCtl.dispose();
    _passwordCtl.dispose();
    _confirmCtl.dispose();
    super.dispose();
  }

  Future<void> _auth() async {
    final name = _nameCtl.text.trim();
    final phone = _phoneCtl.text.trim();
    final email = _emailCtl.text.trim();
    final pass = _passwordCtl.text.trim();
    final confirm = _confirmCtl.text.trim();

    if (email.isEmpty || pass.isEmpty) {
      _snack('Email & password are required.');
      return;
    }

    if (_isSignUp) {
      if (name.isEmpty || phone.isEmpty || confirm.isEmpty) {
        _snack('Please fill in all the fields.');
        return;
      }
      if (pass != confirm) {
        _snack('Passwords do not match.');
        return;
      }
    }

    setState(() => _loading = true);

    try {
      if (_isSignUp) {
        final res = await supabase.auth.signUp(
          email: email,
          password: pass,
          data: {
            'full_name': name,
            'phone': phone,
            'role': 'customer',
          },
        );

        if (res.user != null) {
          _snack(
            'Account created successfully! Please check your email to confirm, then sign in.',
          );
          setState(() => _isSignUp = false);
        }
      } else {
        final res = await supabase.auth.signInWithPassword(
          email: email,
          password: pass,
        );

        if (res.session != null) {
          // Save or clear remember-me preferences
          final prefs = await SharedPreferences.getInstance();
          if (_rememberMe) {
            await prefs.setBool('customer_remember_me', true);
            await prefs.setString('customer_email', email);
          } else {
            await prefs.remove('customer_remember_me');
            await prefs.remove('customer_email');
          }

          if (!mounted) return;
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const CustomerHomePage()),
          );
        } else {
          _snack('Login failed. Confirm your email or try again.');
        }
      }
    } on AuthException catch (e) {
      _snack('Authentication error: ${e.message}');
    } catch (e) {
      _snack('Unexpected error: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  InputDecoration _inputDecoration({
    required String label,
    required IconData icon,
    String? hint,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      prefixIcon: Icon(icon),
      filled: true,
      fillColor: Colors.white.withOpacity(0.9),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: Colors.white.withOpacity(0.3)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Color(0xFF4F46E5), width: 1.5),
      ),
      errorBorder: const OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(16)),
        borderSide: BorderSide(color: Colors.red),
      ),
      focusedErrorBorder: const OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(16)),
        borderSide: BorderSide(color: Colors.red, width: 1.5),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final titleText = _isSignUp ? 'Create Customer Account' : 'Welcome Back';
    final subtitleText = _isSignUp
        ? 'Sign up to experience a smarter, faster way of managing your service.'
        : 'Sign in to continue where you left off and manage your experience.';

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Color(0xFF4F46E5),
              Color(0xFF0EA5E9),
              Color(0xFF22C55E),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Stack(
          children: [
            // Decorative circles / blobs
            Positioned(
              top: -80,
              right: -40,
              child: _blurCircle(160, Colors.white.withOpacity(0.12)),
            ),
            Positioned(
              bottom: -60,
              left: -20,
              child: _blurCircle(140, Colors.white.withOpacity(0.1)),
            ),
            SafeArea(
              child: Center(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final maxWidth =
                    constraints.maxWidth > 600 ? 450.0 : double.infinity;

                    return SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 24,
                      ),
                      child: Center(
                        child: ConstrainedBox(
                          constraints: BoxConstraints(maxWidth: maxWidth),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(24),
                            child: BackdropFilter(
                              filter: ImageFilter.blur(
                                sigmaX: 16,
                                sigmaY: 16,
                              ),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 300),
                                curve: Curves.easeOut,
                                padding: const EdgeInsets.all(20),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.12),
                                  borderRadius: BorderRadius.circular(24),
                                  border: Border.all(
                                    color: Colors.white.withOpacity(0.24),
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.25),
                                      blurRadius: 30,
                                      offset: const Offset(0, 20),
                                    ),
                                  ],
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // App logo + name (with your logo)
                                    Row(
                                      children: [
                                        Container(
                                          width: 70,
                                          height: 70,
                                          decoration: const BoxDecoration(
                                            shape: BoxShape.circle,
                                          ),
                                          child: ClipOval(
                                            child: Image.asset(
                                              'assets/logo.png',
                                              fit: BoxFit.cover,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Column(
                                          crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              'Customer Portal',
                                              style: theme
                                                  .textTheme.titleMedium
                                                  ?.copyWith(
                                                color: Colors.white,
                                                fontWeight: FontWeight.w600,
                                                letterSpacing: 0.4,
                                              ),
                                            ),
                                            Text(
                                              'Seamless • Secure • Smart',
                                              style: theme.textTheme.bodySmall
                                                  ?.copyWith(
                                                color: Colors.white
                                                    .withOpacity(0.8),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 24),
                                    Text(
                                      titleText,
                                      style: theme.textTheme.headlineSmall
                                          ?.copyWith(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: 0.4,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      subtitleText,
                                      style: theme.textTheme.bodyMedium
                                          ?.copyWith(
                                        color: Colors.white.withOpacity(0.85),
                                      ),
                                    ),
                                    const SizedBox(height: 24),

                                    // Toggle buttons (Sign In / Sign Up)
                                    Container(
                                      padding: const EdgeInsets.all(4),
                                      decoration: BoxDecoration(
                                        color: Colors.white.withOpacity(0.18),
                                        borderRadius: BorderRadius.circular(18),
                                      ),
                                      child: Row(
                                        children: [
                                          Expanded(
                                            child: _ModeButton(
                                              selected: !_isSignUp,
                                              label: 'Sign In',
                                              icon: Icons.login_rounded,
                                              onTap: () {
                                                if (_isSignUp) {
                                                  setState(() {
                                                    _isSignUp = false;
                                                  });
                                                }
                                              },
                                            ),
                                          ),
                                          const SizedBox(width: 6),
                                          Expanded(
                                            child: _ModeButton(
                                              selected: _isSignUp,
                                              label: 'Sign Up',
                                              icon: Icons.person_add_alt_1,
                                              onTap: () {
                                                if (!_isSignUp) {
                                                  setState(() {
                                                    _isSignUp = true;
                                                  });
                                                }
                                              },
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),

                                    const SizedBox(height: 22),

                                    // FORM
                                    if (_isSignUp) ...[
                                      TextField(
                                        controller: _nameCtl,
                                        textInputAction: TextInputAction.next,
                                        decoration: _inputDecoration(
                                          label: 'Full Name',
                                          icon: Icons.person_outline,
                                          hint: 'Enter your complete name',
                                        ),
                                      ),
                                      const SizedBox(height: 12),
                                      TextField(
                                        controller: _phoneCtl,
                                        textInputAction: TextInputAction.next,
                                        keyboardType: TextInputType.phone,
                                        decoration: _inputDecoration(
                                          label: 'Phone Number',
                                          icon: Icons.phone_outlined,
                                          hint: 'e.g. +63 9XX XXX XXXX',
                                        ),
                                      ),
                                      const SizedBox(height: 12),
                                    ],
                                    TextField(
                                      controller: _emailCtl,
                                      textInputAction: TextInputAction.next,
                                      keyboardType:
                                      TextInputType.emailAddress,
                                      decoration: _inputDecoration(
                                        label: 'Email Address',
                                        icon: Icons.email_outlined,
                                        hint: 'you@example.com',
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                    TextField(
                                      controller: _passwordCtl,
                                      textInputAction: _isSignUp
                                          ? TextInputAction.next
                                          : TextInputAction.done,
                                      obscureText: !_showPassword,
                                      decoration: _inputDecoration(
                                        label: 'Password',
                                        icon: Icons.lock_outline,
                                        hint: 'Create a strong password',
                                      ).copyWith(
                                        suffixIcon: IconButton(
                                          onPressed: () {
                                            setState(() {
                                              _showPassword = !_showPassword;
                                            });
                                          },
                                          icon: Icon(
                                            _showPassword
                                                ? Icons.visibility
                                                : Icons.visibility_off,
                                          ),
                                        ),
                                      ),
                                    ),

                                    // Remember me (only on Sign In)
                                    if (!_isSignUp) ...[
                                      const SizedBox(height: 8),
                                      Row(
                                        children: [
                                          Checkbox(
                                            value: _rememberMe,
                                            onChanged: (val) {
                                              setState(() {
                                                _rememberMe = val ?? false;
                                              });
                                            },
                                            activeColor:
                                            const Color(0xFF4F46E5),
                                            checkColor: Colors.white,
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            'Remember me',
                                            style: theme
                                                .textTheme.bodyMedium
                                                ?.copyWith(
                                              color: Colors.white
                                                  .withOpacity(0.9),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],

                                    if (_isSignUp) ...[
                                      const SizedBox(height: 12),
                                      TextField(
                                        controller: _confirmCtl,
                                        obscureText: true,
                                        textInputAction: TextInputAction.done,
                                        decoration: _inputDecoration(
                                          label: 'Confirm Password',
                                          icon: Icons.lock_reset_outlined,
                                          hint: 'Re-enter your password',
                                        ),
                                      ),
                                    ],
                                    const SizedBox(height: 18),

                                    // Primary button
                                    _loading
                                        ? const Center(
                                      child: CircularProgressIndicator(
                                        valueColor:
                                        AlwaysStoppedAnimation(
                                          Colors.white,
                                        ),
                                      ),
                                    )
                                        : SizedBox(
                                      width: double.infinity,
                                      child: ElevatedButton(
                                        onPressed: _auth,
                                        style: ElevatedButton.styleFrom(
                                          padding:
                                          const EdgeInsets.symmetric(
                                            vertical: 14,
                                          ),
                                          shape:
                                          RoundedRectangleBorder(
                                            borderRadius:
                                            BorderRadius.circular(20),
                                          ),
                                          elevation: 8,
                                          backgroundColor:
                                          const Color(0xFF4F46E5),
                                          foregroundColor: Colors.white,
                                        ),
                                        child: Row(
                                          mainAxisAlignment:
                                          MainAxisAlignment.center,
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(
                                              _isSignUp
                                                  ? Icons
                                                  .person_add_alt_1
                                                  : Icons.login_rounded,
                                            ),
                                            const SizedBox(width: 8),
                                            Text(
                                              _isSignUp
                                                  ? 'Create Account'
                                                  : 'Sign In',
                                              style: const TextStyle(
                                                fontSize: 16,
                                                fontWeight:
                                                FontWeight.w600,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),

                                    const SizedBox(height: 12),

                                    // Switch mode text
                                    Center(
                                      child: TextButton(
                                        onPressed: () => setState(
                                                () => _isSignUp = !_isSignUp),
                                        child: Text(
                                          _isSignUp
                                              ? 'Already have an account? Sign In'
                                              : 'New here? Create an account',
                                          style: TextStyle(
                                            color: Colors.white
                                                .withOpacity(0.95),
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ),
                                    ),

                                    const SizedBox(height: 8),

                                    // Helper / footer text
                                    Center(
                                      child: Text(
                                        'By continuing, you agree to our Terms of Service\nand acknowledge our Privacy Policy.',
                                        textAlign: TextAlign.center,
                                        style: theme.textTheme.bodySmall
                                            ?.copyWith(
                                          color: Colors.white.withOpacity(0.7),
                                          height: 1.4,
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
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _blurCircle(double size, Color color) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color,
      ),
    );
  }
}

class _ModeButton extends StatelessWidget {
  final bool selected;
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  const _ModeButton({
    required this.selected,
    required this.label,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final bgColor = selected ? Colors.white : Colors.transparent;
    final textColor =
    selected ? const Color(0xFF111827) : Colors.white.withOpacity(0.85);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: selected
            ? [
          BoxShadow(
            color: Colors.black.withOpacity(0.18),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ]
            : null,
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 10,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 18,
                color: textColor,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  color: textColor,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
