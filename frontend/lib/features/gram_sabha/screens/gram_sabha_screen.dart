import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../cubit/gram_sabha_cubit.dart';
import '../cubit/gram_sabha_state.dart';
import '../../../core/api/api_client.dart';
import '../../../l10n/app_localizations.dart';
import '../../auth/cubit/auth_cubit.dart';

class GramSabhaScreen extends StatelessWidget {
  const GramSabhaScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final villageId = context.read<AuthCubit>().currentVillageId;
    return BlocProvider(
      create: (_) => GramSabhaCubit(context.read<ApiClient>())..loadSessions(villageId: villageId),
      child: _GramSabhaView(villageId: villageId),
    );
  }
}

class _GramSabhaView extends StatelessWidget {
  final int villageId;
  const _GramSabhaView({required this.villageId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(AppLocalizations.of(context).gramSabha, style: const TextStyle(fontSize: 16)),
            const Text('Digital Village Assembly', style: TextStyle(fontSize: 11, color: Colors.white70)),
          ],
        ),
        backgroundColor: Colors.purple.shade700,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => context.read<GramSabhaCubit>().loadSessions(villageId: villageId),
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
                    onPressed: () => context.read<GramSabhaCubit>().loadSessions(villageId: villageId),
                    child: Text(AppLocalizations.of(context).retry),
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
        label: Text(AppLocalizations.of(context).newMeeting),
        backgroundColor: Colors.purple.shade700,
        foregroundColor: Colors.white,
      ),
    );
  }

  Widget _buildEmpty(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.groups, size: 80, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          Text(l10n.noGramSabhaYet, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text(l10n.createNewMeeting, style: const TextStyle(color: Colors.grey)),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: () => _showCreateDialog(context),
            icon: const Icon(Icons.add),
            label: Text(l10n.createMeeting),
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
        onEndSession: state.sessions[i].isActive
            ? () => context.read<GramSabhaCubit>().endSession(state.sessions[i].id, villageId)
            : null,
      ),
    );
  }

  void _showCreateDialog(BuildContext context) {
    final titleController = TextEditingController();
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(AppLocalizations.of(context).newGramSabha),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: titleController,
              decoration: InputDecoration(
                hintText: AppLocalizations.of(context).meetingTitleHint,
                border: const OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(AppLocalizations.of(context).cancel),
          ),
          ElevatedButton(
            onPressed: () {
              if (titleController.text.isNotEmpty) {
                Navigator.pop(dialogContext);
                context.read<GramSabhaCubit>().createSession(
                  titleController.text,
                  DateTime.now().add(const Duration(days: 7)),
                  villageId,
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.purple.shade700),
            child: Text(AppLocalizations.of(context).create, style: const TextStyle(color: Colors.white)),
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
  final VoidCallback? onEndSession;

  const _SessionCard({required this.session, required this.onRaiseIssue, required this.onVote,
      this.onEndSession});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
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
                    session.isActive ? '● ${l10n.live}' : l10n.scheduled,
                    style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                ),
                if (session.isActive && onEndSession != null) ...[
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: onEndSession,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.red.shade700,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Text(
                        'End Session',
                        style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          // Issues
          if (session.issues.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: Text(l10n.issuesLabel, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
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
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(l10n.noIssuesYet, style: const TextStyle(color: Colors.grey)),
            ),
          // AI Summary transcript (shown when session is ended and summary is ready)
          if (session.transcript.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.auto_awesome, size: 14, color: Colors.purple.shade700),
                        const SizedBox(width: 4),
                        Text(l10n.aiSummary, style: TextStyle(
                          fontSize: 12, fontWeight: FontWeight.bold, color: Colors.purple.shade700,
                        )),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(session.transcript, style: const TextStyle(
                      fontSize: 13, color: Colors.black54, fontStyle: FontStyle.italic,
                    )),
                  ],
                ),
              ),
            ),
          // Raise issue button
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: OutlinedButton.icon(
              onPressed: () => _showIssueDialog(context),
              icon: const Icon(Icons.add, size: 16),
              label: Text(l10n.raiseIssue, style: const TextStyle(fontSize: 13)),
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
    final l10n = AppLocalizations.of(context);
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.raiseIssue),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(
            hintText: l10n.issueDescriptionHint,
            border: const OutlineInputBorder(),
          ),
          maxLines: 3,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: Text(l10n.cancel)),
          ElevatedButton(
            onPressed: () {
              if (controller.text.isNotEmpty) {
                Navigator.pop(dialogContext);
                onRaiseIssue(controller.text);
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.purple.shade700),
            child: Text(l10n.submit, style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}
