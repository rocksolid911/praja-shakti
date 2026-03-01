import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../cubit/scheme_cubit.dart';
import '../cubit/scheme_state.dart';
import '../../../core/api/api_client.dart';
import '../../../l10n/app_localizations.dart';
import '../../auth/cubit/auth_cubit.dart';

class SchemeExplorerScreen extends StatelessWidget {
  const SchemeExplorerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => SchemeCubit(context.read<ApiClient>()),
      child: const _SchemeExplorerView(),
    );
  }
}

class _SchemeExplorerView extends StatefulWidget {
  const _SchemeExplorerView();

  @override
  State<_SchemeExplorerView> createState() => _SchemeExplorerViewState();
}

class _SchemeExplorerViewState extends State<_SchemeExplorerView> {
  final _queryController = TextEditingController();
  final _scrollController = ScrollController();

  List<String> _getQuickQueries(AppLocalizations l10n) => [
    l10n.quickQuery1,
    l10n.quickQuery2,
    l10n.quickQuery3,
    l10n.quickQuery4,
    l10n.quickQuery5,
  ];

  @override
  void dispose() {
    _queryController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(AppLocalizations.of(context).schemeAdvisor, style: const TextStyle(fontSize: 16)),
            Text(AppLocalizations.of(context).aiPoweredSchemeAdvisor, style: const TextStyle(fontSize: 11, color: Colors.white70)),
          ],
        ),
        backgroundColor: Colors.indigo.shade700,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => context.read<SchemeCubit>().clearHistory(),
            tooltip: AppLocalizations.of(context).clearChat,
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: BlocConsumer<SchemeCubit, SchemeState>(
              listener: (context, state) {
                if (state is SchemeQueryResult) {
                  Future.delayed(const Duration(milliseconds: 100), () {
                    if (_scrollController.hasClients) {
                      _scrollController.animateTo(
                        _scrollController.position.maxScrollExtent,
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeOut,
                      );
                    }
                  });
                }
              },
              builder: (context, state) {
                if (state is SchemeInitial) {
                  return _buildWelcome(context);
                }
                final history = state is SchemeQueryResult ? state.history : <SchemeMessage>[];
                return ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(16),
                  itemCount: history.length + (state is SchemeLoading ? 1 : 0),
                  itemBuilder: (context, i) {
                    if (i == history.length && state is SchemeLoading) {
                      return const Align(
                        alignment: Alignment.centerLeft,
                        child: Padding(
                          padding: EdgeInsets.all(8),
                          child: _TypingIndicator(),
                        ),
                      );
                    }
                    return _MessageBubble(message: history[i]);
                  },
                );
              },
            ),
          ),
          _buildInputArea(context),
        ],
      ),
    );
  }

  Widget _buildWelcome(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final quickQueries = _getQuickQueries(l10n);
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.indigo.shade50,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                Icon(Icons.auto_awesome, size: 48, color: Colors.indigo.shade700),
                const SizedBox(height: 12),
                Text(
                  l10n.schemeWelcomeTitle,
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.indigo.shade800),
                ),
                const SizedBox(height: 8),
                Text(
                  l10n.schemeWelcomeBody,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey.shade600),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(l10n.frequentlyAsked, style: const TextStyle(fontWeight: FontWeight.bold)),
          ),
          const SizedBox(height: 12),
          ...quickQueries.map((q) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: InkWell(
              onTap: () {
                _queryController.text = q;
                _sendQuery(context);
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border.all(color: Colors.indigo.shade200),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  children: [
                    Icon(Icons.chat_bubble_outline, size: 16, color: Colors.indigo.shade400),
                    const SizedBox(width: 8),
                    Expanded(child: Text(q, style: const TextStyle(fontSize: 13))),
                    Icon(Icons.arrow_forward_ios, size: 12, color: Colors.grey.shade400),
                  ],
                ),
              ),
            ),
          )),
        ],
      ),
    );
  }

  Widget _buildInputArea(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        left: 12, right: 12, top: 8,
        bottom: MediaQuery.of(context).viewInsets.bottom + 8,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 4, offset: const Offset(0, -2))],
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _queryController,
                decoration: InputDecoration(
                  hintText: AppLocalizations.of(context).askAboutScheme,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(24)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                ),
                maxLines: null,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _sendQuery(context),
              ),
            ),
            const SizedBox(width: 8),
            BlocBuilder<SchemeCubit, SchemeState>(
              builder: (context, state) {
                final loading = state is SchemeLoading;
                return CircleAvatar(
                  backgroundColor: Colors.indigo.shade700,
                  child: loading
                      ? const SizedBox(width: 20, height: 20,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : IconButton(
                          icon: const Icon(Icons.send, color: Colors.white),
                          onPressed: () => _sendQuery(context),
                        ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  void _sendQuery(BuildContext context) {
    final q = _queryController.text.trim();
    if (q.isEmpty) return;
    _queryController.clear();
    context.read<SchemeCubit>().query(q, villageId: context.read<AuthCubit>().currentVillageId);
  }
}

class _MessageBubble extends StatelessWidget {
  final SchemeMessage message;
  const _MessageBubble({required this.message});

  @override
  Widget build(BuildContext context) {
    final isUser = message.isUser;
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.8),
        child: Column(
          crossAxisAlignment: isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: isUser ? Colors.indigo.shade700 : Colors.grey.shade100,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(16),
                  topRight: const Radius.circular(16),
                  bottomLeft: Radius.circular(isUser ? 16 : 4),
                  bottomRight: Radius.circular(isUser ? 4 : 16),
                ),
              ),
              child: Text(
                message.text,
                style: TextStyle(
                  color: isUser ? Colors.white : Colors.black87,
                  fontSize: 14,
                ),
              ),
            ),
            if (!isUser && message.sources.isNotEmpty) ...[
              const SizedBox(height: 4),
              Wrap(
                spacing: 4,
                children: message.sources.map((s) => Chip(
                  label: Text(s['scheme'] ?? '', style: const TextStyle(fontSize: 10)),
                  padding: EdgeInsets.zero,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  backgroundColor: Colors.indigo.shade50,
                )).toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _TypingIndicator extends StatelessWidget {
  const _TypingIndicator();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(width: 2),
          _dot(0), const SizedBox(width: 4),
          _dot(1), const SizedBox(width: 4),
          _dot(2),
        ],
      ),
    );
  }

  Widget _dot(int i) {
    return Container(
      width: 8, height: 8,
      decoration: BoxDecoration(color: Colors.grey.shade400, shape: BoxShape.circle),
    );
  }
}
