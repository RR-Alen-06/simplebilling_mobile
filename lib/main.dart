import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'core/constants/app_colors.dart';
import 'core/network/realtime_sync_manager.dart';
import 'core/network/supabase_client.dart';
import 'core/network/sync_queue_manager.dart';
import 'data/repositories/api_repository.dart';
import 'presentation/screens/auth/login_screen.dart';
import 'presentation/screens/main_shell_screen.dart';
import 'providers/billing_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SupabaseConfig.initialize();
  await SyncQueueManager.instance.initialize();

  runApp(
    const ProviderScope(
      child: SimpleBillingApp(),
    ),
  );
}

class SimpleBillingApp extends ConsumerStatefulWidget {
  const SimpleBillingApp({super.key});

  @override
  ConsumerState<SimpleBillingApp> createState() => _SimpleBillingAppState();
}

class _SimpleBillingAppState extends ConsumerState<SimpleBillingApp> {
  User? _currentUser;
  bool _isGuestMode = false;
  bool _isSandboxAuthenticated = false;

  @override
  void initState() {
    super.initState();
    _checkInitialAuth();
  }

  Future<void> _checkInitialAuth() async {
    final prefs = await SharedPreferences.getInstance();
    final localAuth = prefs.getString('printpro_local_auth');

    if (SupabaseConfig.isMockMode) {
      if (mounted) {
        setState(() {
          _isSandboxAuthenticated = localAuth != null;
        });
      }
      return;
    }

    try {
      _currentUser = SupabaseConfig.client.auth.currentUser;
      _setupRealtime();

      SupabaseConfig.client.auth.onAuthStateChange.listen((data) {
        if (mounted) {
          setState(() {
            _currentUser = data.session?.user;
          });
          if (_currentUser != null) {
            _setupRealtime();
            SyncQueueManager.instance.initialize();
          } else {
            RealtimeSyncManager.instance.unsubscribe();
          }
        }
      });
    } catch (e) {
      debugPrint('Auth initialization error: $e');
    }
  }

  void _setupRealtime() {
    if (SupabaseConfig.isMockMode || _currentUser == null) return;

    RealtimeSyncManager.instance.subscribe(
      onBillsChanged: () {
        ref.invalidate(billsListProvider);
      },
      onCustomersChanged: () {
        ref.invalidate(customersProvider);
      },
      onProductsChanged: () {
        ref.invalidate(productsProvider);
      },
    );
  }

  @override
  void dispose() {
    RealtimeSyncManager.instance.unsubscribe();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isAuthenticated = _currentUser != null || _isGuestMode || _isSandboxAuthenticated;

    return MaterialApp(
      title: 'SimpleBilling - Mobile POS',
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
      home: isAuthenticated
          ? MainShellScreen(
              onSignOut: () async {
                await ApiRepository.signOut();
                if (mounted) {
                  setState(() {
                    _currentUser = null;
                    _isGuestMode = false;
                    _isSandboxAuthenticated = false;
                  });
                }
              },
            )
          : LoginScreen(
              onLoginSuccess: () {
                if (mounted) {
                  setState(() {
                    _isSandboxAuthenticated = true;
                    if (!SupabaseConfig.isMockMode) {
                      try {
                        _currentUser = SupabaseConfig.client.auth.currentUser;
                      } catch (_) {}
                    }
                  });
                }
              },
              onGuestLogin: () {
                if (mounted) {
                  setState(() => _isGuestMode = true);
                }
              },
            ),
    );
  }
}