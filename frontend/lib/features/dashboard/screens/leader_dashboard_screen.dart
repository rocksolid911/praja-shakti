import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import '../cubit/dashboard_cubit.dart';
import '../cubit/dashboard_state.dart';
import '../../../core/api/api_client.dart';
import '../../../core/models/project.dart';
import '../../../core/utils/responsive.dart';
import '../../../l10n/app_localizations.dart';
import '../../auth/cubit/auth_cubit.dart';

class LeaderDashboardScreen extends StatelessWidget {
  const LeaderDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => DashboardCubit(context.read<ApiClient>())..loadDashboard(),
      child: const _DashboardView(),
    );
  }
}

class _DashboardView extends StatelessWidget {
  const _DashboardView();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(AppLocalizations.of(context).leaderDashboard, style: const TextStyle(fontSize: 16)),
            const Text('Tusra Village, Balangir', style: TextStyle(fontSize: 11, color: Colors.white70)),
          ],
        ),
        backgroundColor: Colors.blue.shade800,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => context.read<DashboardCubit>().loadDashboard(),
          ),
        ],
      ),
      body: BlocConsumer<DashboardCubit, DashboardState>(
        listener: (context, state) {
          if (state is DashboardLoaded && state.lastAdoptedProject != null) {
            _showProposalDialog(context, state.lastAdoptedProject!);
          }
        },
        builder: (context, state) {
          if (state is DashboardLoading) return const Center(child: CircularProgressIndicator());
          if (state is DashboardError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 48, color: Colors.red),
                  Text(state.message),
                  TextButton(
                    onPressed: () => context.read<DashboardCubit>().loadDashboard(),
                    child: Text(AppLocalizations.of(context).retry),
                  ),
                ],
              ),
            );
          }
          if (state is DashboardLoaded) return _buildDashboard(context, state);
          return const SizedBox.shrink();
        },
      ),
    );
  }

  Widget _buildDashboard(BuildContext context, DashboardLoaded state) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= kTabletBreakpoint) {
          return _buildDesktopDashboard(context, state);
        }
        return _buildMobileDashboard(context, state);
      },
    );
  }

  Widget _buildMobileDashboard(BuildContext context, DashboardLoaded state) {
    return RefreshIndicator(
      onRefresh: () => context.read<DashboardCubit>().loadDashboard(),
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          ..._summaryCards(context, state),
          const SizedBox(height: 20),
          ..._prioritySection(context, state),
          ..._activeProjectsSection(context, state),
          ..._fundSection(context, state),
        ],
      ),
    );
  }

  Widget _buildDesktopDashboard(BuildContext context, DashboardLoaded state) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Left column: summary + priority ranking
        Expanded(
          child: Scrollbar(
            thumbVisibility: true,
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                ..._summaryCards(context, state),
                const SizedBox(height: 24),
                ..._prioritySection(context, state),
              ],
            ),
          ),
        ),
        const VerticalDivider(thickness: 1, width: 1),
        // Right column: active projects + fund utilization
        Expanded(
          child: Scrollbar(
            thumbVisibility: true,
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                ..._activeProjectsSection(context, state),
                ..._fundSection(context, state),
              ],
            ),
          ),
        ),
      ],
    );
  }

  List<Widget> _summaryCards(BuildContext context, DashboardLoaded state) {
    final l10n = AppLocalizations.of(context);
    return [
      Row(
        children: [
          Expanded(child: _SummaryCard(
            label: l10n.reports, value: '${state.totalReports}',
            icon: Icons.report, color: Colors.red,
          )),
          const SizedBox(width: 10),
          Expanded(child: _SummaryCard(
            label: l10n.activeProjects, value: '${state.activeProjects.length}',
            icon: Icons.construction, color: Colors.blue,
          )),
          const SizedBox(width: 10),
          Expanded(child: _SummaryCard(
            label: l10n.priorities, value: '${state.priorities.length}',
            icon: Icons.priority_high, color: Colors.orange,
          )),
        ],
      ),
    ];
  }

  List<Widget> _prioritySection(BuildContext context, DashboardLoaded state) {
    if (state.priorities.isEmpty) return [];
    final l10n = AppLocalizations.of(context);
    final isLeader = context.read<AuthCubit>().currentUser?.isLeader ?? false;
    return [
      _SectionHeader(title: l10n.aiPriorityRanking, subtitle: l10n.issuesNeedingAttention),
      const SizedBox(height: 10),
      ...state.priorities.take(5).toList().asMap().entries.map((e) =>
        _PriorityCard(
          rank: e.key + 1,
          cluster: e.value,
          onAdopt: isLeader ? () => _showAdoptDialog(context, e.value) : null,
        ),
      ),
      const SizedBox(height: 20),
    ];
  }

  List<Widget> _activeProjectsSection(BuildContext context, DashboardLoaded state) {
    if (state.activeProjects.isEmpty) return [];
    final l10n = AppLocalizations.of(context);
    return [
      _SectionHeader(title: l10n.activeProjects, subtitle: l10n.currentlyInProgress),
      const SizedBox(height: 10),
      ...state.activeProjects.map((p) => _ActiveProjectTile(
        project: p,
        onTap: () => context.push('/project/${p.id}'),
      )),
      const SizedBox(height: 20),
    ];
  }

  List<Widget> _fundSection(BuildContext context, DashboardLoaded state) {
    if (state.fundStatus.isEmpty) return [];
    final l10n = AppLocalizations.of(context);
    return [
      _SectionHeader(title: l10n.fundUtilization, subtitle: l10n.budgetTracking),
      const SizedBox(height: 10),
      Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: state.fundStatus.map((f) => _FundBar(fund: f)).toList(),
          ),
        ),
      ),
    ];
  }

  void _showProposalDialog(BuildContext context, Project project) {
    final l10n = AppLocalizations.of(context);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: Row(
            children: [
              const Icon(Icons.description, color: Colors.green),
              const SizedBox(width: 8),
              Text(l10n.proposalReady),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(project.title, style: const TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              if (project.fundPlans.isNotEmpty) ...[
                Text('${l10n.totalCost}: ₹${_formatCostStatic(project.estimatedCostInr)}'),
                ...project.fundPlans.take(1).map((fp) => Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${l10n.subsidyLabel}: ${fp.savingsPct.toStringAsFixed(0)}% ${l10n.subsidySavings}'),
                    ...fp.schemesUsed.take(2).map((s) => Text(
                      '• ${s.schemeName}: ₹${_formatCostStatic(s.amountInr)}',
                      style: const TextStyle(fontSize: 13, color: Colors.grey),
                    )),
                  ],
                )),
              ],
              const SizedBox(height: 8),
              if (project.proposalDownloadUrl != null)
                Text(l10n.pdfProposalReady,
                    style: const TextStyle(color: Colors.grey, fontSize: 13))
              else
                Text(l10n.generatingProposal,
                    style: const TextStyle(color: Colors.grey, fontSize: 13)),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: Text(l10n.close)),
            if (project.proposalDownloadUrl != null)
              ElevatedButton.icon(
                onPressed: () async {
                  Navigator.pop(context);
                  final uri = Uri.parse(project.proposalDownloadUrl!);
                  if (await canLaunchUrl(uri)) {
                    await launchUrl(uri, mode: LaunchMode.externalApplication);
                  }
                },
                icon: const Icon(Icons.download),
                label: Text(l10n.downloadPdf),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
              ),
          ],
        ),
      );
    });
  }

  static String _formatCostStatic(int cost) {
    if (cost >= 100000) return '${(cost / 100000).toStringAsFixed(1)}L';
    if (cost >= 1000) return '${(cost / 1000).toStringAsFixed(0)}K';
    return '$cost';
  }

  void _showAdoptDialog(BuildContext context, PriorityCluster cluster) {
    final l10n = AppLocalizations.of(context);
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(l10n.adoptProject),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${l10n.categoryLabel}: ${cluster.category.toUpperCase()}'),
            Text('${l10n.reports}: ${cluster.reportCount}'),
            Text('${l10n.priority}: ${cluster.totalScore.toStringAsFixed(0)}/100'),
            const SizedBox(height: 8),
            Text(l10n.aiProposalNote, style: const TextStyle(color: Colors.grey, fontSize: 13)),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text(l10n.cancel)),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              context.read<DashboardCubit>().adoptProject(cluster.id, 0);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(l10n.projectAdoptedSnackbar),
                  backgroundColor: Colors.green,
                ),
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            child: Text(l10n.adoptProject, style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final String label, value;
  final IconData icon;
  final Color color;
  const _SummaryCard({required this.label, required this.value, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 6),
            Text(value, style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: color)),
            Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey), textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title, subtitle;
  const _SectionHeader({required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
        Text(subtitle, style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
      ],
    );
  }
}

