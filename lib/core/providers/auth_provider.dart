import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/models.dart';
import '../../services/supabase_client.dart';
import '../../config/config_store.dart';

class AuthState {
  final Profile? user;
  final bool isLoading;
  final String? error;

  const AuthState({this.user, this.isLoading = false, this.error});

  bool get isAuthenticated => user != null;

  AuthState copyWith({Profile? user, bool? isLoading, String? error, bool clearUser = false}) =>
      AuthState(
        user: clearUser ? null : (user ?? this.user),
        isLoading: isLoading ?? this.isLoading,
        error: error,
      );
}

class AuthNotifier extends StateNotifier<AuthState> {
  AuthNotifier() : super(const AuthState(isLoading: true)) {
    initialize();
  }

  bool _initialized = false;

  void initialize() async {
    // Guard against duplicate stream subscriptions
    if (_initialized) return;
    _initialized = true;

    state = const AuthState(isLoading: true);
    try {
      // The onAuthStateChange stream fires AuthChangeEvent.initialSession
      // immediately on listen — with the cached session if one exists in
      // browser localStorage (via Supabase.initialize), or null if not.
      supabase.auth.onAuthStateChange.listen((data) async {
        final event = data.event;
        final session = data.session;
        if ((event == AuthChangeEvent.signedIn ||
            event == AuthChangeEvent.initialSession ||
            event == AuthChangeEvent.tokenRefreshed) &&
            session != null) {
          state = const AuthState(isLoading: true);
          await _fetchProfile(session.user.id);
          if (state.isLoading) state = state.copyWith(isLoading: false);
        } else if (event == AuthChangeEvent.signedOut) {
          state = const AuthState();
        } else if (event == AuthChangeEvent.initialSession && session == null) {
          state = const AuthState(); // no cached session — go to login
        }
      });
    } catch (_) {
      state = const AuthState();
    }
  }

  Future<void> _fetchProfile(String userId) async {
    try {
      final res = await supabase
          .from('profiles')
          .select()
          .eq('id', userId)
          .maybeSingle();
      if (res != null) {
        state = AuthState(user: Profile.fromJson(res), isLoading: false);
        return;
      }
    } catch (_) {
    }
    try {
      final authUser = supabase.auth.currentUser;
      if (authUser != null) {
        final meta = authUser.userMetadata ?? {};
        final name = (meta['full_name'] as String? ?? authUser.email ?? 'User');
        final parts = name.trim().split(' ');
        final role = (meta['role'] as String?)?.trim();
        state = AuthState(
          user: Profile(
            id: authUser.id,
            firstName: parts.first,
            lastName: parts.length > 1 ? parts.skip(1).join(' ') : '',
            role: (role != null && role.isNotEmpty) ? role : 'student',
            isActive: true,
            createdAt: DateTime.now(),
          ),
          isLoading: false,
        );
      }
    } catch (_) {}
  }

  Future<String?> login(String email, String password) async {
    state = const AuthState(isLoading: true);
    try {
      final res = await supabase.auth.signInWithPassword(
        email: email,
        password: password,
      );
      if (res.user != null) {
        await _fetchProfile(res.user!.id);
        if (!state.isAuthenticated) {
          final meta = res.user!.userMetadata ?? {};
          final name = (meta['full_name'] as String? ?? email);
          final parts = name.trim().split(' ');
          final role = (meta['role'] as String?)?.trim();
          state = AuthState(
            user: Profile(
              id: res.user!.id,
              firstName: parts.first,
              lastName: parts.length > 1 ? parts.skip(1).join(' ') : '',
              role: (role != null && role.isNotEmpty) ? role : 'student',
              isActive: true,
              createdAt: DateTime.now(),
            ),
            isLoading: false,
          );
        }
        return null; // success
      }
      state = const AuthState(isLoading: false);
      return 'Login failed. Please try again.';
    } on AuthException catch (e) {
      state = AuthState(isLoading: false, error: e.message);
      return e.message;
    } catch (e) {
      state = AuthState(isLoading: false, error: e.toString());
      return e.toString();
    }
  }

  Future<void> logout() async {
    state = const AuthState();
    try {
      await supabase.auth.signOut();
    } catch (_) {}
  }

  Future<String?> createUser({
    required String email,
    required String password,
    required Map<String, dynamic> profileData,
  }) async {
    try {
      final config = await _getConfig();
      final serviceKey = config.$3; // service role key

      if (serviceKey != null && serviceKey.isNotEmpty) {
        final base = config.$1.replaceAll(RegExp(r'/$'), '');
        final authRes = await http.post(
          Uri.parse('$base/auth/v1/admin/users'),
          headers: {
            'Content-Type': 'application/json',
            'apikey': serviceKey,
            'Authorization': 'Bearer $serviceKey',
          },
          body: jsonEncode({
            'email': email,
            'password': password,
            'email_confirm': true,
            'user_metadata': profileData,
          }),
        );
        if (authRes.statusCode > 299) {
          return 'Failed to create user: ${authRes.body}';
        }
        final userId = jsonDecode(authRes.body)['id'] as String;
        await supabase.from('profiles').insert({
          'id': userId,
          'email': email,
          ...profileData,
        });
        return null;
      } else {
        final isolatedClient = SupabaseClient(
          config.$1, config.$2,
          authOptions: const FlutterAuthClientOptions(
            authFlowType: AuthFlowType.implicit,
            autoRefreshToken: false,
          ),
        );
        final res = await isolatedClient.auth.signUp(
          email: email, password: password, data: profileData,
        );
        if (res.user == null) return 'Failed to create auth user';
        await supabase.from('profiles').insert({
          'id': res.user!.id,
          'email': email,
          ...profileData,
        });
        return null;
      }
    } catch (e) {
      return e.toString();
    }
  }

  Future<String?> deleteUser(String userId) async {
    try {
      final config = await _getConfig();
      final serviceKey = config.$3;
      final base = config.$1.replaceAll(RegExp(r'/$'), '');

      // Delete from auth.users via Admin API (requires service role key)
      if (serviceKey != null && serviceKey.isNotEmpty) {
        final authRes = await http.delete(
          Uri.parse('$base/auth/v1/admin/users/$userId'),
          headers: {
            'apikey': serviceKey,
            'Authorization': 'Bearer $serviceKey',
          },
        );
        if (authRes.statusCode > 299) {
          return 'Failed to delete auth user: ${authRes.body}';
        }
      }

      // Also explicitly delete from profiles (handles cases without cascade)
      await supabase.from('profiles').delete().eq('id', userId);
      return null;
    } catch (e) {
      return e.toString();
    }
  }

  Future<(String, String, String?)> _getConfig() async {
    final cfg = ConfigStore.instance.get();
    if (cfg == null) throw StateError('No college config found');
    return (cfg.supabaseUrl, cfg.supabaseAnonKey, cfg.serviceRoleKey);
  }
}

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>(
  (ref) => AuthNotifier(),
);

final currentUserProvider = Provider<Profile?>(
  (ref) => ref.watch(authProvider).user,
);

