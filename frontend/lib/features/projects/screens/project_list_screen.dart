import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../cubit/project_cubit.dart';
import '../cubit/project_state.dart';
import '../../../core/api/api_client.dart';
import '../../../core/models/project.dart';

class ProjectListScreen extends StatelessWidget {
  const ProjectListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => ProjectCubit(context.read<ApiClient>())..loadProjects(),
      child: const _ProjectListView(),
    );
  }
}

class _ProjectListView extends StatelessWidget {
  const _ProjectListView();

  static const _statuses = [
    (null, 'सभी'),
    ('recommended', 'AI सुझाव'),
    ('adopted', 'स्वीकृत'),
    ('in_progress', 'जारी'),
    ('completed', 'पूर्ण'),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('परियोजनाएं'),
        backgroundColor: Colors.blue.shade700,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          // Status filters
          Container(
            height: 48,
            color: Colors.white,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              itemCount: _statuses.length,
              itemBuilder: (context, i) {
                final (key, label) = _statuses[i];
                return BlocBuilder<ProjectCubit, ProjectState>(
                  builder: (context, state) {
                    final active = state is ProjectsLoaded && state.activeFilter == key;
                    return Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: FilterChip(
                        label: Text(label, style: const TextStyle(fontSize: 12)),
                        selected: active,
                        onSelected: (_) => context.read<ProjectCubit>().loadProjects(status: key),
                        selectedColor: Colors.blue.shade100,
                      ),
                    );
                  },
                );
              },
            ),
          ),
          Expanded(
            child: BlocBuilder<ProjectCubit, ProjectState>(
              builder: (context, state) {
                if (state is ProjectLoading) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (state is ProjectError) {
                  return Center(child: Text(state.message));
                }
                if (state is ProjectsLoaded) {
                  if (state.projects.isEmpty) {
                    return const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.construction, size: 64, color: Colors.grey),
                          SizedBox(height: 12),
                          Text('कोई परियोजना नहीं मिली', style: TextStyle(color: Colors.grey)),
                        ],
                      ),
                    );
                  }
                  return ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: state.projects.length,
                    itemBuilder: (context, i) => ProjectCard(
                      project: state.projects[i],
                      onTap: () => context.push('/project/${state.projects[i].id}'),
                    ),
                  );
                }
                return const SizedBox.shrink();
              },
            ),
          ),
        ],
      ),
    );
  }
}

class ProjectCard extends StatelessWidget {
  final Project project;
  final VoidCallback onTap;

  const ProjectCard({super.key, required this.project, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      project.title,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                  ),
                  _statusBadge(project.status),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                project.description,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(Icons.currency_rupee, size: 14, color: Colors.green.shade700),
                  Text(
                    _formatCost(project.estimatedCostInr),
                    style: TextStyle(color: Colors.green.shade700, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(width: 12),
                  if (project.beneficiaryCount != null) ...[
                    const Icon(Icons.people, size: 14, color: Colors.grey),
                    const SizedBox(width: 2),
                    Text('${project.beneficiaryCount} beneficiaries',
                        style: const TextStyle(color: Colors.grey, fontSize: 12)),
                  ],
                  const Spacer(),
                  if (project.priorityScore != null)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.orange.shade100,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'Priority: ${project.priorityScore!.toStringAsFixed(0)}',
                        style: TextStyle(color: Colors.orange.shade800, fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                    ),
                ],
              ),
              if (project.fundPlans.isNotEmpty) ...[
                const SizedBox(height: 8),
                const Divider(),
                Row(
                  children: project.fundPlans.first.schemesUsed.take(3).map((s) =>
                    Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: Chip(
                        label: Text(s.schemeName, style: const TextStyle(fontSize: 10)),
                        padding: EdgeInsets.zero,
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    )
                  ).toList(),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _statusBadge(String status) {
    final (color, label) = switch (status) {
      'recommended' => (Colors.purple, 'AI'),
      'adopted' => (Colors.amber.shade700, 'Adopted'),
      'in_progress' => (Colors.blue, 'Active'),
      'completed' => (Colors.green, 'Done'),
      'delayed' => (Colors.red, 'Delayed'),
      _ => (Colors.grey, status),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: color.withOpacity(0.15), borderRadius: BorderRadius.circular(6)),
      child: Text(label, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold)),
    );
  }

  String _formatCost(int cost) {
    if (cost >= 100000) return '₹${(cost / 100000).toStringAsFixed(1)}L';
    if (cost >= 1000) return '₹${(cost / 1000).toStringAsFixed(0)}K';
    return '₹$cost';
  }
}
