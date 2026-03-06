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
import '../features/projects/screens/completed_projects_screen.dart';

GoRouter createRouter(AuthCubit authCubit) {
  return GoRouter(
    initialLocation: '/',
    refreshListenable: _AuthNotifier(authCubit),
    redirect: (context, state) {
      final authState = authCubit.state;
      final isAuthenticated = authState is AuthAuthenticated ||
          authState is AuthProfileLoaded;
      final isCheckingAuth = authState is AuthLoading;
      final isPublicPage = state.uri.path == '/' ||
          state.uri.path == '/login' ||
          state.uri.path == '/otp';

      // While checking stored token on startup, stay on '/' (splash)
      // Don't redirect to login — checkAuth() will emit the real state
      if (isCheckingAuth) return null;

      if (!isAuthenticated && !isPublicPage) return '/login';

      // Redirect authenticated users away from public pages to their home
      if (isAuthenticated && isPublicPage) {
        final user = authState is AuthAuthenticated
            ? authState.user
            : (authState as AuthProfileLoaded).user;
        return user.isGovernment ? '/gov-dashboard' : '/map';
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
          );
        },
      ),
      GoRoute(path: '/profile', builder: (_, __) => const ProfileScreen()),
      ShellRoute(
        builder: (context, state, child) => AppShell(child: child),
        routes: [
          GoRoute(
            path: '/map',
            builder: (_, state) => MapScreen(focusReportId: state.extra as int?),
          ),
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
          GoRoute(
            path: '/schemes',
            builder: (_, state) => SchemeExplorerScreen(
              initialQuery: state.uri.queryParameters['query'],
            ),
          ),
          GoRoute(path: '/dashboard', builder: (_, __) => const LeaderDashboardScreen()),
          GoRoute(path: '/gramsabha', builder: (_, __) => const GramSabhaScreen()),
          GoRoute(path: '/gov-dashboard', builder: (_, __) => const GovernmentDashboardScreen()),
          GoRoute(path: '/users', builder: (_, __) => const UserManagementScreen()),
          GoRoute(path: '/completed', builder: (_, __) => const CompletedProjectsScreen()),
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
  bool _isRailCollapsed = false;

  // ── Citizen nav ───────────────────────────────────────────────────────────
  static List<_NavItem> _citizenRailItems(AppLocalizations l10n) => [
    _NavItem(Icons.map_outlined, l10n.navMap, '/map'),
    _NavItem(Icons.mic_outlined, l10n.navReport, '/report'),
    _NavItem(Icons.people_outline, l10n.navFeed, '/feed'),
    _NavItem(Icons.construction_outlined, l10n.navProjects, '/projects'),
    _NavItem(Icons.search_outlined, l10n.navSchemes, '/schemes'),
    _NavItem(Icons.verified_outlined, l10n.completed, '/completed'),
  ];
  static List<_NavItem> _citizenBottomItems(AppLocalizations l10n) => [
    _NavItem(Icons.map_outlined, l10n.navMap, '/map'),
    _NavItem(Icons.mic_outlined, l10n.navReport, '/report'),
    _NavItem(Icons.people_outline, l10n.navFeed, '/feed'),
    _NavItem(Icons.construction_outlined, l10n.navProjects, '/projects'),
  ];
  static List<_NavItem> _citizenMoreItems(AppLocalizations l10n) => [
    _NavItem(Icons.search_outlined, l10n.navSchemes, '/schemes'),
    _NavItem(Icons.verified_outlined, l10n.completed, '/completed'),
    _NavItem(Icons.person_outline, l10n.profile, '/profile'),
  ];

  // ── Leader nav ────────────────────────────────────────────────────────────
  static List<_NavItem> _leaderRailItems(AppLocalizations l10n) => [
    _NavItem(Icons.map_outlined, l10n.navMap, '/map'),
    _NavItem(Icons.mic_outlined, l10n.navReport, '/report'),
    _NavItem(Icons.people_outline, l10n.navFeed, '/feed'),
    _NavItem(Icons.groups_outlined, l10n.navGramSabha, '/gramsabha'),
    _NavItem(Icons.dashboard_outlined, l10n.navDashboard, '/dashboard'),
    _NavItem(Icons.construction_outlined, l10n.navProjects, '/projects'),
    _NavItem(Icons.search_outlined, l10n.navSchemes, '/schemes'),
    _NavItem(Icons.manage_accounts_outlined, 'Users', '/users'),
  ];
  static List<_NavItem> _leaderBottomItems(AppLocalizations l10n) => [
    _NavItem(Icons.map_outlined, l10n.navMap, '/map'),
    _NavItem(Icons.mic_outlined, l10n.navReport, '/report'),
    _NavItem(Icons.dashboard_outlined, l10n.navDashboard, '/dashboard'),
    _NavItem(Icons.people_outline, l10n.navFeed, '/feed'),
  ];
  static List<_NavItem> _leaderMoreItems(AppLocalizations l10n) => [
    _NavItem(Icons.construction_outlined, l10n.navProjects, '/projects'),
    _NavItem(Icons.search_outlined, l10n.navSchemes, '/schemes'),
    _NavItem(Icons.groups_outlined, l10n.navGramSabha, '/gramsabha'),
    _NavItem(Icons.manage_accounts_outlined, 'Users', '/users'),
    _NavItem(Icons.person_outline, l10n.profile, '/profile'),
  ];

  // ── Government nav ────────────────────────────────────────────────────────
  static List<_NavItem> _govRailItems(AppLocalizations l10n) => [
    _NavItem(Icons.map_outlined, l10n.navMap, '/map'),
    _NavItem(Icons.people_outline, l10n.navFeed, '/feed'),
    _NavItem(Icons.dashboard_customize_outlined, l10n.navGovDashboard, '/gov-dashboard'),
    _NavItem(Icons.construction_outlined, l10n.navProjects, '/projects'),
    _NavItem(Icons.search_outlined, l10n.navSchemes, '/schemes'),
    _NavItem(Icons.groups_outlined, l10n.navGramSabha, '/gramsabha'),
  ];
  static List<_NavItem> _govBottomItems(AppLocalizations l10n) => [
    _NavItem(Icons.map_outlined, l10n.navMap, '/map'),
    _NavItem(Icons.dashboard_customize_outlined, l10n.navGovDashboard, '/gov-dashboard'),
    _NavItem(Icons.people_outline, l10n.navFeed, '/feed'),
    _NavItem(Icons.construction_outlined, l10n.navProjects, '/projects'),
  ];
  static List<_NavItem> _govMoreItems(AppLocalizations l10n) => [
    _NavItem(Icons.search_outlined, l10n.navSchemes, '/schemes'),
    _NavItem(Icons.groups_outlined, l10n.navGramSabha, '/gramsabha'),
    _NavItem(Icons.person_outline, l10n.profile, '/profile'),
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
                final isDesktop = constraints.maxWidth >= kTabletBreakpoint;
                // Show sidebar rail only on tablet+ (≥768); bottom nav on anything narrower
                final showRail = constraints.maxWidth >= 768;
                if (showRail) {
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
    final isExtended = isDesktop && !_isRailCollapsed;

    return Scaffold(
      body: Row(
        children: [
          // Custom styled sidebar
          Container(
            width: isExtended ? 220 : 72,
            decoration: const BoxDecoration(
              color: Color(0xFF1A237E),
            ),
            child: SafeArea(
              child: Column(
                children: [
                  // ── App branding + collapse toggle ──
                  Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: isExtended ? 16 : 12,
                      vertical: 12,
                    ),
                    child: Row(
                      children: [
                        if (isExtended) ...[
                          Container(
                            width: 32, height: 32,
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(Icons.how_to_vote_rounded,
                                color: Colors.white, size: 18),
                          ),
                          const SizedBox(width: 10),
                          const Expanded(
                            child: Text('PrajaShakti', style: TextStyle(
                              color: Colors.white, fontSize: 16,
                              fontWeight: FontWeight.w700, letterSpacing: 0.3,
                            )),
                          ),
                        ],
                        InkWell(
                          onTap: () => setState(() => _isRailCollapsed = !_isRailCollapsed),
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(
                              isExtended ? Icons.menu_open_rounded : Icons.menu_rounded,
                              color: Colors.white70, size: 20,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 8),

                  // ── Nav items ──
                  Expanded(
                    child: ListView(
                      padding: EdgeInsets.symmetric(horizontal: isExtended ? 10 : 8),
                      children: List.generate(railItems.length, (i) {
                        final item = railItems[i];
                        final isSelected = i == selectedIndex;
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 2),
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: () => context.go(item.path),
                              borderRadius: BorderRadius.circular(12),
                              child: Container(
                                padding: EdgeInsets.symmetric(
                                  horizontal: isExtended ? 14 : 0,
                                  vertical: 11,
                                ),
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? Colors.white.withValues(alpha: 0.15)
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: isExtended
                                    ? Row(
                                        children: [
                                          Icon(item.icon, size: 20,
                                            color: isSelected ? Colors.white : Colors.white60),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Text(item.label, style: TextStyle(
                                              fontSize: 13.5,
                                              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                                              color: isSelected ? Colors.white : Colors.white60,
                                            )),
                                          ),
                                          if (isSelected)
                                            Container(
                                              width: 6, height: 6,
                                              decoration: const BoxDecoration(
                                                color: Color(0xFFFFC107),
                                                shape: BoxShape.circle,
                                              ),
                                            ),
                                        ],
                                      )
                                    : Center(
                                        child: Tooltip(
                                          message: item.label,
                                          child: Icon(item.icon, size: 22,
                                            color: isSelected ? Colors.white : Colors.white60),
                                        ),
                                      ),
                              ),
                            ),
                          ),
                        );
                      }),
                    ),
                  ),

                  // ── Bottom: Profile + Logout ──
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: isExtended ? 10 : 8,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      border: Border(
                        top: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
                      ),
                    ),
                    child: Column(
                      children: [
                        _SidebarAction(
                          icon: Icons.person_outline,
                          label: l10n.profile,
                          isExtended: isExtended,
                          onTap: () => context.push('/profile'),
                        ),
                        const SizedBox(height: 4),
                        _SidebarAction(
                          icon: Icons.logout_rounded,
                          label: l10n.logout,
                          isExtended: isExtended,
                          isDestructive: true,
                          onTap: () => context.read<AuthCubit>().logout(),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Content area
          Expanded(
            child: SafeArea(
              left: false,
              bottom: false,
              child: widget.child,
            ),
          ),
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
      body: SafeArea(
        bottom: false,
        child: widget.child,
      ),
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
    final isAnon = user?.isAnonymous ?? true;
    final name = isAnon
        ? l10n.guest
        : (user!.fullName.isNotEmpty ? user.fullName : user.username);
    final phone = isAnon ? '' : user!.phone;
    final roleLabel = isAnon
        ? l10n.guest
        : user!.isGovernment
            ? 'Government Official'
            : user!.isLeader
                ? 'Panchayat Leader'
                : 'Citizen';
    final initials = name.isNotEmpty
        ? name.split(' ').take(2).map((w) => w.isNotEmpty ? w[0].toUpperCase() : '').join()
        : '?';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetCtx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Drag handle
              Container(
                width: 40, height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),
              // User info
              Row(
                children: [
                  CircleAvatar(
                    radius: 28,
                    backgroundColor: const Color(0xFF3F51B5).withOpacity(0.12),
                    child: Text(initials, style: const TextStyle(
                      fontSize: 20, fontWeight: FontWeight.w700, color: Color(0xFF1A237E),
                    )),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(name, style: const TextStyle(
                          fontSize: 17, fontWeight: FontWeight.w700, color: Color(0xFF263238),
                        )),
                        const SizedBox(height: 2),
                        Text(roleLabel, style: TextStyle(
                          fontSize: 13, color: Colors.grey.shade600,
                        )),
                        if (phone.isNotEmpty)
                          Text(phone, style: TextStyle(
                            fontSize: 12, color: Colors.grey.shade500,
                          )),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              // "QUICK ACCESS MENU" label
              Align(
                alignment: Alignment.centerLeft,
                child: Text('QUICK ACCESS MENU', style: TextStyle(
                  fontSize: 11, fontWeight: FontWeight.w700,
                  color: Colors.grey.shade500, letterSpacing: 1.2,
                )),
              ),
              const SizedBox(height: 12),
              // 2-column grid of menu cards
              GridView.count(
                crossAxisCount: 3,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                childAspectRatio: 1.1,
                children: [
                  ...moreItems.map((item) => _MenuCard(
                    icon: item.icon,
                    label: item.label,
                    color: _menuColor(item.path),
                    onTap: () {
                      Navigator.pop(sheetCtx);
                      if (item.path == '/profile') {
                        context.push('/profile');
                      } else {
                        context.go(item.path);
                      }
                    },
                  )),
                  _MenuCard(
                    icon: Icons.logout_rounded,
                    label: l10n.logout,
                    color: const Color(0xFFFF5252),
                    onTap: () {
                      Navigator.pop(sheetCtx);
                      context.read<AuthCubit>().logout();
                    },
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // Footer
              Text(
                'v1.0.0 • Privacy Policy',
                style: TextStyle(fontSize: 11, color: Colors.grey.shade400),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static Color _menuColor(String path) {
    switch (path) {
      case '/projects': return const Color(0xFF3F51B5);
      case '/schemes': return const Color(0xFF00695C);
      case '/gramsabha': return const Color(0xFFFFC107);
      case '/feed': return const Color(0xFF03A9F4);
      case '/profile': return const Color(0xFF263238);
      case '/completed': return const Color(0xFF2E7D32);
      case '/users': return const Color(0xFFFF9800);
      case '/dashboard': return const Color(0xFF1A237E);
      default: return const Color(0xFF90A4AE);
    }
  }
}

/// Sidebar bottom action (Profile / Logout).
class _SidebarAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isExtended;
  final bool isDestructive;
  final VoidCallback onTap;
  const _SidebarAction({
    required this.icon, required this.label, required this.isExtended,
    this.isDestructive = false, required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = isDestructive
        ? const Color(0xFFFF8A80)
        : Colors.white60;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: isExtended ? 14 : 0,
            vertical: 9,
          ),
          child: isExtended
              ? Row(
                  children: [
                    Icon(icon, size: 18, color: color),
                    const SizedBox(width: 12),
                    Text(label, style: TextStyle(
                      fontSize: 13, color: color, fontWeight: FontWeight.w500,
                    )),
                  ],
                )
              : Center(
                  child: Tooltip(
                    message: label,
                    child: Icon(icon, size: 20, color: color),
                  ),
                ),
        ),
      ),
    );
  }
}

/// Grid card for the More menu bottom sheet.
class _MenuCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _MenuCard({
    required this.icon, required this.label,
    required this.color, required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 44, height: 44,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, size: 22, color: color),
              ),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Text(
                  label,
                  style: const TextStyle(
                    fontSize: 11, fontWeight: FontWeight.w600,
                    color: Color(0xFF263238),
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
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
