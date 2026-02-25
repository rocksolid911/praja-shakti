import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../cubit/report_cubit.dart';
import '../cubit/report_state.dart';
import '../../../core/api/api_client.dart';
import '../../../core/models/report.dart';

class ReportDetailScreen extends StatelessWidget {
  final int reportId;
  const ReportDetailScreen({super.key, required this.reportId});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => ReportCubit(context.read<ApiClient>())..loadReport(reportId),
      child: const _ReportDetailView(),
    );
  }
}

class _ReportDetailView extends StatelessWidget {
  const _ReportDetailView();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('रिपोर्ट विवरण')),
      body: BlocBuilder<ReportCubit, ReportState>(
        builder: (context, state) {
          if (state is ReportLoading) {
            return const Center(child: CircularProgressIndicator());
          }
          if (state is ReportError) {
            return Center(child: Text(state.message));
          }
          if (state is ReportLoaded) {
            return _ReportDetail(report: state.report);
          }
          return const SizedBox.shrink();
        },
      ),
    );
  }
}

class _ReportDetail extends StatelessWidget {
  final Report report;
  const _ReportDetail({required this.report});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        // Status banner
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: _statusColor(report.status).withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _statusColor(report.status)),
          ),
          child: Row(
            children: [
              Icon(_categoryIcon(report.category), color: _statusColor(report.status), size: 32),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      report.category.toUpperCase(),
                      style: TextStyle(
                        color: _statusColor(report.status),
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                    Text(
                      report.subCategory.isNotEmpty ? report.subCategory : report.descriptionText,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: _statusColor(report.status),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _statusLabel(report.status),
                  style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        // Vote section
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Column(
                  children: [
                    BlocBuilder<ReportCubit, ReportState>(
                      builder: (context, state) {
                        return IconButton(
                          icon: Icon(
                            report.hasVoted ? Icons.thumb_up : Icons.thumb_up_outlined,
                            color: report.hasVoted ? Colors.green : null,
                            size: 32,
                          ),
                          onPressed: () {
                            if (report.hasVoted) {
                              context.read<ReportCubit>().removeVote(report.id);
                            } else {
                              context.read<ReportCubit>().vote(report.id);
                            }
                          },
                        );
                      },
                    ),
                    Text(
                      '${report.voteCount}',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
                    ),
                    const Text('votes', style: TextStyle(color: Colors.grey, fontSize: 12)),
                  ],
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _urgencyBadge(report.urgency),
                      if (report.ward != null)
                        Text('Ward ${report.ward}', style: const TextStyle(color: Colors.grey)),
                      if (report.isGramSabha)
                        Chip(
                          label: const Text('Gram Sabha', style: TextStyle(fontSize: 11)),
                          backgroundColor: Colors.purple.shade100,
                        ),
                    ],
                  ),
                ),
                if (report.aiConfidence != null)
                  Column(
                    children: [
                      Text(
                        '${(report.aiConfidence! * 100).toStringAsFixed(0)}%',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: report.aiConfidence! > 0.7 ? Colors.green : Colors.orange,
                        ),
                      ),
                      const Text('AI confidence', style: TextStyle(fontSize: 10, color: Colors.grey)),
                    ],
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        // Description
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('विवरण', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Text(report.descriptionText),
                if (report.descriptionHindi.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(report.descriptionHindi, style: TextStyle(color: Colors.grey.shade600)),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        // Meta info
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                _metaRow('Reported by', report.reporterName.isNotEmpty ? report.reporterName : 'Anonymous'),
                _metaRow('Village', report.villageName),
                _metaRow('Date', _formatDate(report.createdAt)),
                if (report.latitude != null)
                  _metaRow('Location', '${report.latitude!.toStringAsFixed(4)}, ${report.longitude!.toStringAsFixed(4)}'),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _metaRow(String key, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(width: 100, child: Text(key, style: const TextStyle(color: Colors.grey, fontSize: 13))),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 13))),
        ],
      ),
    );
  }

  Widget _urgencyBadge(String urgency) {
    final color = urgency == 'critical' ? Colors.red
        : urgency == 'high' ? Colors.deepOrange
        : urgency == 'medium' ? Colors.orange
        : Colors.green;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: color.withOpacity(0.15), borderRadius: BorderRadius.circular(6)),
      child: Text(urgency.toUpperCase(), style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold)),
    );
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'adopted': return Colors.amber.shade700;
      case 'in_progress': return Colors.blue;
      case 'completed': return Colors.green;
      case 'delayed': return Colors.red.shade900;
      default: return Colors.red;
    }
  }

  String _statusLabel(String status) => switch (status) {
    'reported' => 'रिपोर्ट',
    'adopted' => 'स्वीकृत',
    'in_progress' => 'जारी',
    'completed' => 'पूर्ण',
    'delayed' => 'विलंबित',
    _ => status,
  };

  IconData _categoryIcon(String category) {
    switch (category) {
      case 'water': return Icons.water_drop;
      case 'road': return Icons.add_road;
      case 'health': return Icons.local_hospital;
      case 'education': return Icons.school;
      case 'electricity': return Icons.bolt;
      case 'sanitation': return Icons.wc;
      default: return Icons.report_problem;
    }
  }

  String _formatDate(DateTime dt) {
    return '${dt.day}/${dt.month}/${dt.year}';
  }
}
