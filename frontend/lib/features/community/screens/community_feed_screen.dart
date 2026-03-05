import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';
import '../cubit/community_cubit.dart';
import '../cubit/community_state.dart';
import '../../../core/api/api_client.dart';
import '../../../core/models/report.dart';
import '../../../core/utils/responsive.dart';
import '../../../l10n/app_localizations.dart';
import '../../auth/cubit/auth_cubit.dart';

// ── Design constants ──────────────────────────────────────────────────────────
const _kIndigo = Color(0xFF3B5BDB);
const _kIndigoLight = Color(0xFFEDF2FF);
const _kCardRadius = 16.0;
const _kChipRadius = 20.0;

class CommunityFeedScreen extends StatelessWidget {
  const CommunityFeedScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => CommunityCubit(context.read<ApiClient>())..loadReports(),
      child: const _FeedView(),
    );
  }
}

// ── Main Feed View ────────────────────────────────────────────────────────────

class _FeedView extends StatelessWidget {
  const _FeedView();

  static const _filterKeys = <String?>[
    null, 'water', 'road', 'health', 'education', 'electricity', 'sanitation',
  ];

  static String _filterLabel(AppLocalizations l10n, String? key) => switch (key) {
    'water' => l10n.water,
    'road' => l10n.road,
    'health' => l10n.health,
    'education' => l10n.education,
    'electricity' => l10n.electricity,
    'sanitation' => l10n.sanitation,
    _ => l10n.filterAll,
  };

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= kTabletBreakpoint) {
          return _buildWebLayout(context);
        }
        return _buildMobileLayout(context);
      },
    );
  }

  // ── Mobile Layout ───────────────────────────────────────────────────────────

  Widget _buildMobileLayout(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        elevation: 0.5,
        leading: Padding(
          padding: const EdgeInsets.all(10),
          child: Icon(Icons.groups_rounded, color: _kIndigo, size: 26),
        ),
        title: Text(
          l10n.communityFeed,
          style: const TextStyle(
            color: Color(0xFF1A1A2E), fontWeight: FontWeight.w700, fontSize: 18,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.search_rounded, color: Color(0xFF555770)),
            onPressed: () {},
          ),
          Stack(
            children: [
              IconButton(
                icon: const Icon(Icons.notifications_outlined, color: Color(0xFF555770)),
                onPressed: () {},
              ),
              Positioned(
                top: 10, right: 10,
                child: Container(
                  width: 8, height: 8,
                  decoration: const BoxDecoration(
                    color: Colors.red, shape: BoxShape.circle,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: Column(
        children: [
          _buildFilterChips(context),
          Expanded(
            child: _buildFeedContent(context, columns: 1),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.go('/report'),
        backgroundColor: _kIndigo,
        elevation: 4,
        child: const Icon(Icons.add_rounded, color: Colors.white, size: 28),
      ),
    );
  }

  // ── Web Layout ──────────────────────────────────────────────────────────────

  Widget _buildWebLayout(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      body: Row(
        children: [
          // Main feed area
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Container(
                  padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
                  child: Row(
                    children: [
                      Text(
                        l10n.communityFeed,
                        style: const TextStyle(
                          fontSize: 24, fontWeight: FontWeight.w700,
                          color: Color(0xFF1A1A2E),
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(Icons.refresh_rounded),
                        onPressed: () => context.read<CommunityCubit>().loadReports(),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: _buildFilterChips(context),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: _buildFeedContent(context, columns: 1),
                ),
              ],
            ),
          ),
          // Right sidebar
          Container(
            width: 320,
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(left: BorderSide(color: Colors.grey.shade200)),
            ),
            child: _RightSidebar(),
          ),
        ],
      ),
    );
  }

  // ── Filter Chips ────────────────────────────────────────────────────────────

  Widget _buildFilterChips(BuildContext context) {
    return SizedBox(
      height: 52,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        itemCount: _filterKeys.length,
        itemBuilder: (context, i) {
          final key = _filterKeys[i];
          final label = _filterLabel(AppLocalizations.of(context), key);
          return BlocBuilder<CommunityCubit, CommunityState>(
            builder: (context, state) {
              final active = state is CommunityLoaded && state.activeFilter == key;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: FilterChip(
                  label: Text(
                    label,
                    style: TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w600,
                      color: active ? Colors.white : const Color(0xFF555770),
                    ),
                  ),
                  selected: active,
                  onSelected: (_) => context.read<CommunityCubit>().loadReports(category: key),
                  selectedColor: _kIndigo,
                  backgroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(_kChipRadius),
                    side: BorderSide(
                      color: active ? _kIndigo : Colors.grey.shade300,
                    ),
                  ),
                  showCheckmark: false,
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                ),
              );
            },
          );
        },
      ),
    );
  }

  // ── Feed Content ────────────────────────────────────────────────────────────

  Widget _buildFeedContent(BuildContext context, {required int columns}) {
    return BlocBuilder<CommunityCubit, CommunityState>(
      builder: (context, state) {
        if (state is CommunityLoading) {
          return const Center(child: CircularProgressIndicator(color: _kIndigo));
        }
        if (state is CommunityError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline_rounded, size: 48, color: Colors.red.shade300),
                const SizedBox(height: 12),
                Text(state.message, style: TextStyle(color: Colors.grey.shade600)),
                const SizedBox(height: 8),
                TextButton.icon(
                  onPressed: () => context.read<CommunityCubit>().loadReports(),
                  icon: const Icon(Icons.refresh_rounded),
                  label: Text(AppLocalizations.of(context).retry),
                ),
              ],
            ),
          );
        }
        if (state is CommunityLoaded) {
          if (state.reports.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.people_outline_rounded, size: 64, color: Colors.grey.shade300),
                  const SizedBox(height: 12),
                  Text(
                    AppLocalizations.of(context).noReports,
                    style: TextStyle(color: Colors.grey.shade500, fontSize: 15),
                  ),
                ],
              ),
            );
          }
          return RefreshIndicator(
            color: _kIndigo,
            onRefresh: () => context.read<CommunityCubit>().loadReports(),
            child: NotificationListener<ScrollNotification>(
              onNotification: (n) {
                if (n.metrics.pixels >= n.metrics.maxScrollExtent - 100) {
                  context.read<CommunityCubit>().loadMore();
                }
                return false;
              },
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 12),
                itemCount: 1 + state.reports.length + (state.hasMore ? 1 : 0),
                itemBuilder: (context, i) {
                  // Leader banner as first item
                  if (i == 0) return const _LeaderBanner();
                  final reportIdx = i - 1;
                  if (reportIdx >= state.reports.length) {
                    return const Padding(
                      padding: EdgeInsets.all(16),
                      child: Center(child: CircularProgressIndicator(color: _kIndigo)),
                    );
                  }
                  final report = state.reports[reportIdx];
                  return _ReportCard(
                    report: report,
                    onVote: () => context.read<CommunityCubit>().vote(report.id),
                    onTap: () => context.push('/report/${report.id}'),
                  );
                },
              ),
            ),
          );
        }
        return const SizedBox.shrink();
      },
    );
  }
}

