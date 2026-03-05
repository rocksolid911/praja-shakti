import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../cubit/project_cubit.dart';
import '../cubit/project_state.dart';
import '../../../core/api/api_client.dart';
import '../../../core/models/project.dart';
import '../../../core/utils/responsive.dart';
import '../../../l10n/app_localizations.dart';

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

class _ProjectListView extends StatefulWidget {
  const _ProjectListView();

  @override
  State<_ProjectListView> createState() => _ProjectListViewState();
}

class _ProjectListViewState extends State<_ProjectListView> {
  Project? _selectedProject;
  final _scrollController = ScrollController();

  static const _statusKeys = [null, 'recommended', 'adopted', 'in_progress', 'completed'];

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(() {
      if (_scrollController.position.pixels >=
          _scrollController.position.maxScrollExtent - 200) {
        context.read<ProjectCubit>().loadMoreProjects();
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  String _statusFilterLabel(String? key, AppLocalizations l10n) {
    if (key == null) return l10n.filterAll;
    return switch (key) {
      'recommended' => l10n.aiRecommended,
      'adopted' => l10n.adopted,
      'in_progress' => l10n.inProgress,
      'completed' => l10n.completed,
      _ => key,
    };
  }

  static String _formatCostStatic(int cost) {
    if (cost >= 10000000) return '₹${(cost / 10000000).toStringAsFixed(1)}Cr';
    if (cost >= 100000) return '₹${(cost / 100000).toStringAsFixed(1)}L';
    if (cost >= 1000) return '₹${(cost / 1000).toStringAsFixed(0)}K';
    return '₹$cost';
  }

  void _showFundDetailsSheet(BuildContext context, List<Project> projects) {
    // Aggregate schemes across all projects
    final schemeMap = <String, int>{};
    int grandTotal = 0;
    for (final p in projects) {
      for (final fp in p.fundPlans) {
        grandTotal += fp.totalCostInr;
        for (final s in fp.schemesUsed) {
          schemeMap[s.schemeName] = (schemeMap[s.schemeName] ?? 0) + s.amountInr;
        }
      }
    }
    final sortedSchemes = schemeMap.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40, height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Text('Fund Overview', style: TextStyle(
                fontSize: 18, fontWeight: FontWeight.w700, color: Color(0xFF263238),
              )),
              const SizedBox(height: 4),
              Text('Across ${projects.length} projects',
                  style: TextStyle(fontSize: 13, color: Colors.grey.shade600)),
              const SizedBox(height: 16),
              // Grand total card
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF1A237E), Color(0xFF3F51B5)],
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.account_balance_wallet_rounded, color: Colors.white, size: 28),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Total Fund', style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.7), fontSize: 12,
                        )),
                        Text(_formatCostStatic(grandTotal), style: const TextStyle(
                          color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800,
                        )),
                      ],
                    ),
                  ],
                ),
              ),
              if (sortedSchemes.isNotEmpty) ...[
                const SizedBox(height: 16),
                Text('By Scheme', style: TextStyle(
                  fontSize: 14, fontWeight: FontWeight.w600, color: Colors.grey.shade700,
                )),
                const SizedBox(height: 8),
                ...sortedSchemes.map((e) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      Container(
                        width: 8, height: 8,
                        decoration: BoxDecoration(
                          color: const Color(0xFF3F51B5),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(e.key, style: const TextStyle(fontSize: 13)),
                      ),
                      Text(
                        _formatCostStatic(e.value),
                        style: const TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w700,
                          color: Color(0xFF1A237E),
                        ),
                      ),
                    ],
                  ),
                )),
              ],
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(kToolbarHeight),
        child: BlocBuilder<ProjectCubit, ProjectState>(
          builder: (context, state) {
            int totalFund = 0;
            List<Project> allProjects = [];
            if (state is ProjectsLoaded) {
              allProjects = state.projects;
              for (final p in state.projects) {
                for (final fp in p.fundPlans) {
                  totalFund += fp.totalCostInr;
                }
              }
            }
            return AppBar(
              title: Text(l10n.projects),
              backgroundColor: const Color(0xFF1A237E),
              foregroundColor: Colors.white,
              actions: [
                if (totalFund > 0)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ActionChip(
                      avatar: const Icon(Icons.account_balance_wallet_rounded,
                          size: 16, color: Colors.white),
                      label: Text(
                        _formatCostStatic(totalFund),
                        style: const TextStyle(
                          color: Colors.white, fontWeight: FontWeight.w700, fontSize: 12,
                        ),
                      ),
                      backgroundColor: Colors.white.withValues(alpha: 0.2),
                      side: BorderSide.none,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      onPressed: () => _showFundDetailsSheet(context, allProjects),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
      body: Column(
        children: [
          // Status filter chips
          Container(
            height: 48,
            color: Colors.white,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              itemCount: _statusKeys.length,
              itemBuilder: (context, i) {
                final key = _statusKeys[i];
                final label = _statusFilterLabel(key, l10n);
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
            child: BlocConsumer<ProjectCubit, ProjectState>(
              listener: (context, state) {
                // Clear selection when data reloads
                if (state is ProjectLoading && _selectedProject != null) {
                  setState(() => _selectedProject = null);
                }
              },
              builder: (context, state) {
                if (state is ProjectLoading) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (state is ProjectError) {
                  return Center(child: Text(state.message));
                }
                if (state is ProjectsLoaded) {
                  if (state.projects.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.construction, size: 64, color: Colors.grey),
                          const SizedBox(height: 12),
                          Text(l10n.noProjectsFound, style: const TextStyle(color: Colors.grey)),
                        ],
                      ),
                    );
                  }
                  return _buildContent(context, state);
                }
                return const SizedBox.shrink();
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent(BuildContext context, ProjectsLoaded state) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isDesktop = constraints.maxWidth >= kTabletBreakpoint;
        final isTablet = constraints.maxWidth >= kMobileBreakpoint;

        if (isDesktop) {
          // Desktop: 2-column grid on the left + detail panel on the right
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 3,
                child: Scrollbar(
                  thumbVisibility: true,
                  child: _buildGrid(context, state, columns: 2, onTap: (p) {
                    setState(() => _selectedProject = p);
                  }),
                ),
              ),
              if (_selectedProject != null) ...[
                const VerticalDivider(thickness: 1, width: 1),
                Expanded(
                  flex: 2,
                  child: _ProjectPanel(
                    key: ValueKey(_selectedProject!.id),
                    project: _selectedProject!,
                    onClose: () => setState(() => _selectedProject = null),
                    onViewFull: () => context.push('/project/${_selectedProject!.id}'),
                  ),
                ),
              ],
            ],
          );
        }

        if (isTablet) {
          // Tablet: 2-column grid, tap navigates to detail screen
          return Scrollbar(
            thumbVisibility: true,
            child: _buildGrid(context, state, columns: 2, onTap: (p) {
              context.push('/project/${p.id}');
            }),
          );
        }

        // Mobile: single-column list
        return ListView.builder(
          controller: _scrollController,
          padding: const EdgeInsets.all(12),
          itemCount: state.projects.length + (state.isLoadingMore ? 1 : 0),
          itemBuilder: (context, i) {
            if (i == state.projects.length) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Center(child: CircularProgressIndicator()),
              );
            }
            return ProjectCard(
              project: state.projects[i],
              onTap: () => context.push('/project/${state.projects[i].id}'),
            );
          },
        );
      },
    );
  }

  Widget _buildGrid(
    BuildContext context,
    ProjectsLoaded state, {
    required int columns,
    required void Function(Project) onTap,
  }) {
    final projects = state.projects;
    final rowCount = (projects.length / columns).ceil();
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.all(12),
      itemCount: rowCount + (state.isLoadingMore ? 1 : 0),
      itemBuilder: (context, rowIdx) {
        if (rowIdx == rowCount) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        final start = rowIdx * columns;
        final end = (start + columns).clamp(0, projects.length);
        final rowProjects = projects.sublist(start, end);
        return IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ...rowProjects.map((p) => Expanded(
                child: ProjectCard(
                  project: p,
                  onTap: () => onTap(p),
                  isSelected: _selectedProject?.id == p.id,
                ),
              )),
              for (int i = rowProjects.length; i < columns; i++)
                const Expanded(child: SizedBox()),
            ],
          ),
        );
      },
    );
  }
}

