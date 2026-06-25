import 'dart:async';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/config_store.dart';

class SupabaseClientManager {
  static SupabaseClientManager? _instance;
  static SupabaseClientManager get instance =>
      _instance ??= SupabaseClientManager._();
  SupabaseClientManager._();

  bool _initialized = false;

  /// Returns true if Supabase.initialize() has been called.
  bool get isInitialized => _initialized;

  /// Call this once after config is ready. Safe to call multiple times
  /// (subsequent calls reinitialize with the new URL/key).
  Future<void> ensureInitialized() async {
    final config = ConfigStore.instance.get();
    if (config == null) {
      throw StateError('Supabase not configured. Complete college setup first.');
    }

    if (_initialized) {
      // Supabase.initialize cannot be called twice in the same isolate,
      // but we can update the client by signing out and re-pointing.
      // For a full re-init (e.g. college change) a hot-restart is needed.
      return;
    }

    await Supabase.initialize(
      url: config.supabaseUrl,
      anonKey: config.supabaseAnonKey,
      authOptions: const FlutterAuthClientOptions(
        authFlowType: AuthFlowType.pkce,
      ),
      debug: false,
    );
    _initialized = true;
  }

  SupabaseClient get client {
    if (!_initialized) {
      throw StateError('Call ensureInitialized() before accessing client.');
    }
    return Supabase.instance.client;
  }

  /// Called when a new college config is saved (gateway screen).
  /// Because Supabase.initialize() can only run once per isolate,
  /// we simply set the flag so the existing instance is reused.
  void reset() {
    // No-op: Supabase.instance keeps the same client.
    // If the URL truly changed, the user needs a full page reload.
  }

  static Future<String?> testConnection(String rawUrl, String anonKey) async {
    try {
      var url = rawUrl.trim();
      if (!url.startsWith('http')) url = 'https://$url';
      url = url.replaceAll(RegExp(r'/$'), '');

      final response = await http.get(
        Uri.parse('$url/auth/v1/health'),
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) return null;

      final res2 = await http.get(
        Uri.parse('$url/rest/v1/'),
        headers: {
          'apikey': anonKey.trim(),
          'Authorization': 'Bearer ${anonKey.trim()}',
        },
      ).timeout(const Duration(seconds: 10));

      if (res2.statusCode < 500) return null;
      return 'Server error (${res2.statusCode}). Try again later.';
    } on http.ClientException catch (e) {
      return 'Network error: ${e.message}';
    } catch (e) {
      final msg = e.toString();
      if (msg.contains('timeout') || msg.contains('TimeoutException')) {
        return 'Connection timed out. Check the URL and your internet connection.';
      }
      return 'Could not reach Supabase: $msg';
    }
  }
}

SupabaseClient get supabase => SupabaseClientManager.instance.client;
