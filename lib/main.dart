import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'core/constants/app_theme.dart';
import 'core/network/realtime_sync_manager.dart';
import 'core/network/supabase_client.dart';
import 'core/network/sync_queue_manager.dart';
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

  @override
  void initState() {
    super.initState();
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
  }

  void _setupRealtime() {
    if (_currentUser == null) return;

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
    return MaterialApp(
      title: 'PrintPro ERP & Billing',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      home: (_currentUser != null || _isGuestMode)
          ? MainShellScreen(onSignOut: () => setState(() {
              _currentUser = null;
              _isGuestMode = false;
            }))
          : LoginScreen(
              onLoginSuccess: () => setState(() => _currentUser = SupabaseConfig.client.auth.currentUser),
              onGuestLogin: () => setState(() => _isGuestMode = true),
            ),
    );
  }
}