import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../cubit/dashboard_cubit.dart';
import '../cubit/dashboard_state.dart';
import '../../../core/api/api_client.dart';

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
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Leader Dashboard', style: TextStyle(fontSize: 16)),
            Text('Tusra Village, Balangir', style: TextStyle(fontSize: 11, color: Colors.white70)),
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
                    onPressed: () => context.read<DashboardCubit>().loadDashboard(),
                    child: const Text('Retry'),
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
    return RefreshIndicator(
      onRefresh: () => context.read<DashboardCubit>().loadDashboard(),
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Summary cards
          Row(
            children: [
              Expanded(child: _SummaryCard(
                label: 'Reports', value: '${state.totalReports}',
                icon: Icons.report, color: Colors.red,
              )),
              const SizedBox(width: 10),
              Expanded(child: _SummaryCard(
                label: 'Active Projects', value: '${state.activeProjects.length}',
                icon: Icons.construction, color: Colors.blue,
              )),
              const SizedBox(width: 10),
              Expanded(child: _SummaryCard(
                label: 'Priorities', value: '${state.priorities.length}',
                icon: Icons.priority_high, color: Colors.orange,
              )),
            ],
          ),
          const SizedBox(height: 20),
          // Top priorities
          if (state.priorities.isNotEmpty) ...[
            const _SectionHeader(title: 'AI Priority Ranking', subtitle: 'Issues needing immediate attention'),
            const SizedBox(height: 10),
            ...state.priorities.take(5).toList().asMap().entries.map((e) =>
              _PriorityCard(
                rank: e.key + 1,
                cluster: e.value,
                onAdopt: () => _showAdoptDialog(context, e.value),
              ),
            ),
            const SizedBox(height: 20),
          ],
          // Active projects
          if (state.activeProjects.isNotEmpty) ...[
            const _SectionHeader(title: 'Active Projects', subtitle: 'Currently in progress'),
            const SizedBox(height: 10),
            ...state.activeProjects.map((p) => _ActiveProjectTile(project: p,
              onTap: () => context.push('/project/${p.id}'))),
            const SizedBox(height: 20),
          ],
          // Fund utilization
          if (state.fundStatus.isNotEmpty) ...[
            const _SectionHeader(title: 'Fund Utilization', subtitle: 'Budget tracking by category'),
            const SizedBox(height: 10),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: state.fundStatus.map((f) => _FundBar(fund: f)).toList(),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _showAdoptDialog(BuildContext context, PriorityCluster cluster) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('परियोजना अपनाएं'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('श्रेणी: ${cluster.category.toUpperCase()}'),
            Text('रिपोर्ट: ${cluster.reportCount}'),
            Text('Priority Score: ${cluster.totalScore.toStringAsFixed(0)}/100'),
            const SizedBox(height: 8),
            const Text('AI-generated proposal will be created automatically.',
                style: TextStyle(color: Colors.grey, fontSize: 13)),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              context.read<DashboardCubit>().adoptProject(cluster.id, 0);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('परियोजना स्वीकृत! प्रस्ताव तैयार हो रहा है...'),
                  backgroundColor: Colors.green,
                ),
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            child: const Text('Adopt Project', style: TextStyle(color: Colors.white)),
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
  final VoidCallback onAdopt;
  const _PriorityCard({required this.rank, required this.cluster, required this.onAdopt});

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
              child: const Text('Adopt'),
            ),
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
