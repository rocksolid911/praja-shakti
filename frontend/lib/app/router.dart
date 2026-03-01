import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../core/utils/responsive.dart';
import '../features/auth/cubit/auth_cubit.dart';
import '../features/auth/cubit/auth_state.dart';
import '../core/models/user.dart';
import '../l10n/app_localizations.dart';
import '../features/auth/screens/login_screen.dart';
import '../features/auth/screens/otp_screen.dart';
import '../features/auth/screens/profile_screen.dart';
import '../features/map/screens/map_screen.dart';
import '../features/report/screens/report_screen.dart';
import '../features/report/screens/report_detail_screen.dart';
import '../features/community/screens/community_feed_screen.dart';
import '../features/projects/screens/project_list_screen.dart';
import '../features/projects/screens/project_detail_screen.dart';
import '../features/schemes/screens/scheme_explorer_screen.dart';
import '../features/dashboard/screens/leader_dashboard_screen.dart';
import '../features/gram_sabha/screens/gram_sabha_screen.dart';
import '../features/dashboard/screens/government_dashboard_screen.dart';
import '../features/auth/screens/user_management_screen.dart';

GoRouter createRouter(AuthCubit authCubit) {
  return GoRouter(
    initialLocation: '/login',
    refreshListenable: _AuthNotifier(authCubit),
    redirect: (context, state) {
      final authState = authCubit.state;
      // AuthLoading and AuthProfileLoaded are also valid authenticated states
      final isAuthenticated = authState is AuthAuthenticated ||
          authState is AuthProfileLoaded ||
          authState is AuthLoading;
      final isOnAuthPage = state.uri.path == '/login' || state.uri.path == '/otp';

      if (!isAuthenticated && !isOnAuthPage) return '/login';
      if (authState is AuthAuthenticated && isOnAuthPage) {
        final user = (authState as AuthAuthenticated).user;
        return user.isGovernment ? '/gov-dashboard' : '/map';
      }
      return null;
    },
    routes: [
      GoRoute(path: '/login', builder: (_, __) => const LoginScreen()),
      GoRoute(
        path: '/otp',
        builder: (_, state) {
          final extra = state.extra as Map<String, dynamic>? ?? {};
          return OTPScreen(
            phone: extra['phone'] as String? ?? '',
            otpDebug: extra['otpDebug'] as String?,
          );
        },
      ),
      GoRoute(path: '/profile', builder: (_, __) => const ProfileScreen()),
      ShellRoute(
        builder: (context, state, child) => AppShell(child: child),
        routes: [
          GoRoute(path: '/map', builder: (_, __) => const MapScreen()),
          GoRoute(path: '/report', builder: (_, __) => const ReportScreen()),
          GoRoute(
            path: '/report/:id',
            builder: (_, state) => ReportDetailScreen(
              reportId: int.parse(state.pathParameters['id']!),
            ),
          ),
          GoRoute(path: '/feed', builder: (_, __) => const CommunityFeedScreen()),
          GoRoute(path: '/projects', builder: (_, __) => const ProjectListScreen()),
          GoRoute(
            path: '/project/:id',
            builder: (_, state) => ProjectDetailScreen(
              projectId: int.parse(state.pathParameters['id']!),
            ),
          ),
          GoRoute(path: '/schemes', builder: (_, __) => const SchemeExplorerScreen()),
          GoRoute(path: '/dashboard', builder: (_, __) => const LeaderDashboardScreen()),
          GoRoute(path: '/gramsabha', builder: (_, __) => const GramSabhaScreen()),
          GoRoute(path: '/gov-dashboard', builder: (_, __) => const GovernmentDashboardScreen()),
          GoRoute(path: '/users', builder: (_, __) => const UserManagementScreen()),
        ],
      ),
    ],
  );
}

/// Notifies GoRouter when auth state changes so it can re-run redirect
class _AuthNotifier extends ChangeNotifier {
  _AuthNotifier(AuthCubit authCubit) {
    authCubit.stream.listen((_) => notifyListeners());
  }
}

class _NavItem {
  final IconData icon;
  final String label;
  final String path;
  const _NavItem(this.icon, this.label, this.path);
}

