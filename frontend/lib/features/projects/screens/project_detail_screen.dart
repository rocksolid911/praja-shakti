import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import '../cubit/project_cubit.dart';
import '../cubit/project_state.dart';
import '../../../core/api/api_client.dart';
import '../../../core/models/project.dart';
import '../../../l10n/app_localizations.dart';
import '../../auth/cubit/auth_cubit.dart';
import '../../auth/cubit/auth_state.dart';

class ProjectDetailScreen extends StatelessWidget {
  final int projectId;
  const ProjectDetailScreen({super.key, required this.projectId});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => ProjectCubit(context.read<ApiClient>())..loadProjectDetail(projectId),
      child: const _ProjectDetailView(),
    );
  }
}

class _ProjectDetailView extends StatelessWidget {
  const _ProjectDetailView();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(AppLocalizations.of(context).projectDetails)),
      body: BlocBuilder<ProjectCubit, ProjectState>(
        builder: (context, state) {
          if (state is ProjectLoading) return const Center(child: CircularProgressIndicator());
          if (state is ProjectError) return Center(child: Text(state.message));
          if (state is ProjectDetailLoaded) return _ProjectDetail(project: state.project);
          return const SizedBox.shrink();
        },
      ),
    );
  }
}

class _ProjectDetail extends StatelessWidget {
  final Project project;
  const _ProjectDetail({required this.project});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final authState = context.watch<AuthCubit>().state;
    final isLeader = (authState is AuthAuthenticated && authState.user.isLeader) ||
        (authState is AuthProfileLoaded && authState.user.isLeader);
    final canUpdateStatus = isLeader &&
        (project.status == 'in_progress' || project.status == 'delayed');
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        // Header
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.blue.shade700, Colors.blue.shade500],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(project.title,
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
              const SizedBox(height: 6),
              Text(project.villageName, style: const TextStyle(color: Colors.white70, fontSize: 13)),
              const SizedBox(height: 12),
              Row(
                children: [
                  _headerStat(l10n.costLabel, '₹${_formatCost(project.estimatedCostInr)}'),
                  const SizedBox(width: 20),
                  if (project.beneficiaryCount != null)
                    _headerStat(l10n.beneficiaries, '${project.beneficiaryCount}'),
                  const SizedBox(width: 20),
                  if (project.priorityScore != null)
                    _headerStat(l10n.priority, '${project.priorityScore!.toStringAsFixed(0)}/100'),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        // Status timeline
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l10n.projectStatus, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 16),
                _TimelineItem(
                  label: l10n.aiRecommended,
                  date: project.createdAt,
                  done: true,
                  icon: Icons.auto_awesome,
                  color: Colors.purple,
                ),
                _TimelineItem(
                  label: l10n.adopted,
                  date: project.adoptedAt,
                  done: project.adoptedAt != null,
                  icon: Icons.check_circle,
                  color: Colors.amber.shade700,
                ),
                _TimelineItem(
                  label: l10n.inProgress,
                  date: project.startedAt,
                  done: project.startedAt != null,
                  icon: Icons.construction,
                  color: Colors.blue,
                ),
                _TimelineItem(
                  label: l10n.completed,
                  date: project.completedAt,
                  done: project.completedAt != null,
                  icon: Icons.done_all,
                  color: Colors.green,
                  isLast: true,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        // Leader progress actions (leaders only, for in_progress / delayed)
        if (canUpdateStatus) ...[
          _LeaderActionsCard(project: project),
          const SizedBox(height: 12),
        ],
        // Description
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l10n.description, style: const TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Text(project.description),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        // Impact projection
        if (project.impactProjection != null) ...[
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(l10n.expectedImpact, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 12),
                  ...project.impactProjection!.entries.map((e) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      children: [
                        const Icon(Icons.trending_up, size: 18, color: Colors.green),
                        const SizedBox(width: 8),
                        Expanded(child: Text(_formatKey(e.key), style: const TextStyle(fontSize: 13))),
                        Text('${e.value}', style: const TextStyle(fontWeight: FontWeight.bold)),
                      ],
                    ),
                  )),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
        ],
        // Fund convergence
        if (project.fundPlans.isNotEmpty) ...[
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(l10n.fundPlan, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 4),
                  Text(
                    '${project.fundPlans.first.savingsPct.toStringAsFixed(0)}% ${l10n.subsidySavings}',
                    style: TextStyle(color: Colors.green.shade700, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  ...project.fundPlans.first.schemesUsed.map((s) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      children: [
                        Expanded(child: Text(s.schemeName, style: const TextStyle(fontSize: 13))),
                        Text(
                          '₹${_formatCost(s.amountInr)} (${s.pctCovered.toStringAsFixed(0)}%)',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                      ],
                    ),
                  )),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
        ],
        // Rating
        if (project.status == 'completed') ...[
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(l10n.citizenRating, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 8),
                  if (project.avgCitizenRating != null)
                    Row(
                      children: [
                        RatingBarIndicator(
                          rating: project.avgCitizenRating!,
                          itemBuilder: (_, __) => const Icon(Icons.star, color: Colors.amber),
                          itemCount: 5, itemSize: 24,
                        ),
                        const SizedBox(width: 8),
                        Text('${project.avgCitizenRating!.toStringAsFixed(1)}/5',
                            style: const TextStyle(fontWeight: FontWeight.bold)),
                      ],
                    ),
                  const SizedBox(height: 12),
                  Text(l10n.giveYourRating),
                  const SizedBox(height: 8),
                  _RatingSection(projectId: project.id),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _headerStat(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Colors.white60, fontSize: 11)),
        Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
      ],
    );
  }

  String _formatCost(int cost) {
    if (cost >= 100000) return '${(cost / 100000).toStringAsFixed(1)}L';
    if (cost >= 1000) return '${(cost / 1000).toStringAsFixed(0)}K';
    return '$cost';
  }

  String _formatKey(String key) {
    return key.replaceAll('_', ' ').split(' ').map((w) => w.isNotEmpty ? w[0].toUpperCase() + w.substring(1) : '').join(' ');
  }
}

