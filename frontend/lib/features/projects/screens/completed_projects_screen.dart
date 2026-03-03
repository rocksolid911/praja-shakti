import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import 'package:go_router/go_router.dart';
import '../cubit/project_cubit.dart';
import '../cubit/project_state.dart';
import '../../../core/api/api_client.dart';
import '../../../core/models/project.dart';
import '../../../l10n/app_localizations.dart';

class CompletedProjectsScreen extends StatelessWidget {
  const CompletedProjectsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => ProjectCubit(context.read<ApiClient>())
        ..loadProjects(status: 'completed'),
      child: const _CompletedView(),
    );
  }
}

class _CompletedView extends StatelessWidget {
  const _CompletedView();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.completed),
        backgroundColor: Colors.green.shade700,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () =>
                context.read<ProjectCubit>().loadProjects(status: 'completed'),
          ),
        ],
      ),
      body: BlocBuilder<ProjectCubit, ProjectState>(
        builder: (context, state) {
          if (state is ProjectLoading) {
            return const Center(child: CircularProgressIndicator());
          }
          if (state is ProjectError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 48, color: Colors.red),
                  const SizedBox(height: 8),
                  Text(state.message),
                  TextButton(
                    onPressed: () => context
                        .read<ProjectCubit>()
                        .loadProjects(status: 'completed'),
                    child: Text(l10n.retry),
                  ),
                ],
              ),
            );
          }
          if (state is ProjectsLoaded) {
            if (state.projects.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.done_all, size: 72, color: Colors.grey.shade300),
                    const SizedBox(height: 16),
                    Text(
                      'No completed projects yet',
                      style: TextStyle(color: Colors.grey.shade500, fontSize: 16),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Projects will appear here once marked complete.',
                      style: TextStyle(color: Colors.grey.shade400, fontSize: 13),
                    ),
                  ],
                ),
              );
            }
            return RefreshIndicator(
              onRefresh: () => context
                  .read<ProjectCubit>()
                  .loadProjects(status: 'completed'),
              child: ListView.builder(
                padding: const EdgeInsets.all(12),
                itemCount: state.projects.length,
                itemBuilder: (context, i) =>
                    _CompletedProjectCard(project: state.projects[i]),
              ),
            );
          }
          return const SizedBox.shrink();
        },
      ),
    );
  }
}

class _CompletedProjectCard extends StatefulWidget {
  final Project project;
  const _CompletedProjectCard({required this.project});

  @override
  State<_CompletedProjectCard> createState() => _CompletedProjectCardState();
}

class _CompletedProjectCardState extends State<_CompletedProjectCard> {
  double _stars = 4;
  final _reviewController = TextEditingController();
  bool _submitted = false;
  bool _submitting = false;
  double? _updatedAvgRating;
  String? _error;

  @override
  void dispose() {
    _reviewController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      final api = context.read<ApiClient>();
      await api.post(
        '/projects/${widget.project.id}/rating/',
        data: {
          'rating': _stars.toInt(),
          'review': _reviewController.text.trim(),
        },
      );
      // Re-fetch project to get updated avg rating
      final resp = await api.get('/projects/${widget.project.id}/');
      final updated = Project.fromJson(resp.data);
      if (mounted) {
        setState(() {
          _submitted = true;
          _submitting = false;
          _updatedAvgRating = updated.avgCitizenRating;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _submitting = false;
          _error = 'Could not submit rating. Please try again.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final project = widget.project;
    final avgRating = _updatedAvgRating ?? project.avgCitizenRating;

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Project header ───────────────────────────────────────────────
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.green.shade700, Colors.green.shade500],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.done_all, color: Colors.white, size: 18),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.white24,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text(
                        'COMPLETED',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  project.title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 17,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  project.villageName,
                  style: const TextStyle(color: Colors.white70, fontSize: 13),
                ),
                if (project.completedAt != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    'Completed on ${_fmt(project.completedAt!)}',
                    style: const TextStyle(color: Colors.white60, fontSize: 12),
                  ),
                ],
              ],
            ),
          ),

          // ── Community rating summary ─────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Community Rating',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                ),
                const SizedBox(height: 8),
                if (avgRating != null)
                  Row(
                    children: [
                      RatingBarIndicator(
                        rating: avgRating,
                        itemBuilder: (_, __) =>
                            const Icon(Icons.star, color: Colors.amber),
                        itemCount: 5,
                        itemSize: 28,
                      ),
                      const SizedBox(width: 10),
                      Text(
                        avgRating.toStringAsFixed(1),
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Text(
                        ' / 5',
                        style: TextStyle(fontSize: 16, color: Colors.grey),
                      ),
                    ],
                  )
                else
                  Row(
                    children: [
                      ...List.generate(
                        5,
                        (_) => const Icon(Icons.star_border,
                            color: Colors.grey, size: 28),
                      ),
                      const SizedBox(width: 10),
                      const Text(
                        'No ratings yet — be the first!',
                        style: TextStyle(color: Colors.grey, fontSize: 13),
                      ),
                    ],
                  ),
              ],
            ),
          ),

          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Divider(),
          ),

          // ── View details button ───────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
            child: OutlinedButton.icon(
              onPressed: () => context.push('/project/${widget.project.id}'),
              icon: const Icon(Icons.open_in_new, size: 16),
              label: const Text('View Full Details & Photos'),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(double.infinity, 40),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ),
          const SizedBox(height: 8),
          // ── Rating form ──────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: _submitted ? _SuccessBanner() : _ratingForm(context),
          ),
        ],
      ),
    );
  }

  Widget _SuccessBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.green.shade50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.green.shade200),
      ),
      child: Row(
        children: [
          Icon(Icons.check_circle, color: Colors.green.shade700, size: 22),
          const SizedBox(width: 10),
          const Text(
            'Thank you for your feedback!',
            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _ratingForm(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Rate this project',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
        ),
        const SizedBox(height: 10),
        RatingBar.builder(
          initialRating: _stars,
          minRating: 1,
          itemCount: 5,
          itemSize: 36,
          itemBuilder: (_, __) => const Icon(Icons.star, color: Colors.amber),
          onRatingUpdate: (r) => setState(() => _stars = r),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _reviewController,
          maxLines: 3,
          decoration: InputDecoration(
            hintText: 'Share your feedback about this project...',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          ),
        ),
        if (_error != null) ...[
          const SizedBox(height: 8),
          Text(_error!, style: const TextStyle(color: Colors.red, fontSize: 13)),
        ],
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _submitting ? null : _submit,
            icon: _submitting
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.send, size: 18),
            label: Text(_submitting ? 'Submitting...' : 'Submit Rating'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green.shade700,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
          ),
        ),
      ],
    );
  }

  String _fmt(DateTime dt) => '${dt.day}/${dt.month}/${dt.year}';
}
