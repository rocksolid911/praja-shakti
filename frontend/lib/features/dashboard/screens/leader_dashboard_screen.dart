import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import '../cubit/dashboard_cubit.dart';
import '../cubit/dashboard_state.dart';
import '../../../core/api/api_client.dart';
import '../../../core/models/project.dart';
import '../../../core/storage/secure_storage.dart';
import '../../../core/utils/responsive.dart';
import '../../../l10n/app_localizations.dart';
import '../../auth/cubit/auth_cubit.dart';

// ── Adopt + Proposal dialog (handles its own state to avoid context issues) ──

class _AdoptProjectDialog extends StatefulWidget {
  final PriorityCluster cluster;
  final ApiClient apiClient;
  const _AdoptProjectDialog({required this.cluster, required this.apiClient});

  @override
  State<_AdoptProjectDialog> createState() => _AdoptProjectDialogState();
}

class _AdoptProjectDialogState extends State<_AdoptProjectDialog> {
  bool _loading = false;
  Project? _adopted;
  String? _error;

  Future<void> _adopt() async {
    setState(() { _loading = true; _error = null; });
    try {
      final resp = await widget.apiClient.post('/projects/adopt/', data: {
        'cluster_id': widget.cluster.id,
        'recommendation_index': 0,
      });
      final project = Project.fromJson(resp.data as Map<String, dynamic>);
      setState(() { _loading = false; _adopted = project; });
    } catch (e) {
      setState(() { _loading = false; _error = 'Failed: $e'; });
    }
  }

  @override
  Widget build(BuildContext context) =>
      _adopted != null ? _proposalView(context) : _confirmView(context);

  Widget _confirmView(BuildContext context) {
    return AlertDialog(
      title: const Text('Adopt Project'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Category: ${widget.cluster.category.toUpperCase()}',
              style: const TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text('Reports: ${widget.cluster.reportCount}  •  Votes: ${widget.cluster.upvoteCount}'),
          Text('Priority Score: ${widget.cluster.totalScore.toStringAsFixed(0)}/100'),
          const SizedBox(height: 10),
          const Text(
            'Adopting will generate a PDF project proposal with government scheme funding plan.',
            style: TextStyle(color: Colors.grey, fontSize: 13),
          ),
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(_error!, style: const TextStyle(color: Colors.red, fontSize: 13)),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: _loading ? null : () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _loading ? null : _adopt,
          style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
          child: _loading
              ? const SizedBox(width: 16, height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Text('Adopt Project', style: TextStyle(color: Colors.white)),
        ),
      ],
    );
  }

  Widget _proposalView(BuildContext context) {
    final project = _adopted!;
    final fp = project.fundPlans.isNotEmpty ? project.fundPlans.first : null;

    return AlertDialog(
      title: Row(
        children: [
          const Icon(Icons.description, color: Colors.green),
          const SizedBox(width: 8),
          const Expanded(child: Text('Proposal Ready!')),
        ],
      ),
      content: SizedBox(
        width: 400,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(project.title,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
              const SizedBox(height: 12),
              _row('Total Cost', '₹${_fmt(project.estimatedCostInr)}'),
              _row('Beneficiaries', '${project.beneficiaryCount ?? "—"} households'),
              _row('Status', 'In Progress ✓', green: true),
              if (fp != null) ...[
                const SizedBox(height: 12),
                const Text('Fund Allocation',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                const Divider(height: 8),
                ...fp.schemesUsed.map((s) => _row(
                    s.schemeName,
                    '₹${_fmt(s.amountInr)} (${s.pctCovered.toStringAsFixed(0)}%)')),
                const Divider(height: 8),
                _row('Govt Schemes Cover',
                    '${fp.savingsPct.toStringAsFixed(0)}% of total', green: true),
                _row('Panchayat Pays',
                    '₹${_fmt(fp.panchayatContributionInr)}', green: true),
              ],
              const SizedBox(height: 10),
              Row(children: const [
                Icon(Icons.picture_as_pdf, color: Colors.green, size: 16),
                SizedBox(width: 6),
                Text('PDF proposal ready to download',
                    style: TextStyle(color: Colors.green, fontSize: 13)),
              ]),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('Close'),
        ),
        ElevatedButton.icon(
          onPressed: () => _download(context, project),
          icon: const Icon(Icons.download, size: 16),
          label: const Text('Download PDF'),
          style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green, foregroundColor: Colors.white),
        ),
      ],
    );
  }

  Widget _row(String label, String value, {bool green = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: 13, color: Colors.grey.shade700)),
          Text(value, style: TextStyle(
            fontSize: 13, fontWeight: FontWeight.w600,
            color: green ? Colors.green.shade700 : Colors.black87,
          )),
        ],
      ),
    );
  }

  Future<void> _download(BuildContext context, Project project) async {
    final rawUrl = project.proposalDownloadUrl;
    if (rawUrl == null) return;
    Uri uri;
    if (rawUrl.startsWith('http')) {
      uri = Uri.parse(rawUrl);
    } else {
      final base = widget.apiClient.baseUrl.replaceFirst(RegExp(r'/api/v1$'), '');
      final token = await SecureStorage.getAccessToken() ?? '';
      uri = Uri.parse('$base$rawUrl?token=$token');
    }
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  String _fmt(int cost) {
    if (cost >= 100000) return '${(cost / 100000).toStringAsFixed(1)}L';
    if (cost >= 1000) return '${(cost / 1000).toStringAsFixed(0)}K';
    return '$cost';
  }
}

class LeaderDashboardScreen extends StatelessWidget {
  const LeaderDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final authCubit = context.read<AuthCubit>();
    return BlocProvider(
      create: (_) => DashboardCubit(context.read<ApiClient>())
        ..loadDashboard(
          villageId: authCubit.currentVillageId,
          panchayatId: authCubit.currentPanchayatId,
        ),
      child: const _DashboardView(),
    );
  }
}

class _DashboardView extends StatelessWidget {
  const _DashboardView();

  void _reload(BuildContext context) {
    final auth = context.read<AuthCubit>();
    context.read<DashboardCubit>().loadDashboard(
      villageId: auth.currentVillageId,
      panchayatId: auth.currentPanchayatId,
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.read<AuthCubit>();
    final villageName = auth.currentUser?.villageName ?? '';
    final panchayatName = auth.currentUser?.panchayatName ?? '';
    final subtitle = villageName.isNotEmpty ? '$villageName • $panchayatName' : 'Select your village';

    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(AppLocalizations.of(context).leaderDashboard, style: const TextStyle(fontSize: 16)),
            Text(subtitle, style: const TextStyle(fontSize: 11, color: Colors.white70)),
          ],
        ),
        backgroundColor: Colors.blue.shade800,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => _reload(context),
          ),
        ],
      ),
      body: BlocBuilder<DashboardCubit, DashboardState>(
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
                    onPressed: () => _reload(context),
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
    final auth = context.read<AuthCubit>();
    return RefreshIndicator(
      onRefresh: () => context.read<DashboardCubit>().loadDashboard(
        villageId: auth.currentVillageId,
        panchayatId: auth.currentPanchayatId,
      ),
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

  void _showAdoptDialog(BuildContext context, PriorityCluster cluster) {
    final apiClient = context.read<ApiClient>();
    final cubit = context.read<DashboardCubit>();
    showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => _AdoptProjectDialog(
        cluster: cluster,
        apiClient: apiClient,
      ),
    ).then((adopted) {
      if (adopted == true && context.mounted) {
        cubit.loadDashboard();
      }
    });
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
