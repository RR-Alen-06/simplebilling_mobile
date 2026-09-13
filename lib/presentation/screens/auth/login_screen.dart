import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:simplebilling_mobile/core/constants/app_colors.dart';
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
  final TextEditingController _emailCtrl = TextEditingController(text: 'admin@shop.com');
  final TextEditingController _passwordCtrl = TextEditingController(text: 'admin123');
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

    // 1. Check Built-in Master Admin Bypass
    if ((email == 'admin@shop.com' || email == 'admin@simplebilling.com') &&
        (password == 'admin123' || password == '123456')) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('printpro_local_auth', 'authenticated');
      widget.onLoginSuccess();
      return;
    }

    // 2. Supabase Cloud Auth with auto-sign-up fallback
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
      }
    } catch (e) {
      try {
        final signUpRes = await SupabaseConfig.client.auth.signUp(
          email: email,
          password: password,
        );
        if (signUpRes.user != null) {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('printpro_local_auth', signUpRes.user!.id);
          widget.onLoginSuccess();
          return;
        }
      } catch (_) {}

      setState(() => _errorMsg = 'Authentication error: ${e.toString().replaceAll('Exception:', '')}');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleQuickDemoLogin() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('printpro_local_auth', 'demo_admin_session');
    widget.onLoginSuccess();
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
                // Left Brand Panel
                Expanded(
                  flex: 5,
                  child: Container(
                    padding: const EdgeInsets.all(40),
                    decoration: const BoxDecoration(
                      color: AppColors.deepLavender,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(Icons.print_rounded, size: 28, color: AppColors.deepLavender),
                            ),
                            const SizedBox(width: 12),
                            const Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('SimpleBilling ERP', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 20)),
                                Text('Xerox, Print & Retail Edition', style: TextStyle(color: Colors.white70, fontSize: 12)),
                              ],
                            ),
                          ],
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'High-Velocity POS Terminal\n& Customer Credit Ledger',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w900,
                                fontSize: 28,
                                height: 1.25,
                              ),
                            ),
                            const SizedBox(height: 16),
                            _buildFeaturePill(Icons.speed_rounded, 'Real-time Sub-second POS Checkout Terminal'),
                            _buildFeaturePill(Icons.receipt_long_rounded, 'Dynamic 80mm/58mm Thermal & A4 Tax Invoicing'),
                            _buildFeaturePill(Icons.account_balance_wallet_rounded, 'Customer Credit Ledgers & Advance Drawdowns'),
                            _buildFeaturePill(Icons.offline_bolt_rounded, 'Offline-First Local Sync Engine with Supabase Cloud'),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: Colors.white24),
                          ),
                          child: const Text(
                            'SimpleBilling Engine v2.4.0 • Enterprise Ready',
                            style: TextStyle(color: Colors.white, fontSize: 11.5, fontWeight: FontWeight.w700),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                // Right Authentication Form
                Expanded(
                  flex: 5,
                  child: Center(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(32),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 400),
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
              padding: const EdgeInsets.all(20),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: _buildLoginForm(),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildFeaturePill(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: Colors.white, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoginForm() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.border, width: 2),
        boxShadow: const [
          BoxShadow(color: AppColors.shadowLight, offset: Offset(4, 4), blurRadius: 0),
        ],
      ),
      padding: const EdgeInsets.all(28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.pastelLavender,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.borderLavender, width: 1.5),
                ),
                child: const Icon(Icons.lock_rounded, size: 28, color: AppColors.deepLavender),
              ),
              const SizedBox(width: 12),
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Admin Login', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 20, color: AppColors.textPrimary)),
                  Text('Sign in to access POS billing terminal', style: TextStyle(color: AppColors.textSecondary, fontSize: 11.5)),
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
                border: Border.all(color: AppColors.deepCoral),
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
              labelText: 'Admin Email',
              prefixIcon: const Icon(Icons.email_outlined, size: 18, color: AppColors.primary),
              filled: true,
              fillColor: AppColors.background,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.border)),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.border)),
            ),
          ),
          const SizedBox(height: 12),

          TextField(
            controller: _passwordCtrl,
            obscureText: true,
            decoration: InputDecoration(
              labelText: 'Password',
              prefixIcon: const Icon(Icons.lock_outline_rounded, size: 18, color: AppColors.primary),
              filled: true,
              fillColor: AppColors.background,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.border)),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.border)),
            ),
          ),
          const SizedBox(height: 20),

          // Sign in button
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.deepLavender,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: _isLoading ? null : _handleLogin,
              child: _isLoading
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Text('Sign In to Account', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
            ),
          ),
          const SizedBox(height: 12),

          // ⚡ Quick Demo Login Preset
          SizedBox(
            width: double.infinity,
            height: 46,
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.deepMint,
                backgroundColor: AppColors.pastelMint,
                side: const BorderSide(color: AppColors.borderMint, width: 1.5),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              icon: const Icon(Icons.bolt_rounded, size: 20, color: AppColors.deepMint),
              label: const Text('⚡ Quick Demo Login (admin@shop.com)', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12.5)),
              onPressed: _handleQuickDemoLogin,
            ),
          ),
        ],
      ),
    );
  }
}
