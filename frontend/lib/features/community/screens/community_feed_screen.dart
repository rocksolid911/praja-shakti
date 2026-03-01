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

class _FeedView extends StatelessWidget {
  const _FeedView();

  static const _filterKeys = <String?>[null, 'water', 'road', 'health', 'education', 'electricity', 'sanitation'];

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
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.communityFeed),
        backgroundColor: Colors.green.shade700,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => context.read<CommunityCubit>().loadReports(),
          ),
        ],
      ),
      body: Column(
        children: [
          // Leader info banner — shows panchayat leader contact details
          const _LeaderBanner(),
          // Filter chips
          Container(
            height: 48,
            color: Colors.white,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              itemCount: _filterKeys.length,
              itemBuilder: (context, i) {
                final key = _filterKeys[i];
                final label = _filterLabel(AppLocalizations.of(context), key);
                return BlocBuilder<CommunityCubit, CommunityState>(
                  builder: (context, state) {
                    final active = state is CommunityLoaded && state.activeFilter == key;
                    return Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: FilterChip(
                        label: Text(label, style: const TextStyle(fontSize: 12)),
                        selected: active,
                        onSelected: (_) => context.read<CommunityCubit>().loadReports(category: key),
                        selectedColor: Colors.green.shade100,
                      ),
                    );
                  },
                );
              },
            ),
          ),
          // Feed — responsive columns via LayoutBuilder
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final columns = constraints.maxWidth >= kTabletBreakpoint
                    ? 3
                    : constraints.maxWidth >= kMobileBreakpoint
                        ? 2
                        : 1;
                return BlocBuilder<CommunityCubit, CommunityState>(
                  builder: (context, state) {
                    if (state is CommunityLoading) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (state is CommunityError) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.error_outline, size: 48, color: Colors.red),
                            const SizedBox(height: 8),
                            Text(state.message),
                            TextButton(
                              onPressed: () => context.read<CommunityCubit>().loadReports(),
                              child: Text(AppLocalizations.of(context).retry),
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
                              const Icon(Icons.people_outline, size: 64, color: Colors.grey),
                              const SizedBox(height: 12),
                              Text(AppLocalizations.of(context).noReports, style: const TextStyle(color: Colors.grey)),
                            ],
                          ),
                        );
                      }
                      final rowCount = (state.reports.length / columns).ceil();
                      return RefreshIndicator(
                        onRefresh: () => context.read<CommunityCubit>().loadReports(),
                        child: Scrollbar(
                          thumbVisibility: columns > 1,
                          child: NotificationListener<ScrollNotification>(
                            onNotification: (n) {
                              if (n.metrics.pixels >= n.metrics.maxScrollExtent - 100) {
                                context.read<CommunityCubit>().loadMore();
                              }
                              return false;
                            },
                            child: ListView.builder(
                              padding: EdgeInsets.symmetric(
                                vertical: 8,
                                horizontal: columns > 1 ? 8 : 0,
                              ),
                              itemCount: rowCount + (state.hasMore ? 1 : 0),
                              itemBuilder: (context, rowIdx) {
                                if (rowIdx >= rowCount) {
                                  return const Center(
                                    child: Padding(
                                      padding: EdgeInsets.all(16),
                                      child: CircularProgressIndicator(),
                                    ),
                                  );
                                }
                                if (columns == 1) {
                                  final report = state.reports[rowIdx];
                                  return ReportCard(
                                    report: report,
                                    onVote: () => context.read<CommunityCubit>().vote(report.id),
                                    onTap: () => context.push('/report/${report.id}'),
                                  );
                                }
                                // Multi-column row with IntrinsicHeight for equal card heights
                                final start = rowIdx * columns;
                                final end = (start + columns).clamp(0, state.reports.length);
                                final rowReports = state.reports.sublist(start, end);
                                return IntrinsicHeight(
                                  child: Row(
                                    crossAxisAlignment: CrossAxisAlignment.stretch,
                                    children: [
                                      ...rowReports.map((report) => Expanded(
                                        child: ReportCard(
                                          report: report,
                                          onVote: () => context.read<CommunityCubit>().vote(report.id),
                                          onTap: () => context.push('/report/${report.id}'),
                                        ),
                                      )),
                                      // Pad incomplete last row
                                      for (int i = rowReports.length; i < columns; i++)
                                        const Expanded(child: SizedBox()),
                                    ],
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                      );
                    }
                    return const SizedBox.shrink();
                  },
                );
              },
            ),
          ),
        ],
      ),
      // FAB only shown on mobile — desktop has NavigationRail for navigation
      floatingActionButton: context.isMobile
          ? FloatingActionButton.extended(
              onPressed: () => context.go('/report'),
              icon: const Icon(Icons.add),
              label: Text(l10n.reportIssue),
              backgroundColor: Colors.green.shade700,
              foregroundColor: Colors.white,
            )
          : null,
    );
  }
}

