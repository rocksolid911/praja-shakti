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

// ── Design constants ──────────────────────────────────────────────────────────
const _kIndigo = Color(0xFF3B5BDB);
const _kIndigoLight = Color(0xFFEDF2FF);
const _kCardRadius = 16.0;

// ── Adopt + Proposal dialog (handles its own state) ──────────────────────────

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
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Text('Adopt Project', style: TextStyle(fontWeight: FontWeight.w700)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Category: ${widget.cluster.category.toUpperCase()}',
              style: const TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text('Reports: ${widget.cluster.reportCount}  \u2022  Votes: ${widget.cluster.upvoteCount}'),
          Text('Priority Score: ${widget.cluster.totalScore.toStringAsFixed(0)}/100'),
          const SizedBox(height: 10),
          Text(
            'Adopting will generate a PDF project proposal with government scheme funding plan.',
            style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
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
          style: ElevatedButton.styleFrom(
            backgroundColor: _kIndigo,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
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
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Row(
        children: [
          Icon(Icons.description_rounded, color: Colors.green.shade600),
          const SizedBox(width: 8),
          const Expanded(child: Text('Proposal Ready!', style: TextStyle(fontWeight: FontWeight.w700))),
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
              _row('Total Cost', '\u20B9${_fmt(project.estimatedCostInr)}'),
              _row('Beneficiaries', '${project.beneficiaryCount ?? "\u2014"} households'),
              _row('Status', 'In Progress \u2713', green: true),
              if (fp != null) ...[
                const SizedBox(height: 12),
                const Text('Fund Allocation',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                const Divider(height: 8),
                ...fp.schemesUsed.map((s) => _row(
                    s.schemeName,
                    '\u20B9${_fmt(s.amountInr)} (${s.pctCovered.toStringAsFixed(0)}%)')),
                const Divider(height: 8),
                _row('Govt Schemes Cover',
                    '${fp.savingsPct.toStringAsFixed(0)}% of total', green: true),
                _row('Panchayat Pays',
                    '\u20B9${_fmt(fp.panchayatContributionInr)}', green: true),
              ],
              const SizedBox(height: 10),
              Row(children: [
                Icon(Icons.picture_as_pdf_rounded, color: Colors.green.shade600, size: 16),
                const SizedBox(width: 6),
                Text('PDF proposal ready to download',
                    style: TextStyle(color: Colors.green.shade600, fontSize: 13)),
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
          icon: const Icon(Icons.download_rounded, size: 16),
          label: const Text('Download PDF'),
          style: ElevatedButton.styleFrom(
              backgroundColor: _kIndigo, foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
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

// ── Main Screen ───────────────────────────────────────────────────────────────

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

// ── Dashboard View ────────────────────────────────────────────────────────────

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
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      body: BlocBuilder<DashboardCubit, DashboardState>(
        builder: (context, state) {
          if (state is DashboardLoading) {
            return const Center(child: CircularProgressIndicator(color: _kIndigo));
          }
          if (state is DashboardError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error_outline_rounded, size: 48, color: Colors.red.shade300),
                  const SizedBox(height: 12),
                  Text(state.message, style: TextStyle(color: Colors.grey.shade600)),
                  const SizedBox(height: 8),
                  TextButton.icon(
                    onPressed: () => _reload(context),
                    icon: const Icon(Icons.refresh_rounded),
                    label: Text(AppLocalizations.of(context).retry),
                  ),
                ],
              ),
            );
          }
          if (state is DashboardLoaded) {
            return LayoutBuilder(
              builder: (context, constraints) {
                if (constraints.maxWidth >= kTabletBreakpoint) {
                  return _buildDesktop(context, state);
                }
                return _buildMobile(context, state);
              },
            );
          }
          return const SizedBox.shrink();
        },
      ),
    );
  }

  // ── Mobile Layout ───────────────────────────────────────────────────────────

  Widget _buildMobile(BuildContext context, DashboardLoaded state) {
    final auth = context.read<AuthCubit>();
    final user = auth.currentUser;
    final villageName = user?.villageName ?? '';
    final l10n = AppLocalizations.of(context);

    return RefreshIndicator(
      color: _kIndigo,
      onRefresh: () => context.read<DashboardCubit>().loadDashboard(
        villageId: auth.currentVillageId,
        panchayatId: auth.currentPanchayatId,
      ),
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ── Custom Header ─────────────────────────────────────────────
          Row(
            children: [
              CircleAvatar(
                radius: 26,
                backgroundColor: _kIndigo,
                child: Text(
                  (user?.fullName ?? 'L').isNotEmpty ? (user!.fullName)[0].toUpperCase() : 'L',
                  style: const TextStyle(
                    color: Colors.white, fontWeight: FontWeight.w700, fontSize: 22,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      user?.fullName ?? 'Leader',
                      style: const TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 18,
                        color: Color(0xFF1A1A2E),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Container(
                          width: 8, height: 8,
                          decoration: const BoxDecoration(
                            color: Colors.green, shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Active Leader${villageName.isNotEmpty ? ' \u2022 $villageName' : ''}',
                          style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Stack(
                children: [
                  IconButton(
                    icon: Icon(Icons.notifications_outlined, color: Colors.grey.shade700),
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
            ],
          ),

          const SizedBox(height: 20),

          // ── Summary Cards ─────────────────────────────────────────────
          Row(
            children: [
              Expanded(child: _SummaryCard(
                label: l10n.reports, value: '${state.totalReports}',
                change: '+${state.priorities.length > 0 ? state.priorities.length * 4 : 0}',
                changeColor: Colors.red,
                onTap: () => context.push('/feed'),
              )),
              const SizedBox(width: 10),
              Expanded(child: _SummaryCard(
                label: l10n.projects, value: '${state.activeProjects.length}',
                change: '${state.completedProjects}',
                changeColor: Colors.grey,
                onTap: () => context.push('/projects'),
              )),
              const SizedBox(width: 10),
              Expanded(child: _SummaryCard(
                label: l10n.priorities, value: '${state.priorities.length}',
                change: '${state.priorities.where((p) => p.totalScore > 70).length}',
                changeColor: Colors.grey,
              )),
            ],
          ),

          const SizedBox(height: 28),

          // ── AI Priority Ranking ───────────────────────────────────────
          if (state.priorities.isNotEmpty) ...[
            Row(
              children: [
                const Icon(Icons.auto_awesome_rounded, color: _kIndigo, size: 22),
                const SizedBox(width: 8),
                Text(
                  l10n.aiPriorityRanking,
                  style: const TextStyle(
                    fontSize: 18, fontWeight: FontWeight.w700,
                    color: Color(0xFF1A1A2E),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            ...state.priorities.take(5).toList().asMap().entries.map((e) =>
              _PriorityCard(
                rank: e.key + 1,
                cluster: e.value,
                onAdopt: (context.read<AuthCubit>().currentUser?.isLeader ?? false)
                    ? () => _showAdoptDialog(context, e.value)
                    : null,
              ),
            ),
            const SizedBox(height: 24),
          ],

          // ── Fund Utilization ──────────────────────────────────────────
          if (state.fundStatus.isNotEmpty) ...[
            Row(
              children: [
                Icon(Icons.account_balance_wallet_rounded, color: _kIndigo, size: 22),
                const SizedBox(width: 8),
                Text(
                  l10n.fundUtilization,
                  style: const TextStyle(
                    fontSize: 18, fontWeight: FontWeight.w700,
                    color: Color(0xFF1A1A2E),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(_kCardRadius),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 8, offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                children: state.fundStatus.map((f) => _FundBar(fund: f)).toList(),
              ),
            ),
            const SizedBox(height: 24),
          ],

          // ── Active Projects ───────────────────────────────────────────
          if (state.activeProjects.isNotEmpty) ...[
            Row(
              children: [
                Icon(Icons.construction_rounded, color: _kIndigo, size: 22),
                const SizedBox(width: 8),
                Text(
                  l10n.activeProjects,
                  style: const TextStyle(
                    fontSize: 18, fontWeight: FontWeight.w700,
                    color: Color(0xFF1A1A2E),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            ...state.activeProjects.map((p) => _ActiveProjectCard(
              project: p,
              onTap: () => context.push('/project/${p.id}'),
            )),
          ],
        ],
      ),
    );
  }

  // ── Desktop Layout ──────────────────────────────────────────────────────────

  Widget _buildDesktop(BuildContext context, DashboardLoaded state) {
    final l10n = AppLocalizations.of(context);
    final auth = context.read<AuthCubit>();
    final user = auth.currentUser;
    final villageName = user?.villageName ?? '';
    final panchayatName = user?.panchayatName ?? '';
    final subtitle = villageName.isNotEmpty ? '$villageName \u2022 $panchayatName' : '';

    return Column(
      children: [
        // ── Top Bar ─────────────────────────────────────────────────────
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
          ),
          child: Row(
            children: [
              Text(
                l10n.leaderDashboard,
                style: const TextStyle(
                  fontSize: 20, fontWeight: FontWeight.w700,
                  color: Color(0xFF1A1A2E),
                ),
              ),
              const SizedBox(width: 16),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.green.shade200),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 8, height: 8,
                      decoration: const BoxDecoration(
                        color: Colors.green, shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Active Status: Online',
                      style: TextStyle(
                        fontSize: 12, fontWeight: FontWeight.w600,
                        color: Colors.green.shade700,
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              // Search
              Container(
                width: 220,
                height: 38,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    Icon(Icons.search_rounded, size: 18, color: Colors.grey.shade500),
                    const SizedBox(width: 8),
                    Text('Search data, reports...',
                        style: TextStyle(fontSize: 13, color: Colors.grey.shade500)),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Stack(
                children: [
                  IconButton(
                    icon: Icon(Icons.notifications_outlined, color: Colors.grey.shade700),
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
              IconButton(
                icon: const Icon(Icons.refresh_rounded),
                onPressed: () => _reload(context),
              ),
            ],
          ),
        ),

        // ── Content ─────────────────────────────────────────────────────
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Left column: summary + priorities
              Expanded(
                flex: 3,
                child: Scrollbar(
                  thumbVisibility: true,
                  child: ListView(
                    padding: const EdgeInsets.all(24),
                    children: [
                      // Summary cards
                      Row(
                        children: [
                          Expanded(child: _DesktopSummaryCard(
                            icon: Icons.description_outlined,
                            iconColor: _kIndigo,
                            label: 'Total Reports', value: '${state.totalReports}',
                            badge: '+${state.priorities.length > 0 ? state.priorities.length * 4 : 0}%',
                            badgeColor: Colors.red,
                            onTap: () => context.push('/feed'),
                          )),
                          const SizedBox(width: 14),
                          Expanded(child: _DesktopSummaryCard(
                            icon: Icons.construction_outlined,
                            iconColor: Colors.orange,
                            label: l10n.activeProjects, value: '${state.activeProjects.length}',
                            badge: 'No change',
                            badgeColor: Colors.grey,
                            onTap: () => context.push('/projects'),
                          )),
                          const SizedBox(width: 14),
                          Expanded(child: _DesktopSummaryCard(
                            icon: Icons.priority_high_rounded,
                            iconColor: Colors.red,
                            label: 'Critical Priorities', value: '${state.priorities.length}',
                            badge: 'Stable',
                            badgeColor: Colors.grey,
                          )),
                        ],
                      ),
                      const SizedBox(height: 28),

                      // AI Priority Ranking
                      if (state.priorities.isNotEmpty) ...[
                        Row(
                          children: [
                            const Icon(Icons.auto_awesome_rounded, color: _kIndigo, size: 22),
                            const SizedBox(width: 8),
                            Text(
                              l10n.aiPriorityRanking,
                              style: const TextStyle(
                                fontSize: 18, fontWeight: FontWeight.w700,
                                color: Color(0xFF1A1A2E),
                              ),
                            ),
                            const Spacer(),
                            TextButton(
                              onPressed: () {},
                              child: Text(
                                'View AI Analysis',
                                style: TextStyle(color: _kIndigo, fontWeight: FontWeight.w600),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        ...state.priorities.take(5).toList().asMap().entries.map((e) =>
                          _PriorityCard(
                            rank: e.key + 1,
                            cluster: e.value,
                            isDesktop: true,
                            onAdopt: (context.read<AuthCubit>().currentUser?.isLeader ?? false)
                                ? () => _showAdoptDialog(context, e.value)
                                : null,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),

              // Divider
              Container(width: 1, color: Colors.grey.shade200),

              // Right column: fund + projects
              SizedBox(
                width: 340,
                child: Scrollbar(
                  thumbVisibility: true,
                  child: ListView(
                    padding: const EdgeInsets.all(24),
                    children: [
                      // Fund Utilization
                      if (state.fundStatus.isNotEmpty) ...[
                        Row(
                          children: [
                            Icon(Icons.account_balance_wallet_rounded, color: _kIndigo, size: 20),
                            const SizedBox(width: 8),
                            Text(
                              l10n.fundUtilization,
                              style: const TextStyle(
                                fontSize: 16, fontWeight: FontWeight.w700,
                                color: Color(0xFF1A1A2E),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(_kCardRadius),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.04),
                                blurRadius: 8, offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Column(
                            children: [
                              ...state.fundStatus.map((f) => _FundBar(fund: f)),
                              const SizedBox(height: 8),
                              SizedBox(
                                width: double.infinity,
                                child: OutlinedButton(
                                  onPressed: () {},
                                  style: OutlinedButton.styleFrom(
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                  ),
                                  child: const Text('Request Extra Budget'),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 28),
                      ],

                      // Active Projects
                      if (state.activeProjects.isNotEmpty) ...[
                        Row(
                          children: [
                            Icon(Icons.construction_rounded, color: _kIndigo, size: 20),
                            const SizedBox(width: 8),
                            Text(
                              l10n.activeProjects,
                              style: const TextStyle(
                                fontSize: 16, fontWeight: FontWeight.w700,
                                color: Color(0xFF1A1A2E),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        ...state.activeProjects.map((p) => _ActiveProjectCard(
                          project: p,
                          onTap: () => context.push('/project/${p.id}'),
                        )),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
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

// ── Summary Card (Mobile) ─────────────────────────────────────────────────────

class _SummaryCard extends StatelessWidget {
  final String label, value, change;
  final Color changeColor;
  final VoidCallback? onTap;
  const _SummaryCard({
    required this.label, required this.value,
    required this.change, required this.changeColor,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8, offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 11, fontWeight: FontWeight.w600,
                    color: Colors.grey.shade600,
                  ),
                ),
                if (change.isNotEmpty)
                  Text(
                    change,
                    style: TextStyle(
                      fontSize: 10, fontWeight: FontWeight.w700,
                      color: changeColor,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              value,
              style: const TextStyle(
                fontSize: 26, fontWeight: FontWeight.w800,
                color: Color(0xFF1A1A2E),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Summary Card (Desktop) ────────────────────────────────────────────────────

class _DesktopSummaryCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label, value, badge;
  final Color badgeColor;
  final VoidCallback? onTap;
  const _DesktopSummaryCard({
    required this.icon, required this.iconColor,
    required this.label, required this.value,
    required this.badge, required this.badgeColor,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(_kCardRadius),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(_kCardRadius),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8, offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: iconColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: iconColor, size: 22),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: badgeColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    badge,
                    style: TextStyle(
                      fontSize: 11, fontWeight: FontWeight.w700,
                      color: badgeColor,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Text(label, style: TextStyle(fontSize: 13, color: Colors.grey.shade600)),
            const SizedBox(height: 4),
            Text(
              value,
              style: const TextStyle(
                fontSize: 28, fontWeight: FontWeight.w800,
                color: Color(0xFF1A1A2E),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Priority Card ─────────────────────────────────────────────────────────────

class _PriorityCard extends StatelessWidget {
  final int rank;
  final PriorityCluster cluster;
  final VoidCallback? onAdopt;
  final bool isDesktop;
  const _PriorityCard({
    required this.rank, required this.cluster, this.onAdopt, this.isDesktop = false,
  });

  @override
  Widget build(BuildContext context) {
    final score = cluster.totalScore;
    final isCritical = score > 70;
    final isHigh = score > 40;
    final borderColor = isCritical ? Colors.red : isHigh ? Colors.orange : Colors.blue;
    final l10n = AppLocalizations.of(context);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(_kCardRadius),
        border: Border(
          left: BorderSide(color: borderColor, width: 4),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8, offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Badges + urgency timer row ──
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: isCritical ? Colors.red : isHigh ? Colors.orange : Colors.blue,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    isCritical ? 'CRITICAL' : isHigh ? 'HIGH PRIORITY' : 'MODERATE',
                    style: const TextStyle(
                      color: Colors.white, fontSize: 10, fontWeight: FontWeight.w800,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                if (isCritical) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.access_time_rounded, size: 12, color: Colors.red.shade700),
                        const SizedBox(width: 4),
                        Text(
                          '48H URGENT',
                          style: TextStyle(
                            fontSize: 10, fontWeight: FontWeight.w800,
                            color: Colors.red.shade700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const Spacer(),
                if (isDesktop) ...[
                  // Vote counts for desktop
                  Icon(Icons.thumb_up_rounded, size: 14, color: Colors.grey.shade500),
                  const SizedBox(width: 4),
                  Text('${cluster.upvoteCount}',
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade600, fontWeight: FontWeight.w600)),
                  const SizedBox(width: 10),
                  Icon(Icons.thumb_down_rounded, size: 14, color: Colors.grey.shade500),
                  const SizedBox(width: 4),
                  Text('${cluster.reportCount}',
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade600, fontWeight: FontWeight.w600)),
                ],
              ],
            ),

            const SizedBox(height: 12),

            // ── Title + location ──
            Text(
              '${cluster.category[0].toUpperCase()}${cluster.category.substring(1)} Supply Issues',
              style: const TextStyle(
                fontWeight: FontWeight.w700, fontSize: 17,
                color: Color(0xFF1A1A2E),
              ),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(Icons.location_on_rounded, size: 14, color: Colors.grey.shade500),
                const SizedBox(width: 4),
                Text(
                  '${cluster.reportCount} reports in cluster',
                  style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                ),
              ],
            ),

            const SizedBox(height: 14),

            // ── Score bars ──
            _ScoreBar(label: 'Community Score', value: cluster.communityScore, maxValue: 10, color: _kIndigo),
            const SizedBox(height: 8),
            _ScoreBar(label: 'Data Urgency', value: cluster.urgencyScore, maxValue: 10, color: Colors.orange),

            const SizedBox(height: 14),

            // ── Bottom row: votes + action ──
            Row(
              children: [
                if (!isDesktop) ...[
                  Icon(Icons.thumb_up_rounded, size: 16, color: Colors.grey.shade500),
                  const SizedBox(width: 4),
                  Text('${cluster.upvoteCount}',
                      style: TextStyle(fontSize: 13, color: Colors.grey.shade600, fontWeight: FontWeight.w600)),
                  const SizedBox(width: 14),
                  Icon(Icons.thumb_down_rounded, size: 16, color: Colors.grey.shade500),
                  const SizedBox(width: 4),
                  Text('${cluster.reportCount}',
                      style: TextStyle(fontSize: 13, color: Colors.grey.shade600, fontWeight: FontWeight.w600)),
                ],
                const Spacer(),
                if (onAdopt != null) ...[
                  if (isDesktop) ...[
                    ElevatedButton(
                      onPressed: onAdopt,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _kIndigo,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      ),
                      child: const Text('Assign Task Force', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton(
                      onPressed: () {},
                      style: OutlinedButton.styleFrom(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      ),
                      child: const Text('View Detail', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                    ),
                  ] else
                    ElevatedButton(
                      onPressed: onAdopt,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isCritical ? _kIndigo : Colors.white,
                        foregroundColor: isCritical ? Colors.white : _kIndigo,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                          side: isCritical ? BorderSide.none : BorderSide(color: _kIndigo),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                      ),
                      child: Text(
                        isCritical ? 'TAKE ACTION' : 'REVIEW',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                      ),
                    ),
                ],
              ],
            ),

            // Impact score for desktop
            if (isDesktop) ...[
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('IMPACT SCORE', style: TextStyle(fontSize: 10, color: Colors.grey.shade500, fontWeight: FontWeight.w600)),
                    Text(
                      '${(score / 10).toStringAsFixed(1)}/10',
                      style: TextStyle(
                        fontSize: 24, fontWeight: FontWeight.w800,
                        color: isCritical ? Colors.red : isHigh ? Colors.orange : Colors.green,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ── Score Bar ─────────────────────────────────────────────────────────────────

class _ScoreBar extends StatelessWidget {
  final String label;
  final double value, maxValue;
  final Color color;
  const _ScoreBar({required this.label, required this.value, required this.maxValue, required this.color});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 120,
          child: Text(
            label,
            style: TextStyle(fontSize: 13, color: Colors.grey.shade600, fontWeight: FontWeight.w500),
          ),
        ),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: (value / maxValue).clamp(0.0, 1.0),
              backgroundColor: Colors.grey.shade200,
              valueColor: AlwaysStoppedAnimation(color),
              minHeight: 8,
            ),
          ),
        ),
        const SizedBox(width: 10),
        SizedBox(
          width: 30,
          child: Text(
            value.toStringAsFixed(1),
            textAlign: TextAlign.end,
            style: TextStyle(
              fontSize: 13, fontWeight: FontWeight.w700, color: color,
            ),
          ),
        ),
      ],
    );
  }
}

// ── Fund Bar ──────────────────────────────────────────────────────────────────

class _FundBar extends StatelessWidget {
  final FundStatus fund;
  const _FundBar({required this.fund});

  @override
  Widget build(BuildContext context) {
    final pct = fund.utilizationPct.clamp(0.0, 100.0);
    final barColor = pct > 80 ? Colors.green : pct > 50 ? _kIndigo : Colors.orange;

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                fund.category[0].toUpperCase() + fund.category.substring(1),
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
              ),
              Text(
                '${pct.toStringAsFixed(0)}%',
                style: TextStyle(
                  fontSize: 14, fontWeight: FontWeight.w800, color: barColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: pct / 100,
              backgroundColor: Colors.grey.shade200,
              valueColor: AlwaysStoppedAnimation(barColor),
              minHeight: 8,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '\u20B9${_formatCost(fund.spentInr)} spent of \u20B9${_formatCost(fund.allocatedInr)}',
            style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
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

// ── Active Project Card ───────────────────────────────────────────────────────

class _ActiveProjectCard extends StatelessWidget {
  final dynamic project;
  final VoidCallback onTap;
  const _ActiveProjectCard({required this.project, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final title = project.title ?? '';
    final cost = project.estimatedCostInr ?? 0;
    final beneficiaries = project.beneficiaryCount ?? 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(_kCardRadius),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8, offset: const Offset(0, 2),
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
              Row(
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: Colors.green.shade50,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: Colors.green.shade200),
                    ),
                    child: Text(
                      'ON TRACK',
                      style: TextStyle(
                        fontSize: 10, fontWeight: FontWeight.w800,
                        color: Colors.green.shade700,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: 0.65,
                  backgroundColor: Colors.grey.shade200,
                  valueColor: const AlwaysStoppedAnimation(_kIndigo),
                  minHeight: 8,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Text(
                    '65%',
                    style: TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w700, color: _kIndigo,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '\u20B9${_formatCost(cost)} \u2022 $beneficiaries beneficiaries',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatCost(int cost) {
    if (cost >= 100000) return '${(cost / 100000).toStringAsFixed(1)}L';
    if (cost >= 1000) return '${(cost / 1000).toStringAsFixed(0)}K';
    return '$cost';
  }
}
