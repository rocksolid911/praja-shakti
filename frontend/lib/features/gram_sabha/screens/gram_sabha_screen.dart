import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../cubit/gram_sabha_cubit.dart';
import '../cubit/gram_sabha_state.dart';
import '../../../core/api/api_client.dart';

class GramSabhaScreen extends StatelessWidget {
  const GramSabhaScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => GramSabhaCubit(context.read<ApiClient>())..loadSessions(),
      child: const _GramSabhaView(),
    );
  }
}

class _GramSabhaView extends StatelessWidget {
  const _GramSabhaView();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('ग्राम सभा', style: TextStyle(fontSize: 16)),
            Text('Digital Village Assembly', style: TextStyle(fontSize: 11, color: Colors.white70)),
          ],
        ),
        backgroundColor: Colors.purple.shade700,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => context.read<GramSabhaCubit>().loadSessions(),
          ),
        ],
      ),
      body: BlocBuilder<GramSabhaCubit, GramSabhaState>(
        builder: (context, state) {
          if (state is GramSabhaLoading) return const Center(child: CircularProgressIndicator());
          if (state is GramSabhaError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 48, color: Colors.red),
                  Text(state.message),
                  TextButton(
                    onPressed: () => context.read<GramSabhaCubit>().loadSessions(),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            );
          }
          if (state is GramSabhaLoaded) return _buildSessions(context, state);
          return _buildEmpty(context);
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showCreateDialog(context),
        icon: const Icon(Icons.add),
        label: const Text('नई बैठक'),
        backgroundColor: Colors.purple.shade700,
        foregroundColor: Colors.white,
      ),
    );
  }

  Widget _buildEmpty(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.groups, size: 80, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          const Text('कोई ग्राम सभा नहीं', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          const Text('नई बैठक बनाएं', style: TextStyle(color: Colors.grey)),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: () => _showCreateDialog(context),
            icon: const Icon(Icons.add),
            label: const Text('बैठक बनाएं'),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.purple.shade700, foregroundColor: Colors.white),
          ),
        ],
      ),
    );
  }

  Widget _buildSessions(BuildContext context, GramSabhaLoaded state) {
    if (state.sessions.isEmpty) return _buildEmpty(context);
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: state.sessions.length,
      itemBuilder: (context, i) => _SessionCard(
        session: state.sessions[i],
        onRaiseIssue: (title) => context.read<GramSabhaCubit>().raiseIssue(state.sessions[i].id, title),
        onVote: (issueId) => context.read<GramSabhaCubit>().voteIssue(state.sessions[i].id, issueId),
      ),
    );
  }

  void _showCreateDialog(BuildContext context) {
    final titleController = TextEditingController();
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('नई ग्राम सभा'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: titleController,
              decoration: const InputDecoration(
                hintText: 'बैठक का शीर्षक',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              if (titleController.text.isNotEmpty) {
                Navigator.pop(dialogContext);
                context.read<GramSabhaCubit>().createSession(
                  titleController.text,
                  DateTime.now().add(const Duration(days: 7)),
                  1,
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.purple.shade700),
            child: const Text('बनाएं', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}

class _SessionCard extends StatelessWidget {
  final GramSabhaSession session;
  final void Function(String) onRaiseIssue;
  final void Function(int) onVote;

  const _SessionCard({required this.session, required this.onRaiseIssue, required this.onVote});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: session.isActive ? Colors.purple.shade700 : Colors.grey.shade700,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(session.title,
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                      const SizedBox(height: 2),
                      Text(
                        '${session.scheduledAt.day}/${session.scheduledAt.month}/${session.scheduledAt.year}',
                        style: const TextStyle(color: Colors.white70, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: session.isActive ? Colors.green : Colors.grey.shade500,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    session.isActive ? '● LIVE' : 'Scheduled',
                    style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),
          // Issues
          if (session.issues.isNotEmpty) ...[
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: Text('मुद्दे:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            ),
            ...session.issues.map((issue) => ListTile(
              leading: Container(
                width: 36, height: 36,
                decoration: BoxDecoration(
                  color: Colors.purple.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('${issue.voteCount}', style: TextStyle(
                      color: Colors.purple.shade800, fontWeight: FontWeight.bold, fontSize: 14,
                    )),
                  ],
                ),
              ),
              title: Text(issue.title, style: const TextStyle(fontSize: 14)),
              trailing: IconButton(
                icon: Icon(Icons.thumb_up_outlined, color: Colors.purple.shade700),
                onPressed: () => onVote(issue.id),
                visualDensity: VisualDensity.compact,
              ),
            )),
          ] else
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text('अभी कोई मुद्दा नहीं — पहला मुद्दा उठाएं!',
                  style: TextStyle(color: Colors.grey)),
            ),
          // Raise issue button
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: OutlinedButton.icon(
              onPressed: () => _showIssueDialog(context),
              icon: const Icon(Icons.add, size: 16),
              label: const Text('मुद्दा उठाएं', style: TextStyle(fontSize: 13)),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.purple.shade700,
                side: BorderSide(color: Colors.purple.shade700),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showIssueDialog(BuildContext context) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('मुद्दा उठाएं'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            hintText: 'मुद्दे का विवरण...',
            border: OutlineInputBorder(),
          ),
          maxLines: 3,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              if (controller.text.isNotEmpty) {
                Navigator.pop(dialogContext);
                onRaiseIssue(controller.text);
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.purple.shade700),
            child: const Text('जमा करें', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}