class _TimelineItem extends StatelessWidget {
  final String label;
  final DateTime? date;
  final bool done;
  final IconData icon;
  final Color color;
  final bool isLast;

  const _TimelineItem({
    required this.label, this.date, required this.done,
    required this.icon, required this.color, this.isLast = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            Container(
              width: 32, height: 32,
              decoration: BoxDecoration(
                color: done ? color : Colors.grey.shade200,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 16, color: done ? Colors.white : Colors.grey),
            ),
            if (!isLast) Container(width: 2, height: 28, color: done ? color.withOpacity(0.4) : Colors.grey.shade200),
          ],
        ),
        const SizedBox(width: 12),
        Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: TextStyle(
                fontWeight: done ? FontWeight.bold : FontWeight.normal,
                color: done ? Colors.black : Colors.grey,
              )),
              if (date != null)
                Text('${date!.day}/${date!.month}/${date!.year}',
                    style: const TextStyle(fontSize: 11, color: Colors.grey)),
            ],
          ),
        ),
      ],
    );
  }
}

class _RatingSection extends StatefulWidget {
  final int projectId;
  const _RatingSection({required this.projectId});

  @override
  State<_RatingSection> createState() => _RatingSectionState();
}

class _RatingSectionState extends State<_RatingSection> {
  double _rating = 3;
  final _reviewController = TextEditingController();