class _PriorityCard extends StatelessWidget {
  final int rank;
  final PriorityCluster cluster;
  final VoidCallback? onAdopt;
  const _PriorityCard({required this.rank, required this.cluster, this.onAdopt});

  @override
  Widget build(BuildContext context) {
    final score = cluster.totalScore;
    final color = score > 70 ? Colors.red : score > 40 ? Colors.orange : Colors.green;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            // Rank + Score
            Container(
              width: 56, height: 56,
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: color.withOpacity(0.3)),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('$rank', style: TextStyle(fontWeight: FontWeight.bold, color: color, fontSize: 18)),
                  Text('${score.toStringAsFixed(0)}', style: TextStyle(fontSize: 10, color: color)),
                ],
              ),
            ),
            const SizedBox(width: 12),
            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      _categoryChip(cluster.category),
                      const Spacer(),
                      Text('${cluster.reportCount} reports • ${cluster.upvoteCount} votes',
                          style: const TextStyle(fontSize: 11, color: Colors.grey)),
                    ],
                  ),
                  const SizedBox(height: 6),
                  // Score breakdown bar
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: score / 100,
                      backgroundColor: Colors.grey.shade200,
                      valueColor: AlwaysStoppedAnimation(color),
                      minHeight: 6,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      _scorePill('Community', cluster.communityScore, Colors.green),
                      _scorePill('Data', cluster.dataScore, Colors.blue),
                      _scorePill('Urgency', cluster.urgencyScore, Colors.orange),
                    ],
                  ),
                ],
              ),
            ),
            if (onAdopt != null) ...[
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: onAdopt,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green.shade700,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  minimumSize: const Size(60, 32),
                  textStyle: const TextStyle(fontSize: 12),
                ),
                child: Text(AppLocalizations.of(context).adopt),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _categoryChip(String category) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: _categoryColor(category).withOpacity(0.15),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        category.toUpperCase(),
        style: TextStyle(color: _categoryColor(category), fontSize: 11, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _scorePill(String label, double score, Color color) {
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: Text(
        '$label: ${score.toStringAsFixed(0)}',
        style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.bold),
      ),
    );
  }

  Color _categoryColor(String cat) {
    switch (cat) {
      case 'water': return Colors.blue;
      case 'road': return Colors.orange;
      case 'health': return Colors.red;
      default: return Colors.grey;
    }
  }
}

