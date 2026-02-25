import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
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

final appRouter = GoRouter(
  initialLocation: '/login',
  routes: [
    GoRoute(path: '/login', builder: (_, __) => const LoginScreen()),
    GoRoute(path: '/otp', builder: (_, state) => OTPScreen(phone: state.extra as String? ?? '')),
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

class AppShell extends StatelessWidget {
  final Widget child;
  const AppShell({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: child,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _getIndex(GoRouterState.of(context).uri.toString()),
        onDestinationSelected: (index) => _navigate(context, index),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.map), label: 'Map'),
          NavigationDestination(icon: Icon(Icons.mic), label: 'Report'),
          NavigationDestination(icon: Icon(Icons.people), label: 'Feed'),
          NavigationDestination(icon: Icon(Icons.construction), label: 'Projects'),
          NavigationDestination(icon: Icon(Icons.more_horiz), label: 'More'),
        ],
      ),
    );
  }

  int _getIndex(String location) {
    if (location.startsWith('/map')) return 0;
    if (location.startsWith('/report')) return 1;
    if (location.startsWith('/feed')) return 2;
    if (location.startsWith('/project')) return 3;
    return 4;
  }

  void _navigate(BuildContext context, int index) {
    switch (index) {
      case 0: context.go('/map');
      case 1: context.go('/report');
      case 2: context.go('/feed');
      case 3: context.go('/projects');
      case 4: _showMoreMenu(context);
    }
  }

  void _showMoreMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.search),
              title: const Text('Scheme Explorer'),
              onTap: () { Navigator.pop(context); context.go('/schemes'); },
            ),
            ListTile(
              leading: const Icon(Icons.dashboard),
              title: const Text('Leader Dashboard'),
              onTap: () { Navigator.pop(context); context.go('/dashboard'); },
            ),
            ListTile(
              leading: const Icon(Icons.groups),
              title: const Text('Gram Sabha'),
              onTap: () { Navigator.pop(context); context.go('/gramsabha'); },
            ),
            ListTile(
              leading: const Icon(Icons.person),
              title: const Text('Profile'),
              onTap: () { Navigator.pop(context); context.go('/profile'); },
            ),
          ],
        ),
      ),
    );
  }
}
