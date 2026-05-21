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

  /// Test a connection without caching it.
  static Future<bool> testConnection(String url, String anonKey) async {
    try {
      final testClient = SupabaseClient(url, anonKey);
      await testClient.from('profiles').select('id').limit(1);
      return true;
    } catch (_) {
      return false;
    }
  }
}

/// Convenience getter — use this throughout the app.
SupabaseClient get supabase => SupabaseClientManager.instance.client;
