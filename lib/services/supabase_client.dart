import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/config_store.dart';

/// Dynamic Supabase client — equivalent to the React Proxy pattern.
/// Reads credentials from ConfigStore on first use; can be reset
/// when the college changes (e.g. after SetupWizard completes).
class SupabaseClientManager {
  static SupabaseClientManager? _instance;
  static SupabaseClientManager get instance =>
      _instance ??= SupabaseClientManager._();
  SupabaseClientManager._();

  SupabaseClient? _client;

  SupabaseClient get client {
    if (_client != null) return _client!;
    final config = ConfigStore.instance.get();
    if (config == null) {
      throw StateError('Supabase not configured. Complete college setup first.');
    }
    _client = SupabaseClient(config.supabaseUrl, config.supabaseAnonKey);
    return _client!;
  }

  /// Call this after college credentials change.
  void reset() {
    _client = null;
  }

  /// Test that a Supabase project URL is reachable.
  /// Uses the auth health endpoint — no API key required.
  /// Key correctness is verified later when schema creation is attempted.
  static Future<String?> testConnection(String rawUrl, String anonKey) async {
    try {
      var url = rawUrl.trim();
      if (!url.startsWith('http')) url = 'https://$url';
      url = url.replaceAll(RegExp(r'/$'), '');

      // /auth/v1/health returns 200 on any valid Supabase project — no key needed
      final response = await http.get(
        Uri.parse('$url/auth/v1/health'),
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) return null; // success

      // Fallback: try the REST root with the key
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

/// Convenience getter — use this throughout the app.
SupabaseClient get supabase => SupabaseClientManager.instance.client;