  @override
  void dispose() {
    _reviewController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        RatingBar.builder(
          initialRating: _rating,
          minRating: 1,
          itemCount: 5,
          itemBuilder: (_, __) => const Icon(Icons.star, color: Colors.amber),
          onRatingUpdate: (r) => setState(() => _rating = r),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _reviewController,
          maxLines: 2,
          decoration: InputDecoration(
            hintText: AppLocalizations.of(context).writeReviewHint,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          ),
        ),
        const SizedBox(height: 8),
        ElevatedButton(
          onPressed: () {
            context.read<ProjectCubit>().rateProject(widget.projectId, _rating.toInt(), _reviewController.text);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(AppLocalizations.of(context).ratingSubmitted), backgroundColor: Colors.green),
            );
          },
          child: Text(AppLocalizations.of(context).submitRating),
        ),
      ],
    );
  }
}

// ── Leader progress actions ───────────────────────────────────────────────────

class _LeaderActionsCard extends StatelessWidget {
  final Project project;
  const _LeaderActionsCard({required this.project});

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<ProjectCubit>();
    final apiClient = context.read<ApiClient>();
    return Card(
      color: Colors.green.shade50,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.green.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.admin_panel_settings, color: Colors.green.shade700, size: 18),
                const SizedBox(width: 6),
                const Text('Leader Actions',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Current status: ${project.status.replaceAll('_', ' ').toUpperCase()}',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (project.status == 'delayed')
                  ElevatedButton.icon(
                    onPressed: () => _openDialog(context, cubit, apiClient, 'in_progress',
                        'Resume Project', 'Mark this project as back in progress?'),
                    icon: const Icon(Icons.play_arrow, size: 18),
                    label: const Text('Resume'),
                    style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue, foregroundColor: Colors.white),
                  ),
                if (project.status == 'in_progress')
                  OutlinedButton.icon(
                    onPressed: () => _openDialog(context, cubit, apiClient, 'delayed',
                        'Mark as Delayed', 'Flag this project as delayed due to obstacles?'),
                    icon: const Icon(Icons.warning_amber, size: 18, color: Colors.orange),
                    label: const Text('Mark Delayed',
                        style: TextStyle(color: Colors.orange)),
                    style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Colors.orange)),
                  ),
                ElevatedButton.icon(
                  onPressed: () => _openDialog(context, cubit, apiClient, 'completed',
                      'Mark as Completed',
                      'Mark this project as complete? Citizens will be able to rate it.'),
                  icon: const Icon(Icons.done_all, size: 18),
                  label: const Text('Mark Complete'),
                  style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green, foregroundColor: Colors.white),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _openDialog(BuildContext context, ProjectCubit cubit, ApiClient apiClient,
      String newStatus, String title, String message) {
    showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => _UpdateStatusDialog(
        projectId: project.id,
        newStatus: newStatus,
        title: title,
        message: message,
        apiClient: apiClient,
      ),
    ).then((updated) {
      if (updated == true && context.mounted) {
        cubit.loadProjectDetail(project.id);
      }
    });
  }
}

class _UpdateStatusDialog extends StatefulWidget {
  final int projectId;
  final String newStatus;
  final String title;
  final String message;
  final ApiClient apiClient;

  const _UpdateStatusDialog({
    required this.projectId,
    required this.newStatus,
    required this.title,
    required this.message,
    required this.apiClient,
  });

  @override
  State<_UpdateStatusDialog> createState() => _UpdateStatusDialogState();
}

class _UpdateStatusDialogState extends State<_UpdateStatusDialog> {
  bool _loading = false;
  String? _error;

  Future<void> _submit() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await widget.apiClient.patch(
        '/projects/${widget.projectId}/update_status/',
        data: {'status': widget.newStatus},
      );
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      setState(() {
        _loading = false;
        _error = 'Update failed. Please try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(widget.message),
          if (_error != null) ...[
            const SizedBox(height: 10),
            Text(_error!, style: const TextStyle(color: Colors.red, fontSize: 13)),
          ],
          if (_loading) ...[
            const SizedBox(height: 16),
            const Center(child: CircularProgressIndicator()),
          ],
        ],
      ),
      actions: _loading
          ? null
          : [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: _submit,
                child: const Text('Confirm'),
              ),
            ],
    );
  }
}