class _ActiveProjectTile extends StatelessWidget {
  final dynamic project;
  final VoidCallback onTap;
  const _ActiveProjectTile({required this.project, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        onTap: onTap,
        leading: Container(
          width: 44, height: 44,
          decoration: BoxDecoration(color: Colors.blue.shade100, borderRadius: BorderRadius.circular(10)),
          child: Icon(Icons.construction, color: Colors.blue.shade700),
        ),
        title: Text(project.title ?? '', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
        subtitle: Text(
          '₹${_formatCost(project.estimatedCostInr ?? 0)} • ${project.beneficiaryCount ?? 0} beneficiaries',
          style: const TextStyle(fontSize: 12),
        ),
        trailing: const Icon(Icons.arrow_forward_ios, size: 14),
      ),
    );
  }

  String _formatCost(int cost) {
    if (cost >= 100000) return '${(cost / 100000).toStringAsFixed(1)}L';
    if (cost >= 1000) return '${(cost / 1000).toStringAsFixed(0)}K';
    return '$cost';
  }
}

class _FundBar extends StatelessWidget {
  final FundStatus fund;
  const _FundBar({required this.fund});

  @override
  Widget build(BuildContext context) {
    final pct = fund.utilizationPct.clamp(0.0, 100.0);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(fund.category.toUpperCase(), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
              Text('${pct.toStringAsFixed(0)}%', style: TextStyle(
                fontSize: 12,
                color: pct > 80 ? Colors.green : pct > 50 ? Colors.orange : Colors.red,
                fontWeight: FontWeight.bold,
              )),
            ],
          ),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: pct / 100,
              backgroundColor: Colors.grey.shade200,
              valueColor: AlwaysStoppedAnimation(
                pct > 80 ? Colors.green : pct > 50 ? Colors.orange : Colors.red,
              ),
              minHeight: 8,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            '₹${_formatCost(fund.spentInr)} spent of ₹${_formatCost(fund.allocatedInr)}',
            style: const TextStyle(fontSize: 10, color: Colors.grey),
          ),
        ],
      ),
    );
  }

  String _formatCost(int cost) {
    if (cost >= 100000) return '${(cost / 100000).toStringAsFixed(1)}L';
    if (cost >= 1000) return '${(cost / 1000).toStringAsFixed(0)}K';
    return '$cost';
  }
}
