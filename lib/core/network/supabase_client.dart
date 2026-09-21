import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:simplebilling_mobile/data/mock/mock_data_store.dart';

class SupabaseConfig {
  SupabaseConfig._();

  static bool? _mockModeOverride;

  static String get supabaseUrl =>
      dotenv.env['SUPABASE_URL'] ??
      const String.fromEnvironment('SUPABASE_URL', defaultValue: '');

  static String get supabasePublishableKey =>
      dotenv.env['SUPABASE_PUBLISHABLE_KEY'] ??
      const String.fromEnvironment('SUPABASE_PUBLISHABLE_KEY', defaultValue: '');

  static bool get isMockMode {
    if (_mockModeOverride != null) return _mockModeOverride!;
    
    final envMock = dotenv.env['MOCK_MODE']?.trim().toLowerCase();
    if (envMock == 'true' || envMock == '1') return true;
    
    const bool fromDefine = bool.fromEnvironment('MOCK_MODE', defaultValue: false);
    if (fromDefine) return true;

    final url = supabaseUrl;
    final key = supabasePublishableKey;
    if (url.isEmpty ||
        key.isEmpty ||
        url.contains('your-project.supabase.co') ||
        key.contains('your-supabase-publishable-key')) {
      return true;
    }

    return false;
  }

  static void setMockMode(bool enabled) {
    _mockModeOverride = enabled;
  }

  static Future<void> initialize() async {
    try {
      try {
        await dotenv.load(fileName: '.env');
      } catch (e) {
        debugPrint('No local .env file found or failed to load, falling back to --dart-define');
      }

      await MockDataStore.instance.initialize();

      if (isMockMode) {
        debugPrint('🧪 SimpleBilling running in ISOLATED SANDBOX / MOCK MODE. Live DB is protected.');
        return;
      }

      final url = supabaseUrl;
      final key = supabasePublishableKey;

      if (url.isNotEmpty && key.isNotEmpty) {
        await Supabase.initialize(
          url: url,
          publishableKey: key,
        );
        debugPrint('Supabase initialized successfully in simplebilling_mobile');
      }
    } catch (e) {
      debugPrint('Error initializing Supabase (fallback to sandbox): $e');
    }
  }

  static SupabaseClient get client => Supabase.instance.client;
}