class AppShell extends StatefulWidget {
  final Widget child;
  const AppShell({super.key, required this.child});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  // ── Citizen nav ──────────────────────────────────────────────────
  static const _citizenRail = [
    _NavItem(Icons.map, 'Map', '/map'),
    _NavItem(Icons.mic, 'Report', '/report'),
    _NavItem(Icons.people, 'Feed', '/feed'),
    _NavItem(Icons.search, 'Schemes', '/schemes'),
  ];
  static const _citizenBottom = [
    _NavItem(Icons.map, 'Map', '/map'),
    _NavItem(Icons.mic, 'Report', '/report'),
    _NavItem(Icons.people, 'Feed', '/feed'),
    _NavItem(Icons.search, 'Schemes', '/schemes'),
  ];
  static const _citizenMore = [
    _NavItem(Icons.person, 'Profile', '/profile'),
  ];

  // ── Leader nav ────────────────────────────────────────────────────
  static const _leaderRail = [
    _NavItem(Icons.map, 'Map', '/map'),
    _NavItem(Icons.mic, 'Report', '/report'),
    _NavItem(Icons.people, 'Feed', '/feed'),
    _NavItem(Icons.groups, 'Gram Sabha', '/gramsabha'),
    _NavItem(Icons.dashboard, 'Dashboard', '/dashboard'),
    _NavItem(Icons.construction, 'Projects', '/projects'),
    _NavItem(Icons.search, 'Schemes', '/schemes'),
  ];
  static const _leaderBottom = [
    _NavItem(Icons.map, 'Map', '/map'),
    _NavItem(Icons.mic, 'Report', '/report'),
    _NavItem(Icons.people, 'Feed', '/feed'),
    _NavItem(Icons.groups, 'Gram Sabha', '/gramsabha'),
  ];
  static const _leaderMore = [
    _NavItem(Icons.dashboard, 'Dashboard', '/dashboard'),
    _NavItem(Icons.construction, 'Projects', '/projects'),
    _NavItem(Icons.search, 'Schemes', '/schemes'),
    _NavItem(Icons.manage_accounts, 'Manage Users', '/users'),
    _NavItem(Icons.person, 'Profile', '/profile'),
  ];

  // ── Government nav ────────────────────────────────────────────────
  static const _govRail = [
    _NavItem(Icons.map, 'Map', '/map'),
    _NavItem(Icons.people, 'Feed', '/feed'),
    _NavItem(Icons.dashboard_customize, 'Gov Dashboard', '/gov-dashboard'),
    _NavItem(Icons.construction, 'Projects', '/projects'),
    _NavItem(Icons.search, 'Schemes', '/schemes'),
    _NavItem(Icons.groups, 'Gram Sabha', '/gramsabha'),
  ];
  static const _govBottom = [
    _NavItem(Icons.map, 'Map', '/map'),
    _NavItem(Icons.people, 'Feed', '/feed'),
    _NavItem(Icons.dashboard_customize, 'Dashboard', '/gov-dashboard'),
    _NavItem(Icons.construction, 'Projects', '/projects'),
  ];
  static const _govMore = [
    _NavItem(Icons.search, 'Schemes', '/schemes'),
    _NavItem(Icons.groups, 'Gram Sabha', '/gramsabha'),
    _NavItem(Icons.person, 'Profile', '/profile'),
  ];

  User? _currentUser() {
    final s = context.read<AuthCubit>().state;
    if (s is AuthAuthenticated) return s.user;
    if (s is AuthProfileLoaded) return s.user;
    return null;
  }

  List<_NavItem> _railItems() {
    final u = _currentUser();
    if (u == null) return _leaderRail;
    if (u.isGovernment) return _govRail;
    if (u.isLeader) return _leaderRail;
    return _citizenRail;
  }

  List<_NavItem> _bottomItems() {
    final u = _currentUser();
    if (u == null) return _leaderBottom;
    if (u.isGovernment) return _govBottom;
    if (u.isLeader) return _leaderBottom;
    return _citizenBottom;
  }

