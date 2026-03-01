import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../core/api/api_client.dart';
import '../../../core/models/report.dart';

// ── State ─────────────────────────────────────────────────────────────────────

abstract class _GovState {}
class _GovLoading extends _GovState {}
class _GovError extends _GovState { final String msg; _GovError(this.msg); }
class _GovLoaded extends _GovState {
  final int totalReports;
  final int criticalReports;
  final int resolvedReports;
  final int activeProjects;
  final List<Report> topVoted;
  final List<Map<String, dynamic>> aiPriorities;

  _GovLoaded({
    required this.totalReports,
    required this.criticalReports,
    required this.resolvedReports,
    required this.activeProjects,
    required this.topVoted,
    required this.aiPriorities,
  });
}

// ── Cubit ─────────────────────────────────────────────────────────────────────

class _GovCubit extends Cubit<_GovState> {
  final ApiClient _api;
  _GovCubit(this._api) : super(_GovLoading());

  Future<void> load({int villageId = 1}) async {
    emit(_GovLoading());
    try {
      final resp = await _api.get(
        '/dashboard/government/',
        queryParameters: {'village': villageId},
      );
      final data = resp.data as Map<String, dynamic>;
      final summary = data['summary'] as Map<String, dynamic>;
      final rawReports = (data['top_voted_reports'] as List? ?? []);
      final rawPriorities = (data['ai_priority_ranking'] as List? ?? []);

      emit(_GovLoaded(
        totalReports: summary['total_reports'] ?? 0,
        criticalReports: summary['critical_reports'] ?? 0,
        resolvedReports: summary['resolved_reports'] ?? 0,
        activeProjects: summary['active_projects'] ?? 0,
        topVoted: rawReports.map((r) => Report.fromJson(r as Map<String, dynamic>)).toList(),
        aiPriorities: rawPriorities.cast<Map<String, dynamic>>(),
      ));
    } catch (e) {
      emit(_GovError('Failed to load: $e'));
    }
  }
}

// ── Screen ────────────────────────────────────────────────────────────────────

class GovernmentDashboardScreen extends StatelessWidget {
  const GovernmentDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => _GovCubit(context.read<ApiClient>())..load(),
      child: const _GovView(),
    );
  }
}

class _GovView extends StatelessWidget {
  const _GovView();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Government Dashboard', style: TextStyle(fontSize: 16)),
            Text('Panchayat Intelligence Overview', style: TextStyle(fontSize: 11, color: Colors.white70)),
          ],
        ),
        backgroundColor: Colors.indigo.shade700,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => context.read<_GovCubit>().load(),
          ),
        ],
      ),
      body: BlocBuilder<_GovCubit, _GovState>(
        builder: (context, state) {
          if (state is _GovLoading) return const Center(child: CircularProgressIndicator());
          if (state is _GovError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 48, color: Colors.red),
                  const SizedBox(height: 8),
                  Text(state.msg),
                  TextButton(
                    onPressed: () => context.read<_GovCubit>().load(),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            );
          }
          if (state is _GovLoaded) return _buildContent(context, state);
          return const SizedBox.shrink();
        },
      ),
    );
  }

  Widget _buildContent(BuildContext context, _GovLoaded state) {
    return RefreshIndicator(
      onRefresh: () => context.read<_GovCubit>().load(),
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ── Summary cards ─────────────────────────────────────────
          _SectionHeader(icon: Icons.analytics, title: 'Overview', color: Colors.indigo.shade700),
          const SizedBox(height: 10),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: 2.2,
            children: [
              _SummaryCard('Total Reports', '${state.totalReports}', Icons.report_outlined, Colors.blue),
              _SummaryCard('Critical', '${state.criticalReports}', Icons.warning_amber, Colors.red),
              _SummaryCard('Resolved', '${state.resolvedReports}', Icons.check_circle_outline, Colors.green),
              _SummaryCard('Active Projects', '${state.activeProjects}', Icons.construction, Colors.orange),
            ],
          ),
          const SizedBox(height: 24),

          // ── AI Priority Ranking ───────────────────────────────────
          _SectionHeader(icon: Icons.auto_awesome, title: 'AI Priority Ranking', color: Colors.deepPurple),
          const SizedBox(height: 10),
          if (state.aiPriorities.isEmpty)
            _EmptyCard('No priority data yet. Reports need to be clustered first.')
          else
            ...state.aiPriorities.asMap().entries.map((e) =>
              _PriorityRankCard(rank: e.key + 1, data: e.value),
            ),
          const SizedBox(height: 24),

          // ── Top Voted Reports ─────────────────────────────────────
          _SectionHeader(icon: Icons.thumb_up, title: 'Top Voted Reports', color: Colors.teal.shade700),
          const SizedBox(height: 10),
          if (state.topVoted.isEmpty)
            _EmptyCard('No reports yet.')
          else
            ...state.topVoted.map((r) => _TopReportCard(report: r)),
        ],
      ),
    );
  }
}

