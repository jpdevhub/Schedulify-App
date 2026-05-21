import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/models.dart';
import '../../services/supabase_client.dart';
import '../../config/config_store.dart';

// ── Auth State ─────────────────────────────────────────────────────────────

class AuthState {
  final Profile? user;
  final bool isLoading;
  final String? error;

  const AuthState({this.user, this.isLoading = false, this.error});

  bool get isAuthenticated => user != null;
  AuthState copyWith({Profile? user, bool? isLoading, String? error}) =>
      AuthState(
        user: user ?? this.user,
        isLoading: isLoading ?? this.isLoading,
        error: error,
      );
}

// ── Auth Notifier ──────────────────────────────────────────────────────────

class AuthNotifier extends StateNotifier<AuthState> {
  AuthNotifier() : super(const AuthState(isLoading: true)) {
    _init();
  }

  void _init() async {
    try {
      final session = supabase.auth.currentSession;
      if (session != null) {
        await _fetchProfile(session.user.id);
      }
    } catch (_) {
      // not configured yet — silently ignore
    } finally {
      state = state.copyWith(isLoading: false);
    }

    // Listen for auth changes
    try {
      supabase.auth.onAuthStateChange.listen((data) async {
        final event = data.event;
        final session = data.session;
        if (event == AuthChangeEvent.signedIn && session != null) {
          await _fetchProfile(session.user.id);
        } else if (event == AuthChangeEvent.signedOut) {
          state = const AuthState();
        }
      });
    } catch (_) {}
  }

  Future<void> _fetchProfile(String userId) async {
    final res = await supabase
        .from('profiles')
        .select()
        .eq('id', userId)
        .maybeSingle();
    if (res != null) {
      state = state.copyWith(user: Profile.fromJson(res), isLoading: false);
    }
  }

  Future<String?> login(String email, String password) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final res = await supabase.auth.signInWithPassword(
        email: email,
        password: password,
      );
      if (res.user != null) {
        await _fetchProfile(res.user!.id);
        return null; // success
      }
      return 'Login failed';
    } on AuthException catch (e) {
      state = state.copyWith(isLoading: false, error: e.message);
      return e.message;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      return e.toString();
    }
  }

  Future<void> logout() async {
    try {
      await supabase.auth.signOut();
    } catch (_) {}
    state = const AuthState();
  }

  /// Create a new user without disrupting admin session.
  /// Uses an isolated Supabase client (no session persistence).
  Future<String?> createUser({
    required String email,
    required String password,
    required Map<String, dynamic> profileData,
  }) async {
    try {
      final config = await _getConfig();
      final isolatedClient = SupabaseClient(
        config.$1,
        config.$2,
        authOptions: const FlutterAuthClientOptions(
          authFlowType: AuthFlowType.pkce,
          autoRefreshToken: false,
        ),
      );
      final res = await isolatedClient.auth.signUp(
        email: email,
        password: password,
      );
      if (res.user == null) return 'Failed to create auth user';
      await supabase.from('profiles').insert({
        'id': res.user!.id,
        ...profileData,
      });
      return null;
    } catch (e) {
      return e.toString();
    }
  }

  Future<(String, String)> _getConfig() async {
    final cfg = ConfigStore.instance.get();
    if (cfg == null) throw StateError('No college config found');
    return (cfg.supabaseUrl, cfg.supabaseAnonKey);
  }
}

// ── Providers ──────────────────────────────────────────────────────────────

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>(
  (ref) => AuthNotifier(),
);

final currentUserProvider = Provider<Profile?>(
  (ref) => ref.watch(authProvider).user,
);