  List<_NavItem> _moreItems() {
    final u = _currentUser();
    if (u == null) return _leaderMore;
    if (u.isGovernment) return _govMore;
    if (u.isLeader) return _leaderMore;
    return _citizenMore;
  }

  int _getRailIndex(String location) {
    final items = _railItems();
    for (int i = 0; i < items.length; i++) {
      if (location.startsWith(items[i].path)) return i;
    }
    return 0;
  }

  int _getBottomIndex(String location) {
    final items = _bottomItems();
    for (int i = 0; i < items.length; i++) {
      if (location.startsWith(items[i].path)) return i;
    }
    return items.length; // "More"
  }

  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).uri.toString();

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= kMobileBreakpoint;
        final isDesktop = constraints.maxWidth >= kTabletBreakpoint;

        if (isWide) {
          return _buildRailLayout(context, location, isDesktop);
        }
        return _buildBottomNavLayout(context, location);
      },
    );
  }

  Widget _buildRailLayout(BuildContext context, String location, bool isDesktop) {
    final l10n = AppLocalizations.of(context);
    final selectedIndex = _getRailIndex(location);
    final railItems = _railItems();
    return Scaffold(
      body: Row(
        children: [
          NavigationRail(
            extended: isDesktop,
            selectedIndex: selectedIndex,
            onDestinationSelected: (i) => context.go(railItems[i].path),
            destinations: railItems.map((item) => NavigationRailDestination(
              icon: Icon(item.icon),
              label: Text(item.label),
            )).toList(),
            trailing: Expanded(
              child: Align(
                alignment: Alignment.bottomCenter,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      InkWell(
                        onTap: () => context.push('/profile'),
                        borderRadius: BorderRadius.circular(8),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.person_outline),
                              const SizedBox(height: 2),
                              Text(l10n.profile, style: const TextStyle(fontSize: 10)),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      InkWell(
                        onTap: () => context.read<AuthCubit>().logout(),
                        borderRadius: BorderRadius.circular(8),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.logout, color: Colors.red),
                              const SizedBox(height: 2),
                              Text(l10n.logout, style: const TextStyle(fontSize: 10, color: Colors.red)),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const VerticalDivider(thickness: 1, width: 1),
          Expanded(child: widget.child),
        ],
      ),
    );
  }

  Widget _buildBottomNavLayout(BuildContext context, String location) {
    final l10n = AppLocalizations.of(context);
    final selectedIndex = _getBottomIndex(location);
    final bottomItems = _bottomItems();
    return Scaffold(
      body: widget.child,
      bottomNavigationBar: NavigationBar(
        selectedIndex: selectedIndex.clamp(0, bottomItems.length),
        onDestinationSelected: (i) {
          if (i < bottomItems.length) {
            context.go(bottomItems[i].path);
          } else {
            _showMoreMenu(context);
          }
        },
        destinations: [
          ...bottomItems.map((item) => NavigationDestination(
            icon: Icon(item.icon), label: item.label,
          )),
          NavigationDestination(icon: const Icon(Icons.more_horiz), label: l10n.navMore),
        ],
      ),
    );
  }

  void _showMoreMenu(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final moreItems = _moreItems();
    showModalBottomSheet(
      context: context,
      builder: (sheetCtx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ...moreItems.map((item) => ListTile(
              leading: Icon(item.icon),
              title: Text(item.label),
              onTap: () {
                Navigator.pop(sheetCtx);
                if (item.path == '/profile') {
                  context.push('/profile');
                } else {
                  context.go(item.path);
                }
              },
            )),
            ListTile(
              leading: const Icon(Icons.logout, color: Colors.red),
              title: Text(l10n.logout, style: const TextStyle(color: Colors.red)),
              onTap: () {
                Navigator.pop(sheetCtx);
                context.read<AuthCubit>().logout();
              },
            ),
          ],
        ),
      ),
    );
  }
}

// Keep backward compat — app.dart uses `appRouter`
final _tempRouter = GoRouter(initialLocation: '/login', routes: [
  GoRoute(path: '/login', builder: (_, __) => const LoginScreen()),
]);
GoRouter get appRouter => _tempRouter; // replaced at runtime in app.dart
