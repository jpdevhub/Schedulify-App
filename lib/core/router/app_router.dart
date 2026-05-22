import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/auth_provider.dart';
import '../../config/config_store.dart';
import '../../features/gateway/screens/gateway_screen.dart';
import '../../features/setup/screens/setup_wizard_screen.dart';
import '../../features/auth/screens/login_screen.dart';
import '../../features/admin/screens/admin_shell.dart';
import '../../features/faculty/screens/faculty_dashboard.dart';
import '../../features/student/screens/student_dashboard.dart';

// ── Router Notifier ────────────────────────────────────────────────────────
// Bridges Riverpod auth state → GoRouter's refreshListenable.
// This prevents GoRouter from being RECREATED on every auth change
// (which was causing the "refresh" bug).

class _RouterNotifier extends ChangeNotifier {
  _RouterNotifier(this._ref) {
    _ref.listen<AuthState>(authProvider, (_, __) => notifyListeners());
  }

  final Ref _ref;

  String? redirect(BuildContext context, GoRouterState routerState) {
    final authState = _ref.read(authProvider);
    final configReady = ConfigStore.instance.isReady;
    final isAuthenticated = authState.isAuthenticated;
    final isLoading = authState.isLoading;
    final path = routerState.uri.path;

    // Still initializing — don't redirect yet
    if (isLoading) return null;

    // Not configured → only gateway and setup are allowed
    if (!configReady && path != '/' && path != '/setup') return '/';

    // Configured, not logged in → go to login (only from gateway)
    if (configReady && !isAuthenticated && path == '/') return '/login';

    // Logged in → can't go back to gateway or login
    if (isAuthenticated && (path == '/' || path == '/login')) {
      return _roleHome(authState.user?.role ?? 'student');
    }

    return null;
  }
}

// ── Router Provider ────────────────────────────────────────────────────────
// GoRouter is created ONCE. Auth changes trigger redirect via refreshListenable,
// NOT by recreating the router.

final routerProvider = Provider<GoRouter>((ref) {
  final notifier = _RouterNotifier(ref);

  return GoRouter(
    initialLocation: '/',
    refreshListenable: notifier,
    redirect: notifier.redirect,
    routes: [
      GoRoute(path: '/', builder: (_, __) => const GatewayScreen()),
      GoRoute(path: '/setup', builder: (_, __) => const SetupWizardScreen()),
      GoRoute(path: '/login', builder: (_, __) => const LoginScreen()),
      GoRoute(
        path: '/admin',
        builder: (_, __) => const AdminShell(),
        routes: [
          GoRoute(
            path: 'upload',
            builder: (_, __) => const AdminShell(initialSection: 'upload'),
          ),
        ],
      ),
      GoRoute(path: '/faculty', builder: (_, __) => const FacultyDashboard()),
      GoRoute(path: '/student', builder: (_, __) => const StudentDashboard()),
    ],
    errorBuilder: (_, state) => Scaffold(
      body: Center(child: Text('Page not found: ${state.uri}')),
    ),
  );
});

String _roleHome(String role) {
  switch (role) {
    case 'super_admin':
    case 'admin':
      return '/admin';
    case 'faculty':
      return '/faculty';
    default:
      return '/student';
  }
}
