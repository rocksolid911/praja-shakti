import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../cubit/community_cubit.dart';
import '../cubit/community_state.dart';
import '../../../core/api/api_client.dart';
import '../../../core/models/report.dart';
import '../../../core/utils/responsive.dart';
import '../../../l10n/app_localizations.dart';

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

class ReportCard extends StatelessWidget {
  final Report report;
  final VoidCallback onVote;
  final VoidCallback onTap;

  const ReportCard({super.key, required this.report, required this.onVote, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
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
