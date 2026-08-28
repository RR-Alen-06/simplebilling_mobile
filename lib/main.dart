import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'core/constants/app_colors.dart';
import 'core/network/supabase_client.dart';
import 'presentation/screens/auth/login_screen.dart';
import 'presentation/screens/main_shell_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SupabaseConfig.initialize();

  runApp(
    const ProviderScope(
      child: SimpleBillingApp(),
    ),
  );
}

class SimpleBillingApp extends StatefulWidget {
  const SimpleBillingApp({super.key});

  @override
  State<SimpleBillingApp> createState() => _SimpleBillingAppState();
}

class _SimpleBillingAppState extends State<SimpleBillingApp> {
  User? _currentUser;

  @override
  void initState() {
    super.initState();
    _currentUser = SupabaseConfig.client.auth.currentUser;
    SupabaseConfig.client.auth.onAuthStateChange.listen((data) {
      if (mounted) {
        setState(() {
          _currentUser = data.session?.user;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PrintPro ERP & Billing',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.primary,
          primary: AppColors.primary,
          secondary: AppColors.secondary,
          surface: AppColors.surface,
        ),
        scaffoldBackgroundColor: AppColors.background,
        fontFamily: 'Roboto',
      ),
      home: _currentUser != null
          ? MainShellScreen(onSignOut: () => setState(() => _currentUser = null))
          : LoginScreen(onLoginSuccess: () => setState(() => _currentUser = SupabaseConfig.client.auth.currentUser)),
    );
  }
}
