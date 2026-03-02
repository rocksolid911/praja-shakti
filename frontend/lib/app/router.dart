import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../core/cubit/locale_cubit.dart';
import '../core/utils/responsive.dart';
import '../features/auth/cubit/auth_cubit.dart';
import '../features/auth/cubit/auth_state.dart';
import '../core/models/user.dart';
import '../l10n/app_localizations.dart';
import '../features/auth/screens/landing_screen.dart';
import '../features/auth/screens/landing_page.dart';
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
    initialLocation: '/',
    refreshListenable: _AuthNotifier(authCubit),
    redirect: (context, state) {
      final authState = authCubit.state;
      final isAuthenticated = authState is AuthAuthenticated ||
          authState is AuthProfileLoaded ||
          authState is AuthLoading;
      final isPublicPage = state.uri.path == '/' ||
          state.uri.path == '/login' ||
          state.uri.path == '/otp';

      if (!isAuthenticated && !isPublicPage) return '/login';
      if (authState is AuthAuthenticated && isPublicPage) {
        return authState.user.isGovernment ? '/gov-dashboard' : '/map';
      }
      return null;
    },
    routes: [
      GoRoute(path: '/', builder: (_, __) => const LandingPage()),
      GoRoute(path: '/login', builder: (_, __) => const LandingScreen()),
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

/// Notifies GoRouter when auth state changes so it can re-run redirect.
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
  // ── Citizen nav ───────────────────────────────────────────────────────────
  static List<_NavItem> _citizenRailItems(AppLocalizations l10n) => [
    _NavItem(Icons.map, l10n.navMap, '/map'),
    _NavItem(Icons.mic, l10n.navReport, '/report'),
    _NavItem(Icons.people, l10n.navFeed, '/feed'),
    _NavItem(Icons.search, l10n.navSchemes, '/schemes'),
  ];
  static List<_NavItem> _citizenBottomItems(AppLocalizations l10n) => [
    _NavItem(Icons.map, l10n.navMap, '/map'),
    _NavItem(Icons.mic, l10n.navReport, '/report'),
    _NavItem(Icons.people, l10n.navFeed, '/feed'),
    _NavItem(Icons.search, l10n.navSchemes, '/schemes'),
  ];
  static List<_NavItem> _citizenMoreItems(AppLocalizations l10n) => [
    _NavItem(Icons.person, l10n.profile, '/profile'),
  ];

  // ── Leader nav ────────────────────────────────────────────────────────────
  static List<_NavItem> _leaderRailItems(AppLocalizations l10n) => [
    _NavItem(Icons.map, l10n.navMap, '/map'),
    _NavItem(Icons.mic, l10n.navReport, '/report'),
    _NavItem(Icons.people, l10n.navFeed, '/feed'),
    _NavItem(Icons.groups, l10n.navGramSabha, '/gramsabha'),
    _NavItem(Icons.dashboard, l10n.navDashboard, '/dashboard'),
    _NavItem(Icons.construction, l10n.navProjects, '/projects'),
    _NavItem(Icons.search, l10n.navSchemes, '/schemes'),
  ];
  static List<_NavItem> _leaderBottomItems(AppLocalizations l10n) => [
    _NavItem(Icons.map, l10n.navMap, '/map'),
    _NavItem(Icons.mic, l10n.navReport, '/report'),
    _NavItem(Icons.dashboard, l10n.navDashboard, '/dashboard'),
    _NavItem(Icons.groups, l10n.navGramSabha, '/gramsabha'),
  ];
  static List<_NavItem> _leaderMoreItems(AppLocalizations l10n) => [
    _NavItem(Icons.construction, l10n.navProjects, '/projects'),
    _NavItem(Icons.search, l10n.navSchemes, '/schemes'),
    _NavItem(Icons.manage_accounts, l10n.navManageUsers, '/users'),
    _NavItem(Icons.people, l10n.navFeed, '/feed'),
    _NavItem(Icons.person, l10n.profile, '/profile'),
  ];

  // ── Government nav ────────────────────────────────────────────────────────
  static List<_NavItem> _govRailItems(AppLocalizations l10n) => [
    _NavItem(Icons.map, l10n.navMap, '/map'),
    _NavItem(Icons.people, l10n.navFeed, '/feed'),
    _NavItem(Icons.dashboard_customize, l10n.navGovDashboard, '/gov-dashboard'),
    _NavItem(Icons.construction, l10n.navProjects, '/projects'),
    _NavItem(Icons.search, l10n.navSchemes, '/schemes'),
    _NavItem(Icons.groups, l10n.navGramSabha, '/gramsabha'),
  ];
  static List<_NavItem> _govBottomItems(AppLocalizations l10n) => [
    _NavItem(Icons.map, l10n.navMap, '/map'),
    _NavItem(Icons.dashboard_customize, l10n.navGovDashboard, '/gov-dashboard'),
    _NavItem(Icons.people, l10n.navFeed, '/feed'),
    _NavItem(Icons.construction, l10n.navProjects, '/projects'),
  ];
  static List<_NavItem> _govMoreItems(AppLocalizations l10n) => [
    _NavItem(Icons.search, l10n.navSchemes, '/schemes'),
    _NavItem(Icons.groups, l10n.navGramSabha, '/gramsabha'),
    _NavItem(Icons.person, l10n.profile, '/profile'),
  ];

  // ── Role selection — takes User? directly, no context.read() ─────────────
  static List<_NavItem> _railItemsFor(AppLocalizations l10n, User? user) {
    if (user == null) return _leaderRailItems(l10n);
    if (user.isGovernment) return _govRailItems(l10n);
    if (user.isLeader) return _leaderRailItems(l10n);
    return _citizenRailItems(l10n);
  }

  static List<_NavItem> _bottomItemsFor(AppLocalizations l10n, User? user) {
    if (user == null) return _leaderBottomItems(l10n);
    if (user.isGovernment) return _govBottomItems(l10n);
    if (user.isLeader) return _leaderBottomItems(l10n);
    return _citizenBottomItems(l10n);
  }

  static List<_NavItem> _moreItemsFor(AppLocalizations l10n, User? user) {
    if (user == null) return _leaderMoreItems(l10n);
    if (user.isGovernment) return _govMoreItems(l10n);
    if (user.isLeader) return _leaderMoreItems(l10n);
    return _citizenMoreItems(l10n);
  }

  static int _railIndexFor(String location, List<_NavItem> items) {
    for (int i = 0; i < items.length; i++) {
      if (location.startsWith(items[i].path)) return i;
    }
    return 0;
  }

  static int _bottomIndexFor(String location, List<_NavItem> items) {
    for (int i = 0; i < items.length; i++) {
      if (location.startsWith(items[i].path)) return i;
    }
    return items.length; // "More"
  }

  /// Extract user directly from the BlocBuilder's authState — no context.read() needed.
  static User? _userFromState(AuthState authState) {
    if (authState is AuthAuthenticated) return authState.user;
    if (authState is AuthProfileLoaded) return authState.user;
    return null;
  }

  @override
  Widget build(BuildContext context) {
    // Double-wrap: AuthCubit triggers rebuild on role change, LocaleCubit on language change.
    // User is extracted DIRECTLY from authState to guarantee correctness.
    return BlocBuilder<AuthCubit, AuthState>(
      builder: (context, authState) {
        final user = _userFromState(authState);
        return BlocBuilder<LocaleCubit, Locale>(
          builder: (context, _) {
            final location = GoRouterState.of(context).uri.toString();
            final l10n = AppLocalizations.of(context);
            return LayoutBuilder(
              builder: (context, constraints) {
                final isWide = constraints.maxWidth >= kMobileBreakpoint;
                final isDesktop = constraints.maxWidth >= kTabletBreakpoint;
                if (isWide) {
                  return _buildRailLayout(context, location, isDesktop, l10n, user);
                }
                return _buildBottomNavLayout(context, location, l10n, user);
              },
            );
          },
        );
      },
    );
  }

  Widget _buildRailLayout(
    BuildContext context, String location, bool isDesktop,
    AppLocalizations l10n, User? user,
  ) {
    final railItems = _railItemsFor(l10n, user);
    final selectedIndex = _railIndexFor(location, railItems);
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

  Widget _buildBottomNavLayout(
    BuildContext context, String location,
    AppLocalizations l10n, User? user,
  ) {
    final bottomItems = _bottomItemsFor(l10n, user);
    final selectedIndex = _bottomIndexFor(location, bottomItems);
    return Scaffold(
      body: widget.child,
      bottomNavigationBar: NavigationBar(
        selectedIndex: selectedIndex.clamp(0, bottomItems.length),
        onDestinationSelected: (i) {
          if (i < bottomItems.length) {
            context.go(bottomItems[i].path);
          } else {
            _showMoreMenu(context, l10n, user);
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

  void _showMoreMenu(BuildContext context, AppLocalizations l10n, User? user) {
    final moreItems = _moreItemsFor(l10n, user);
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
  GoRoute(path: '/login', builder: (_, __) => const LandingScreen()),
]);
GoRouter get appRouter => _tempRouter; // replaced at runtime in app.dart
