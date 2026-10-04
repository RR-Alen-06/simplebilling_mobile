import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'core/constants/app_colors.dart';
import 'core/constants/app_theme.dart';
import 'core/network/realtime_sync_manager.dart';
import 'core/network/supabase_client.dart';
import 'core/network/sync_queue_manager.dart';
import 'core/utils/app_logger.dart';
import 'presentation/screens/auth/login_screen.dart';
import 'presentation/screens/main_shell_screen.dart';
import 'providers/billing_provider.dart';

void main() {
  runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();

    FlutterError.onError = (FlutterErrorDetails details) {
      FlutterError.presentError(details);
      AppLogger.error('Flutter Error: ${details.exceptionAsString()}', details.exception, details.stack);
    };

    ErrorWidget.builder = (FlutterErrorDetails details) {
      return _GlobalFriendlyErrorWidget(details: details);
    };

    await SupabaseConfig.initialize();
    await SyncQueueManager.instance.initialize();

    runApp(
      const ProviderScope(
        child: SimpleBillingApp(),
      ),
    );
  }, (error, stack) {
    AppLogger.error('Uncaught Zoned Exception', error, stack);
  });
}

class SimpleBillingApp extends ConsumerStatefulWidget {
  const SimpleBillingApp({super.key});

  @override
  ConsumerState<SimpleBillingApp> createState() => _SimpleBillingAppState();
}

class _SimpleBillingAppState extends ConsumerState<SimpleBillingApp> {
  User? _currentUser;
  bool _isLocalAuth = false;
  bool _isGuestMode = false;
  StreamSubscription<AuthState>? _authSubscription;

  @override
  void initState() {
    super.initState();
    if (SupabaseConfig.isInitialized) {
      try {
        _currentUser = SupabaseConfig.client.auth.currentUser;
        _setupRealtime();

        _authSubscription = SupabaseConfig.client.auth.onAuthStateChange.listen((data) {
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
      } catch (e, stack) {
        AppLogger.error('Error attaching Supabase auth state listener', e, stack);
      }
    }
  }

  void _setupRealtime() {
    if (_currentUser == null || !SupabaseConfig.isInitialized) return;

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
    _authSubscription?.cancel();
    RealtimeSyncManager.instance.unsubscribe();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool isAuthenticated = _currentUser != null || _isLocalAuth || _isGuestMode;

    return MaterialApp(
      title: 'SimpleBilling ERP',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      home: isAuthenticated
          ? MainShellScreen(
              onSignOut: () async {
                if (SupabaseConfig.isInitialized) {
                  try {
                    await SupabaseConfig.client.auth.signOut();
                  } catch (e, stack) {
                    AppLogger.warn('Error during Supabase sign out', e, stack);
                  }
                }
                if (mounted) {
                  setState(() {
                    _currentUser = null;
                    _isLocalAuth = false;
                    _isGuestMode = false;
                  });
                }
              },
            )
          : LoginScreen(
              onLoginSuccess: () {
                User? user;
                if (SupabaseConfig.isInitialized) {
                  try {
                    user = SupabaseConfig.client.auth.currentUser;
                  } catch (e, stack) {
                    AppLogger.warn('Error accessing current user on login', e, stack);
                  }
                }
                setState(() {
                  _currentUser = user;
                  if (user == null) {
                    _isLocalAuth = true;
                  }
                });
              },
              onGuestLogin: () => setState(() => _isGuestMode = true),
            ),
    );
  }
}

class _GlobalFriendlyErrorWidget extends StatelessWidget {
  final FlutterErrorDetails details;
  const _GlobalFriendlyErrorWidget({required this.details});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.background,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.error_outline_rounded,
                      color: AppColors.deepCoral,
                      size: 48,
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Something went wrong',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'An unexpected interface error occurred. The application remains running.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryEmerald,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      icon: const Icon(Icons.refresh_rounded),
                      label: const Text('Reload UI'),
                      onPressed: () {
                        // Re-trigger rebuild
                        (context as Element).markNeedsBuild();
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}