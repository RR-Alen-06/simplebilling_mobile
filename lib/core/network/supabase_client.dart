import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseConfig {
  SupabaseConfig._();

  static const String _defaultUrl = 'https://hngmiuoqgefwkyesburm.supabase.co';
  static const String _defaultKey = 'sb_publishable_L5GGO39t_5VbiWK0V059fQ_Ghaz6PPw';

  static String get supabaseUrl =>
      dotenv.env['SUPABASE_URL'] ??
      (const String.fromEnvironment('SUPABASE_URL', defaultValue: '').isNotEmpty
          ? const String.fromEnvironment('SUPABASE_URL')
          : _defaultUrl);

  static String get supabasePublishableKey =>
      dotenv.env['SUPABASE_PUBLISHABLE_KEY'] ??
      (const String.fromEnvironment('SUPABASE_PUBLISHABLE_KEY', defaultValue: '').isNotEmpty
          ? const String.fromEnvironment('SUPABASE_PUBLISHABLE_KEY')
          : _defaultKey);

  static bool get isInitialized {
    try {
      Supabase.instance;
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
        debugPrint('No local .env file found or failed to load, using default config: $e');
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
      debugPrint('Error initializing Supabase: $e');
    }
  }

  static SupabaseClient get client => Supabase.instance.client;
}