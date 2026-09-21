import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:simplebilling_mobile/core/constants/app_colors.dart';
import 'package:simplebilling_mobile/core/constants/app_theme.dart';
import 'package:simplebilling_mobile/core/network/supabase_client.dart';

class LoginScreen extends StatefulWidget {
  final VoidCallback onLoginSuccess;
  final VoidCallback? onGuestLogin;

  const LoginScreen({
    super.key,
    required this.onLoginSuccess,
    this.onGuestLogin,
  });

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _emailCtrl = TextEditingController();
  final TextEditingController _passwordCtrl = TextEditingController();
  bool _obscurePassword = true;
  bool _isLoading = false;
  String? _errorMsg;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    final email = _emailCtrl.text.trim();
    final password = _passwordCtrl.text.trim();
    if (email.isEmpty || password.isEmpty) {
      setState(() => _errorMsg = 'Please enter both email and password.');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMsg = null;
    });

    // Supabase Cloud Auth with auto-sign-up fallback
    try {
      final res = await SupabaseConfig.client.auth.signInWithPassword(
        email: email,
        password: password,
      );

      if (res.user != null) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('printpro_local_auth', res.user!.id);
        widget.onLoginSuccess();
        return;
      } else {
        setState(() => _errorMsg = 'Invalid credentials. Please verify your email and password.');
      }
    } catch (e) {
      setState(() => _errorMsg = 'Authentication failed: ${e.toString().replaceAll('Exception:', '')}');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isLargeScreen = constraints.maxWidth >= 850;

          if (isLargeScreen) {
            return Row(
              children: [
                // Left Brand Presentation Panel
                Expanded(
                  flex: 5,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 40),
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Color(0xFF0F172A), // Slate 900
                          Color(0xFF064E3B), // Deep Emerald
                          Color(0xFF047857), // Emerald 700
                        ],
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // Brand Logo
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: AppColors.primaryEmerald,
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: [
                                  BoxShadow(
                                    color: AppColors.primaryEmerald.withValues(alpha: 0.4),
                                    blurRadius: 12,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: const Icon(Icons.point_of_sale, size: 26, color: Colors.white),
                            ),
                            const SizedBox(width: 14),
                            const Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('SimpleBilling', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 22, letterSpacing: -0.4)),
                                Text('Modern POS & ERP Suite', style: TextStyle(color: Colors.white70, fontSize: 12)),
                              ],
                            ),
                          ],
                        ),

                        // Main Feature Points
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'High-Velocity POS Terminal\n& Customer Credit Ledger',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w900,
                                fontSize: 32,
                                height: 1.2,
                                letterSpacing: -0.5,
                              ),
                            ),
                            const SizedBox(height: 24),
                            _buildFeaturePill(Icons.flash_on_rounded, 'Sub-second POS Checkout & Multi-Step Wizard'),
                            _buildFeaturePill(Icons.receipt_long_rounded, 'WhatsApp PDF Sharing & 80mm POS Thermal Printing'),
                            _buildFeaturePill(Icons.account_balance_wallet_rounded, 'Live Customer Dues & Advance Wallet Tracking'),
                            _buildFeaturePill(Icons.cloud_sync_rounded, 'Offline-First Realtime Synchronization Engine'),
                          ],
                        ),

                        // System Version Tag
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: Colors.white24),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.shield_outlined, color: Colors.white70, size: 14),
                              SizedBox(width: 6),
                              Text(
                                'SimpleBilling v2.4.0 • Enterprise FinTech',
                                style: TextStyle(color: Colors.white, fontSize: 11.5, fontWeight: FontWeight.w700),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Right Authentication Form Area
                Expanded(
                  flex: 5,
                  child: Center(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(32),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 420),
                        child: _buildLoginForm(),
                      ),
                    ),
                  ),
                ),
              ],
            );
          }

          // Mobile View
          return Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Column(
                  children: [
                    // Mobile Top Logo Header
                    Container(
                      margin: const EdgeInsets.only(bottom: 24),
                      child: Column(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: AppColors.primaryEmerald,
                              borderRadius: BorderRadius.circular(18),
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.primaryEmerald.withValues(alpha: 0.35),
                                  blurRadius: 16,
                                  offset: const Offset(0, 6),
                                ),
                              ],
                            ),
                            child: const Icon(Icons.point_of_sale, size: 36, color: Colors.white),
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            'SimpleBilling',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w900,
                              color: AppColors.textPrimary,
                              letterSpacing: -0.5,
                            ),
                          ),
                          const SizedBox(height: 2),
                          const Text(
                            'Next-Gen POS & Cloud Ledger',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),

                    _buildLoginForm(),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildFeaturePill(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: Colors.white, size: 18),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(color: Colors.white, fontSize: 13.5, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoginForm() {
    return Container(
      decoration: AppTheme.tactileCardDecoration(elevated: true, borderRadius: 20),
      padding: const EdgeInsets.all(28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.primaryContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.admin_panel_settings_rounded, size: 24, color: AppColors.primaryDark),
              ),
              const SizedBox(width: 12),
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Merchant Sign In', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: AppColors.textPrimary)),
                  Text('Access POS terminal & register', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 20),

          if (_errorMsg != null) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.pastelCoral,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.borderCoral),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error_outline_rounded, color: AppColors.deepCoral, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _errorMsg!,
                      style: const TextStyle(color: AppColors.deepCoral, fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],

          TextField(
            controller: _emailCtrl,
            keyboardType: TextInputType.emailAddress,
            decoration: InputDecoration(
              labelText: 'Email Address',
              hintText: 'admin@shop.com',
              prefixIcon: const Icon(Icons.email_outlined, size: 18, color: AppColors.primaryEmerald),
              filled: true,
              fillColor: AppColors.surfaceVariant,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.border)),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.border)),
            ),
          ),
          const SizedBox(height: 14),

          TextField(
            controller: _passwordCtrl,
            obscureText: _obscurePassword,
            decoration: InputDecoration(
              labelText: 'Password',
              prefixIcon: const Icon(Icons.lock_outline_rounded, size: 18, color: AppColors.primaryEmerald),
              suffixIcon: IconButton(
                icon: Icon(_obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined, size: 20, color: AppColors.textSecondary),
                onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
              ),
              filled: true,
              fillColor: AppColors.surfaceVariant,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.border)),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.border)),
            ),
          ),
          const SizedBox(height: 22),

          // Primary Sign in Button
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryEmerald,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: _isLoading ? null : _handleLogin,
              child: _isLoading
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text('Sign In to Terminal', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
                        SizedBox(width: 6),
                        Icon(Icons.arrow_forward_rounded, size: 18),
                      ],
                    ),
            ),
          ),

          if (widget.onGuestLogin != null) ...[
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              height: 40,
              child: TextButton(
                onPressed: widget.onGuestLogin,
                child: const Text(
                  'Continue as Guest (Offline Mode)',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