// ── Sub-widgets ───────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final String title;
  final Color color;
  const _SectionHeader({required this.icon, required this.title, required this.color});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(width: 8),
        Text(title, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color)),
      ],
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  const _SummaryCard(this.label, this.value, this.icon, this.color);

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(value, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                  Text(label, style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PriorityRankCard extends StatelessWidget {
  final int rank;
  final Map<String, dynamic> data;
  const _PriorityRankCard({required this.rank, required this.data});

  Color get _rankColor => rank == 1
      ? Colors.red
      : rank == 2
          ? Colors.deepOrange
          : rank <= 4 ? Colors.orange : Colors.blueGrey;

  @override
  Widget build(BuildContext context) {
    final score = (data['total_score'] ?? data['score'] ?? 0.0).toDouble();
    final category = data['category'] ?? data['cluster_category'] ?? '';
    final reportCount = data['report_count'] ?? 0;
    final community = (data['community_score'] ?? 0.0).toDouble();
    final dataScore = (data['data_score'] ?? 0.0).toDouble();
    final urgency = (data['urgency_score'] ?? 0.0).toDouble();

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            // Rank badge
            Container(
              width: 36, height: 36,
              decoration: BoxDecoration(color: _rankColor, borderRadius: BorderRadius.circular(8)),
              child: Center(
                child: Text('#$rank', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    category.toUpperCase(),
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      _ScoreChip('Community', community, Colors.blue),
                      const SizedBox(width: 6),
                      _ScoreChip('Data', dataScore, Colors.green),
                      const SizedBox(width: 6),
                      _ScoreChip('Urgency', urgency, Colors.orange),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text('$reportCount reports', style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
                ],
              ),
            ),
            // Total score circle
            Container(
              width: 52, height: 52,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: _rankColor, width: 2.5),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    score.toStringAsFixed(0),
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: _rankColor),
                  ),
                  Text('/100', style: TextStyle(fontSize: 8, color: Colors.grey.shade500)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ScoreChip extends StatelessWidget {
  final String label;
  final double value;
  final Color color;
  const _ScoreChip(this.label, this.value, this.color);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        '$label: ${value.toStringAsFixed(0)}',
        style: TextStyle(fontSize: 9, color: color, fontWeight: FontWeight.w600),
      ),
    );
  }
}

class _TopReportCard extends StatelessWidget {
  final Report report;
  const _TopReportCard({required this.report});

  @override
  Widget build(BuildContext context) {
    final catColor = _catColor(report.category);
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => context.push('/report/${report.id}'),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              // Vote count badge
              Container(
                width: 44, height: 44,
                decoration: BoxDecoration(
                  color: Colors.teal.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.thumb_up, size: 14, color: Colors.teal),
                    Text(
                      '${report.voteCount}',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              // Category icon
              Container(
                width: 36, height: 36,
                decoration: BoxDecoration(
                  color: catColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(_catIcon(report.category), color: catColor, size: 18),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      report.subCategory.isNotEmpty ? report.subCategory : report.descriptionText,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      report.villageName,
                      style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                    ),
                  ],
                ),
              ),
              // Urgency badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                decoration: BoxDecoration(
                  color: _urgencyColor(report.urgency).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  report.urgency.toUpperCase(),
                  style: TextStyle(
                    fontSize: 9, fontWeight: FontWeight.bold,
                    color: _urgencyColor(report.urgency),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _catColor(String cat) {
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

  IconData _catIcon(String cat) {
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

  Color _urgencyColor(String u) {
    switch (u) {
      case 'critical': return Colors.red;
      case 'high': return Colors.deepOrange;
      case 'medium': return Colors.orange;
      default: return Colors.green;
    }
  }
}

class _EmptyCard extends StatelessWidget {
  final String message;
  const _EmptyCard(this.message);

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Text(message, style: TextStyle(color: Colors.grey.shade500)),
      ),
    );
  }
}