/// Fetches and displays the panchayat leader's contact info above the feed.
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
    final panchayat = (_leader!['panchayat'] as String?) ?? '';
    final ward = _leader!['ward'];

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.green.shade50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.green.shade200),
      ),
      child: Row(
        children: [
          Icon(Icons.person_pin, color: Colors.green.shade700, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Gram Panchayat Leader',
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.green.shade700,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  name.isNotEmpty ? name : phone,
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                ),
                if (panchayat.isNotEmpty)
                  Text(
                    panchayat,
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                  ),
              ],
            ),
          ),
          if (ward != null) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
              decoration: BoxDecoration(
                color: Colors.green.shade100,
                borderRadius: BorderRadius.circular(5),
              ),
              child: Text(
                'Ward $ward',
                style: TextStyle(fontSize: 10, color: Colors.green.shade800, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(width: 8),
          ],
          GestureDetector(
            onTap: () async {
              final uri = Uri.parse('tel:$phone');
              if (await canLaunchUrl(uri)) launchUrl(uri);
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.green.shade700,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.phone, size: 13, color: Colors.white),
                  const SizedBox(width: 5),
                  Text(
                    phone,
                    style: const TextStyle(
                      fontSize: 11, color: Colors.white, fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class ReportCard extends StatelessWidget {
  final Report report;
  final VoidCallback onVote;
  final VoidCallback onTap;

  const ReportCard({super.key, required this.report, required this.onVote, required this.onTap});

  static Future<void> _openNavigation(double lat, double lng) async {
    final uri = Uri.parse(
      'https://www.google.com/maps/dir/?api=1&destination=$lat,$lng',
    );
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  bool get _isTranscriptionPending =>
      report.descriptionText.startsWith('[Voice note') ||
      report.descriptionText.startsWith('[Voice Note');

  @override
  Widget build(BuildContext context) {
    final hasLocation = report.latitude != null && report.longitude != null;
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top row: vote + icon + text content
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Vote button
                  Column(
                    children: [
                      IconButton(
                        icon: Icon(
                          report.hasVoted ? Icons.thumb_up : Icons.thumb_up_outlined,
                          color: report.hasVoted ? Colors.green.shade700 : null,
                        ),
                        onPressed: onVote,
                        visualDensity: VisualDensity.compact,
                      ),
                      Text(
                        '${report.voteCount}',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                      ),
                    ],
                  ),
                  const SizedBox(width: 10),
                  // Category icon
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: _categoryColor(report.category).withOpacity(0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(_categoryIcon(report.category), color: _categoryColor(report.category)),
                  ),
                  const SizedBox(width: 10),
                  // Content
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                report.subCategory.isNotEmpty ? report.subCategory : report.descriptionText,
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            _statusDot(report.status),
                          ],
                        ),
                        const SizedBox(height: 4),
                        // Show transcription pending state differently
                        if (_isTranscriptionPending)
                          Row(
                            children: [
                              Icon(Icons.access_time, size: 13, color: Colors.orange.shade600),
                              const SizedBox(width: 4),
                              Text(
                                'AI transcription in progress...',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.orange.shade700,
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                            ],
                          )
                        else
                          Text(
                            report.descriptionText,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                          ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            if (report.ward != null) ...[
                              Icon(Icons.map, size: 12, color: Colors.grey.shade500),
                              const SizedBox(width: 2),
                              Text('Ward ${report.ward}', style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
                              const SizedBox(width: 8),
                            ],
                            _urgencyBadge(report.urgency),
                            const Spacer(),
                            Text(
                              _timeAgo(report.createdAt),
                              style: TextStyle(fontSize: 11, color: Colors.grey.shade400),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              // Map thumbnail — only shown when GPS coordinates are available
              if (hasLocation) ...[
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: SizedBox(
                    height: 130,
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
                                  width: 36,
                                  height: 36,
                                  child: Icon(
                                    Icons.location_pin,
                                    color: _categoryColor(report.category),
                                    size: 36,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        // Navigate button overlay (bottom-right)
                        Positioned(
                          bottom: 8,
                          right: 8,
                          child: ElevatedButton.icon(
                            onPressed: () => _openNavigation(report.latitude!, report.longitude!),
                            icon: const Icon(Icons.navigation, size: 14),
                            label: const Text('Navigate', style: TextStyle(fontSize: 12)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white,
                              foregroundColor: Colors.blue.shade700,
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              elevation: 3,
                            ),
                          ),
                        ),
                        // Coordinates label (bottom-left)
                        Positioned(
                          bottom: 8,
                          left: 8,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                            decoration: BoxDecoration(
                              color: Colors.black54,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              '${report.latitude!.toStringAsFixed(4)}, ${report.longitude!.toStringAsFixed(4)}',
                              style: const TextStyle(color: Colors.white, fontSize: 9),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _statusDot(String status) {
    final color = status == 'completed' ? Colors.green
        : status == 'in_progress' ? Colors.blue
        : status == 'adopted' ? Colors.amber.shade700
        : status == 'delayed' ? Colors.red.shade900
        : Colors.red;
    return Container(
      width: 8, height: 8,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }

  Widget _urgencyBadge(String urgency) {
    final color = urgency == 'critical' ? Colors.red
        : urgency == 'high' ? Colors.deepOrange
        : urgency == 'medium' ? Colors.orange
        : Colors.green;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(color: color.withOpacity(0.15), borderRadius: BorderRadius.circular(4)),
      child: Text(urgency, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold)),
    );
  }

  Color _categoryColor(String cat) {
    switch (cat) {
      case 'water': return Colors.blue;
      case 'road': return Colors.orange;
      case 'health': return Colors.red;
      case 'education': return Colors.purple;
      case 'electricity': return Colors.yellow.shade800;
      case 'sanitation': return Colors.teal;
      default: return Colors.grey;
    }
  }

  IconData _categoryIcon(String cat) {
    switch (cat) {
      case 'water': return Icons.water_drop;
      case 'road': return Icons.add_road;
      case 'health': return Icons.local_hospital;
      case 'education': return Icons.school;
      case 'electricity': return Icons.bolt;
      case 'sanitation': return Icons.wc;
      default: return Icons.report_problem;
    }
  }

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inDays > 0) return '${diff.inDays}d ago';
    if (diff.inHours > 0) return '${diff.inHours}h ago';
    return '${diff.inMinutes}m ago';
  }
}
