import 'dart:typed_data';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
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
        // Progress photo gallery
        _PhotoGallerySection(project: project),
        const SizedBox(height: 12),
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
                    child: GestureDetector(
                      onTap: () => context.go(
                          '/schemes?query=${Uri.encodeComponent(s.schemeName)}'),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              s.schemeName,
                              style: const TextStyle(
                                fontSize: 13,
                                color: Colors.blue,
                                decoration: TextDecoration.underline,
                              ),
                            ),
                          ),
                          Text(
                            '₹${_formatCost(s.amountInr)} (${s.pctCovered.toStringAsFixed(0)}%)',
                            style: const TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 13),
                          ),
                          const SizedBox(width: 4),
                          Icon(Icons.open_in_new,
                              size: 12, color: Colors.blue.shade300),
                        ],
                      ),
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

// ── Progress photo gallery ────────────────────────────────────────────────────

void _showFullScreenPhoto(BuildContext context, String url) {
  showDialog(
    context: context,
    builder: (_) => Dialog(
      backgroundColor: Colors.black,
      insetPadding: EdgeInsets.zero,
      child: Stack(
        children: [
          InteractiveViewer(
            child: CachedNetworkImage(
              imageUrl: url,
              fit: BoxFit.contain,
              placeholder: (_, __) =>
                  const Center(child: CircularProgressIndicator()),
              errorWidget: (_, __, ___) =>
                  const Icon(Icons.broken_image, color: Colors.white, size: 48),
            ),
          ),
          Positioned(
            top: 8,
            right: 8,
            child: IconButton(
              icon: const Icon(Icons.close, color: Colors.white),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ),
        ],
      ),
    ),
  );
}

class _PhotoGallerySection extends StatelessWidget {
  final Project project;
  const _PhotoGallerySection({required this.project});

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<ProjectCubit>();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text('Progress Photos',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(width: 8),
                if (project.photos.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade100,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '${project.photos.length}',
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue.shade800),
                    ),
                  ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.add_a_photo_outlined),
                  tooltip: 'Add photo',
                  onPressed: () =>
                      _showPhotoUploadDialog(context, project.id, cubit),
                ),
              ],
            ),
            if (project.photos.isEmpty) ...[
              const SizedBox(height: 12),
              Center(
                child: Text(
                  'No photos yet. Be the first to document progress!',
                  style: TextStyle(color: Colors.grey.shade500, fontSize: 13),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 4),
            ] else ...[
              const SizedBox(height: 12),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  childAspectRatio: 1.2,
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                ),
                itemCount: project.photos.length,
                itemBuilder: (context, i) {
                  final photo = project.photos[i];
                  final url = photo.photoUrl ?? '';
                  return GestureDetector(
                    onTap: url.isNotEmpty
                        ? () => _showFullScreenPhoto(context, url)
                        : null,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          url.isNotEmpty
                              ? CachedNetworkImage(
                                  imageUrl: url,
                                  fit: BoxFit.cover,
                                  placeholder: (_, __) => Container(
                                    color: Colors.grey.shade200,
                                    child: const Center(
                                        child: CircularProgressIndicator()),
                                  ),
                                  errorWidget: (_, __, ___) => Container(
                                    color: Colors.grey.shade200,
                                    child: const Icon(Icons.broken_image,
                                        color: Colors.grey),
                                  ),
                                )
                              : Container(
                                  color: Colors.grey.shade200,
                                  child: const Icon(Icons.broken_image,
                                      color: Colors.grey),
                                ),
                          // Delay badge overlay
                          if (photo.isDelayReport)
                            Positioned(
                              top: 6,
                              left: 6,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.orange.shade700,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.warning_amber,
                                        size: 10, color: Colors.white),
                                    SizedBox(width: 2),
                                    Text('DELAY',
                                        style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 9,
                                            fontWeight: FontWeight.bold)),
                                  ],
                                ),
                              ),
                            ),
                          // Caption at bottom
                          if (photo.caption.isNotEmpty)
                            Positioned(
                              bottom: 0,
                              left: 0,
                              right: 0,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 4),
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.bottomCenter,
                                    end: Alignment.topCenter,
                                    colors: [
                                      Colors.black.withOpacity(0.6),
                                      Colors.transparent,
                                    ],
                                  ),
                                ),
                                child: Text(
                                  photo.caption,
                                  style: const TextStyle(
                                      color: Colors.white, fontSize: 10),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _showPhotoUploadDialog(
      BuildContext context, int projectId, ProjectCubit cubit) {
    showDialog(
      context: context,
      builder: (dialogCtx) => _PhotoUploadDialog(
        projectId: projectId,
        cubit: cubit,
      ),
    );
  }
}

class _PhotoUploadDialog extends StatefulWidget {
  final int projectId;
  final ProjectCubit cubit;
  const _PhotoUploadDialog({required this.projectId, required this.cubit});

  @override
  State<_PhotoUploadDialog> createState() => _PhotoUploadDialogState();
}

class _PhotoUploadDialogState extends State<_PhotoUploadDialog> {
  Uint8List? _imageBytes;
  String _filename = '';
  final _captionController = TextEditingController();
  bool _isDelayReport = false;
  bool _uploading = false;

  @override
  void dispose() {
    _captionController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery);
    if (picked == null) return;
    final bytes = await picked.readAsBytes();
    setState(() {
      _imageBytes = bytes;
      _filename = picked.name;
    });
  }

  Future<void> _upload() async {
    if (_imageBytes == null) return;
    setState(() => _uploading = true);
    await widget.cubit.uploadPhoto(
      widget.projectId,
      bytes: _imageBytes!,
      filename: _filename,
      caption: _captionController.text.trim(),
      isDelayReport: _isDelayReport,
    );
    if (mounted) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Photo uploaded successfully'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add Progress Photo'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_imageBytes != null) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.memory(_imageBytes!,
                    height: 160, fit: BoxFit.cover),
              ),
              const SizedBox(height: 12),
            ] else ...[
              OutlinedButton.icon(
                onPressed: _pickImage,
                icon: const Icon(Icons.photo_library),
                label: const Text('Choose from Gallery'),
              ),
              const SizedBox(height: 12),
            ],
            if (_imageBytes != null)
              TextButton.icon(
                onPressed: _pickImage,
                icon: const Icon(Icons.swap_horiz, size: 16),
                label: const Text('Change photo'),
              ),
            TextField(
              controller: _captionController,
              maxLines: 2,
              decoration: InputDecoration(
                labelText: 'Caption (optional)',
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
            const SizedBox(height: 8),
            CheckboxListTile(
              value: _isDelayReport,
              onChanged: (v) => setState(() => _isDelayReport = v ?? false),
              title: const Text('Flag as delay report',
                  style: TextStyle(fontSize: 14)),
              subtitle: const Text('Marks this as documenting a project delay',
                  style: TextStyle(fontSize: 11)),
              controlAffinity: ListTileControlAffinity.leading,
              contentPadding: EdgeInsets.zero,
            ),
            if (_uploading) ...[
              const SizedBox(height: 12),
              const Center(child: CircularProgressIndicator()),
            ],
          ],
        ),
      ),
      actions: _uploading
          ? null
          : [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: _imageBytes != null ? _upload : null,
                child: const Text('Upload'),
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