class ProjectCard extends StatelessWidget {
  final Project project;
  final VoidCallback onTap;
  final bool isSelected;

  const ProjectCard({
    super.key,
    required this.project,
    required this.onTap,
    this.isSelected = false,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape: isSelected
          ? RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: Colors.blue.shade700, width: 2),
            )
          : null,
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
                  _statusBadge(project.status, l10n),
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
                    Text('${project.beneficiaryCount} ${l10n.beneficiaries}',
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
                        '${l10n.priority}: ${project.priorityScore!.toStringAsFixed(0)}',
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

  Widget _statusBadge(String status, AppLocalizations l10n) {
    final (color, label) = switch (status) {
      'recommended' => (Colors.purple, 'AI'),
      'adopted' => (Colors.amber.shade700, l10n.adopted),
      'in_progress' => (Colors.blue, l10n.active),
      'completed' => (Colors.green, l10n.done),
      'delayed' => (Colors.red, l10n.delayed),
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

/// Side panel shown on desktop when a project card is selected.
class _ProjectPanel extends StatelessWidget {
  final Project project;
  final VoidCallback onClose;
  final VoidCallback onViewFull;

  const _ProjectPanel({
    super.key,
    required this.project,
    required this.onClose,
    required this.onViewFull,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Column(
      children: [
        // Panel header
        Container(
          color: Colors.blue.shade700,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  project.title,
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close, color: Colors.white70),
                onPressed: onClose,
                tooltip: l10n.close,
              ),
            ],
          ),
        ),
        // Panel content
        Expanded(
          child: Scrollbar(
            thumbVisibility: true,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Key stats row
                  Row(
                    children: [
                      _Stat(
                        label: l10n.costLabel,
                        value: _formatCost(project.estimatedCostInr),
                        color: Colors.green.shade700,
                      ),
                      if (project.beneficiaryCount != null) ...[
                        const SizedBox(width: 16),
                        _Stat(
                          label: l10n.beneficiaries,
                          value: '${project.beneficiaryCount}',
                          color: Colors.blue.shade700,
                        ),
                      ],
                      if (project.priorityScore != null) ...[
                        const SizedBox(width: 16),
                        _Stat(
                          label: l10n.priority,
                          value: '${project.priorityScore!.toStringAsFixed(0)}/100',
                          color: Colors.orange.shade700,
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 14),
                  // Description
                  if (project.description.isNotEmpty) ...[
                    Text(l10n.description, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    const SizedBox(height: 6),
                    Text(project.description, style: TextStyle(color: Colors.grey.shade700, fontSize: 13)),
                    const SizedBox(height: 14),
                  ],
                  // Status timeline
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(l10n.timeline, style: const TextStyle(fontWeight: FontWeight.bold)),
                          const SizedBox(height: 8),
                          _TimelineRow(Icons.auto_awesome, l10n.aiRecommended, project.createdAt, Colors.purple, done: true),
                          _TimelineRow(Icons.check_circle, l10n.adopted, project.adoptedAt, Colors.amber.shade700),
                          _TimelineRow(Icons.construction, l10n.inProgress, project.startedAt, Colors.blue),
                          _TimelineRow(Icons.done_all, l10n.completed, project.completedAt, Colors.green),
                        ],
                      ),
                    ),
                  ),
                  // Fund plan
                  if (project.fundPlans.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${l10n.fundPlan} — ${project.fundPlans.first.savingsPct.toStringAsFixed(0)}% ${l10n.subsidySavings}',
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 8),
                            ...project.fundPlans.first.schemesUsed.map((s) => Padding(
                              padding: const EdgeInsets.only(bottom: 4),
                              child: Row(
                                children: [
                                  Expanded(child: Text(s.schemeName, style: const TextStyle(fontSize: 13))),
                                  Text(
                                    '${_formatCost(s.amountInr)} (${s.pctCovered.toStringAsFixed(0)}%)',
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                  ),
                                ],
                              ),
                            )),
                          ],
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  // Open full detail
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: onViewFull,
                      icon: const Icon(Icons.open_in_new, size: 16),
                      label: Text(l10n.viewFullDetails),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue.shade700,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _TimelineRow(IconData icon, String label, DateTime? date, Color color, {bool done = false}) {
    final isDone = done || date != null;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Icon(icon, size: 16, color: isDone ? color : Colors.grey.shade400),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                color: isDone ? Colors.black87 : Colors.grey,
                fontWeight: isDone ? FontWeight.w500 : FontWeight.normal,
              ),
            ),
          ),
          if (date != null)
            Text(
              '${date.day}/${date.month}/${date.year}',
              style: const TextStyle(fontSize: 11, color: Colors.grey),
            ),
        ],
      ),
    );
  }

  String _formatCost(int cost) {
    if (cost >= 100000) return '₹${(cost / 100000).toStringAsFixed(1)}L';
    if (cost >= 1000) return '₹${(cost / 1000).toStringAsFixed(0)}K';
    return '₹$cost';
  }
}

class _Stat extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _Stat({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
        Text(value, style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: color)),
      ],
    );
  }
}
