import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseConfig {
  SupabaseConfig._();

  static String _safeDotEnv(String key) {
    try {
      if (dotenv.isInitialized) {
        return dotenv.maybeGet(key) ?? '';
      }
    } catch (_) {
      // Ignored - DotEnv not loaded or failed
    }
    return '';
  }

  static String get supabaseUrl {
    const fromEnv = String.fromEnvironment('SUPABASE_URL', defaultValue: '');
    if (fromEnv.isNotEmpty) return fromEnv;
    return _safeDotEnv('SUPABASE_URL');
  }

  static String get supabasePublishableKey {
    const fromEnv = String.fromEnvironment('SUPABASE_PUBLISHABLE_KEY', defaultValue: '');
    if (fromEnv.isNotEmpty) return fromEnv;
    return _safeDotEnv('SUPABASE_PUBLISHABLE_KEY');
  }

  static bool get isConfigured =>
      supabaseUrl.isNotEmpty && supabasePublishableKey.isNotEmpty;

  static bool get isInitialized {
    try {
      Supabase.instance.client;
      return true;
    } catch (_) {
      return false;
    }
  }

  static Future<void> initialize() async {
    try {
      try {
        await dotenv.load(fileName: '.env');
      } catch (e) {
        debugPrint('No local .env file found or failed to load: $e');
      }

      final url = supabaseUrl;
      final key = supabasePublishableKey;

      if (url.isNotEmpty && key.isNotEmpty) {
        await Supabase.initialize(
          url: url,
          publishableKey: key,
        );
        debugPrint('Supabase initialized successfully in simplebilling_mobile');
      } else {
        debugPrint('Supabase credentials not configured (SUPABASE_URL / SUPABASE_PUBLISHABLE_KEY missing).');
      }
    } catch (e) {
      debugPrint('Error initializing Supabase: $e');
    }
  }

  static SupabaseClient get client {
    if (!isInitialized) {
      throw StateError(
        'Supabase is not initialized. Verify credentials or check SupabaseConfig.isInitialized first.',
      );
    }
    return Supabase.instance.client;
  }
}