// ── Leader Banner ─────────────────────────────────────────────────────────────

class _LeaderBanner extends StatefulWidget {
  const _LeaderBanner();

  @override
  State<_LeaderBanner> createState() => _LeaderBannerState();
}

class _LeaderBannerState extends State<_LeaderBanner> {
  Map<String, dynamic>? _leader;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _fetchLeader();
  }

  Future<void> _fetchLeader() async {
    try {
      final villageId = context.read<AuthCubit>().currentVillageId;
      final api = context.read<ApiClient>();
      final resp = await api.get(
        '/auth/village-leader/',
        queryParameters: {'village': villageId},
      );
      if (mounted) {
        final data = resp.data as Map<String, dynamic>;
        setState(() {
          _leader = data.containsKey('id') ? data : null;
          _loaded = true;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loaded = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded || _leader == null) return const SizedBox.shrink();

    final name = (_leader!['name'] as String?)?.trim() ?? '';
    final phone = (_leader!['phone'] as String?) ?? '';
    final initials = name.isNotEmpty
        ? name.split(' ').take(2).map((w) => w.isNotEmpty ? w[0] : '').join().toUpperCase()
        : '?';

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF364FC7), Color(0xFF3B5BDB)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(_kCardRadius),
        boxShadow: [
          BoxShadow(
            color: _kIndigo.withValues(alpha: 0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 24,
            backgroundColor: Colors.white.withValues(alpha: 0.2),
            child: Icon(Icons.person_rounded, color: Colors.white.withValues(alpha: 0.9), size: 28),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'GRAM PANCHAYAT LEADER',
                  style: TextStyle(
                    fontSize: 10, fontWeight: FontWeight.w700,
                    color: Colors.white.withValues(alpha: 0.7),
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  name.isNotEmpty ? name : phone,
                  style: const TextStyle(
                    fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
          OutlinedButton.icon(
            onPressed: () async {
              final uri = Uri.parse('tel:$phone');
              if (await canLaunchUrl(uri)) launchUrl(uri);
            },
            icon: const Icon(Icons.phone_rounded, size: 16, color: Colors.white),
            label: const Text(
              'Contact',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13),
            ),
            style: OutlinedButton.styleFrom(
              side: BorderSide(color: Colors.white.withValues(alpha: 0.5)),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Report Card ───────────────────────────────────────────────────────────────

class _ReportCard extends StatelessWidget {
  final Report report;
  final VoidCallback onVote;
  final VoidCallback onTap;

  const _ReportCard({required this.report, required this.onVote, required this.onTap});

  // Also exported for the old ReportCard name (used in feed)
  static Future<void> _openNavigation(double lat, double lng) async {
    final uri = Uri.parse(
      'https://www.google.com/maps/dir/?api=1&destination=$lat,$lng',
    );
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasLocation = report.latitude != null && report.longitude != null;
    final initials = _getInitials(report.reporterName);
    final avatarColor = _categoryColor(report.category);

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(_kCardRadius),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(_kCardRadius),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Header: Avatar + Name + Metadata + Severity Badge ────────
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: avatarColor.withValues(alpha: 0.15),
                    child: Text(
                      initials,
                      style: TextStyle(
                        color: avatarColor, fontWeight: FontWeight.w700, fontSize: 14,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          report.reporterName.isNotEmpty ? report.reporterName : 'Anonymous',
                          style: const TextStyle(
                            fontWeight: FontWeight.w700, fontSize: 14,
                            color: Color(0xFF1A1A2E),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _buildMetadataString(),
                          style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  _SeverityBadge(urgency: report.urgency),
                ],
              ),

              const SizedBox(height: 14),

              // ── Title ───────────────────────────────────────────────────
              Text(
                report.subCategory.isNotEmpty ? report.subCategory : report.descriptionText,
                style: const TextStyle(
                  fontWeight: FontWeight.w700, fontSize: 17,
                  color: Color(0xFF1A1A2E),
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),

              const SizedBox(height: 8),

              // ── Description ─────────────────────────────────────────────
              if (report.descriptionText.startsWith('[Voice note') ||
                  report.descriptionText.startsWith('[Voice Note'))
                Row(
                  children: [
                    Icon(Icons.access_time_rounded, size: 14, color: Colors.orange.shade600),
                    const SizedBox(width: 4),
                    Text(
                      'AI transcription in progress...',
                      style: TextStyle(
                        fontSize: 13, color: Colors.orange.shade600,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                )
              else
                Text(
                  report.descriptionText,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 14, color: Colors.grey.shade600,
                    height: 1.4,
                  ),
                ),

              // ── Map Thumbnail ───────────────────────────────────────────
              if (hasLocation) ...[
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: SizedBox(
                    height: 150,
                    child: Stack(
                      children: [
                        FlutterMap(
                          options: MapOptions(
                            initialCenter: LatLng(report.latitude!, report.longitude!),
                            initialZoom: 15,
                            interactionOptions: const InteractionOptions(
                              flags: InteractiveFlag.none,
                            ),
                          ),
                          children: [
                            TileLayer(
                              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                              userAgentPackageName: 'com.prajashakti.app',
                            ),
                            MarkerLayer(
                              markers: [
                                Marker(
                                  point: LatLng(report.latitude!, report.longitude!),
                                  width: 36, height: 36,
                                  child: Icon(
                                    Icons.location_pin,
                                    color: _kIndigo,
                                    size: 36,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        // Location + ref label overlay (bottom-left)
                        Positioned(
                          bottom: 8, left: 8,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(6),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.1),
                                  blurRadius: 4,
                                ),
                              ],
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.location_on_rounded, size: 12, color: _kIndigo),
                                const SizedBox(width: 4),
                                Text(
                                  [
                                    if (report.ward != null) 'Ward ${report.ward}',
                                    '#REP-${report.id}',
                                  ].join(' \u2022 '),
                                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],

              const SizedBox(height: 14),

              // ── Bottom Action Row ───────────────────────────────────────
              Row(
                children: [
                  // Upvote button
                  InkWell(
                    onTap: onVote,
                    borderRadius: BorderRadius.circular(8),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            report.hasVoted ? Icons.thumb_up_rounded : Icons.thumb_up_outlined,
                            size: 18,
                            color: report.hasVoted ? _kIndigo : Colors.grey.shade500,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            '${report.voteCount} Upvotes',
                            style: TextStyle(
                              fontSize: 13, fontWeight: FontWeight.w600,
                              color: report.hasVoted ? _kIndigo : Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 20),
                  // Comments (tap to view detail)
                  InkWell(
                    onTap: onTap,
                    borderRadius: BorderRadius.circular(8),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.chat_bubble_outline_rounded, size: 17, color: Colors.grey.shade500),
                          const SizedBox(width: 6),
                          Text(
                            '${report.voteCount > 10 ? (report.voteCount ~/ 7) : 0}',
                            style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const Spacer(),
                  // Navigate button
                  if (hasLocation)
                    TextButton.icon(
                      onPressed: () => _openNavigation(report.latitude!, report.longitude!),
                      icon: Icon(Icons.navigation_rounded, size: 16, color: _kIndigo),
                      label: Text(
                        'Navigate',
                        style: TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w600, color: _kIndigo,
                        ),
                      ),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                          side: BorderSide(color: _kIndigo.withValues(alpha: 0.3)),
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _buildMetadataString() {
    final parts = <String>[];
    parts.add(_timeAgo(report.createdAt));
    if (report.villageName.isNotEmpty) parts.add(report.villageName);
    if (report.ward != null) parts.add('Ward ${report.ward.toString().padLeft(2, '0')}');
    return parts.join(' \u2022 ');
  }

  String _getInitials(String name) {
    if (name.isEmpty) return '?';
    final words = name.trim().split(' ');
    if (words.length >= 2) {
      return '${words[0][0]}${words[1][0]}'.toUpperCase();
    }
    return name[0].toUpperCase();
  }

  Color _categoryColor(String cat) {
    switch (cat) {
      case 'water': return Colors.blue;
      case 'road': return Colors.orange;
      case 'health': return Colors.red;
      case 'education': return Colors.purple;
      case 'electricity': return Colors.amber.shade800;
      case 'sanitation': return Colors.teal;
      default: return Colors.grey;
    }
  }

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inDays > 0) return '${diff.inDays}d ago';
    if (diff.inHours > 0) return '${diff.inHours}h ago';
    return '${diff.inMinutes}m ago';
  }
}

// ── Severity Badge ────────────────────────────────────────────────────────────

class _SeverityBadge extends StatelessWidget {
  final String urgency;
  const _SeverityBadge({required this.urgency});

  @override
  Widget build(BuildContext context) {
    final (Color bg, Color fg, String label) = switch (urgency) {
      'critical' => (const Color(0xFFFF6B6B), Colors.white, 'CRITICAL'),
      'high'     => (const Color(0xFFFF922B), Colors.white, 'HIGH'),
      'medium'   => (const Color(0xFFFFD43B), const Color(0xFF5C4800), 'MEDIUM'),
      _          => (const Color(0xFF69DB7C), const Color(0xFF1B5E20), 'LOW'),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: fg, fontSize: 10, fontWeight: FontWeight.w800,
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}

// ── Right Sidebar (Web) ───────────────────────────────────────────────────────

class _RightSidebar extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        // Active Resolution section
        const Text(
          'Active Resolution',
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: Color(0xFF1A1A2E)),
        ),
        const SizedBox(height: 14),
        _ResolutionItem(
          icon: Icons.check_circle_rounded,
          iconColor: Colors.green,
          title: 'Road Work Completed',
          subtitle: 'Main St pothole fixed',
          status: 'Verified by 42 citizens',
        ),
        const SizedBox(height: 10),
        _ResolutionItem(
          icon: Icons.autorenew_rounded,
          iconColor: _kIndigo,
          title: 'Water Tanker Sent',
          subtitle: 'Sent to community center',
          status: 'In progress...',
        ),
        const SizedBox(height: 30),

        // Report CTA card
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: _kIndigoLight,
            borderRadius: BorderRadius.circular(_kCardRadius),
            border: Border.all(color: _kIndigo.withValues(alpha: 0.15)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Report a New Issue?',
                style: TextStyle(
                  fontSize: 16, fontWeight: FontWeight.w700, color: _kIndigo,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Use AI to generate a professional report in seconds.',
                style: TextStyle(fontSize: 13, color: Colors.grey.shade600, height: 1.4),
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => context.go('/report'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _kIndigo,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: const Text(
                    'Create AI Report',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ResolutionItem extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final String status;
  const _ResolutionItem({
    required this.icon, required this.iconColor,
    required this.title, required this.subtitle, required this.status,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Icon(icon, color: iconColor, size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                Text(subtitle, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                const SizedBox(height: 2),
                Text(status, style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Backward compat: keep ReportCard class name for imports ───────────────────
// The old ReportCard was used directly. Alias it to the new private one.
class ReportCard extends StatelessWidget {
  final Report report;
  final VoidCallback onVote;
  final VoidCallback onTap;

  const ReportCard({super.key, required this.report, required this.onVote, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return _ReportCard(report: report, onVote: onVote, onTap: onTap);
  }
}
