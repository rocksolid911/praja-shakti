import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../core/utils/responsive.dart';
import '../features/auth/cubit/auth_cubit.dart';
import '../features/auth/cubit/auth_state.dart';
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
      if (authState is AuthAuthenticated && isOnAuthPage) return '/map';
      return null;
    },
    routes: [
      GoRoute(path: '/login', builder: (_, __) => const LoginScreen()),
      GoRoute(
        path: '/otp',
        builder: (_, state) => OTPScreen(phone: state.extra as String? ?? ''),
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
  // All destinations shown in the NavigationRail on wide screens.
  static const _railItems = [
    _NavItem(Icons.map, 'Map', '/map'),
    _NavItem(Icons.mic, 'Report', '/report'),
    _NavItem(Icons.people, 'Feed', '/feed'),
    _NavItem(Icons.construction, 'Projects', '/projects'),
    _NavItem(Icons.search, 'Schemes', '/schemes'),
    _NavItem(Icons.dashboard, 'Dashboard', '/dashboard'),
    _NavItem(Icons.groups, 'Gram Sabha', '/gramsabha'),
  ];

  // First 4 items appear directly in the mobile BottomNavigationBar.
  static const _bottomItems = [
    _NavItem(Icons.map, 'Map', '/map'),
    _NavItem(Icons.mic, 'Report', '/report'),
    _NavItem(Icons.people, 'Feed', '/feed'),
    _NavItem(Icons.construction, 'Projects', '/projects'),
  ];

  // Items shown in the "More" bottom sheet on mobile.
  static const _moreItems = [
    _NavItem(Icons.search, 'Scheme Explorer', '/schemes'),
    _NavItem(Icons.dashboard, 'Leader Dashboard', '/dashboard'),
    _NavItem(Icons.groups, 'Gram Sabha', '/gramsabha'),
    _NavItem(Icons.person, 'Profile', '/profile'),
  ];

  int _getRailIndex(String location) {
    if (location.startsWith('/map')) return 0;
    if (location.startsWith('/report')) return 1;
    if (location.startsWith('/feed')) return 2;
    if (location.startsWith('/project')) return 3;
    if (location.startsWith('/schemes')) return 4;
    if (location.startsWith('/dashboard')) return 5;
    if (location.startsWith('/gramsabha')) return 6;
    return 0;
  }

  int _getBottomIndex(String location) {
    if (location.startsWith('/map')) return 0;
    if (location.startsWith('/report')) return 1;
    if (location.startsWith('/feed')) return 2;
    if (location.startsWith('/project')) return 3;
    return 4; // More
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
    final selectedIndex = _getRailIndex(location);
    return Scaffold(
      body: Row(
        children: [
          NavigationRail(
            extended: isDesktop,
            selectedIndex: selectedIndex,
            onDestinationSelected: (i) => context.go(_railItems[i].path),
            destinations: _railItems.map((item) => NavigationRailDestination(
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
                      IconButton(
                        icon: const Icon(Icons.person_outline),
                        tooltip: 'Profile',
                        onPressed: () => context.go('/profile'),
                      ),
                      IconButton(
                        icon: const Icon(Icons.logout, color: Colors.red),
                        tooltip: 'Logout',
                        onPressed: () => context.read<AuthCubit>().logout(),
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
    final selectedIndex = _getBottomIndex(location);
    return Scaffold(
      body: widget.child,
      bottomNavigationBar: NavigationBar(
        selectedIndex: selectedIndex,
        onDestinationSelected: (i) {
          if (i < _bottomItems.length) {
            context.go(_bottomItems[i].path);
          } else {
            _showMoreMenu(context);
          }
        },
        destinations: [
          ..._bottomItems.map((item) => NavigationDestination(
            icon: Icon(item.icon),
            label: item.label,
          )),
          const NavigationDestination(icon: Icon(Icons.more_horiz), label: 'More'),
        ],
      ),
    );
  }

  void _showMoreMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ..._moreItems.map((item) => ListTile(
              leading: Icon(item.icon),
              title: Text(item.label),
              onTap: () { Navigator.pop(context); context.go(item.path); },
            )),
            ListTile(
              leading: const Icon(Icons.logout, color: Colors.red),
              title: const Text('Logout', style: TextStyle(color: Colors.red)),
              onTap: () {
                Navigator.pop(context);
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
