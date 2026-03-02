import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';
import '../cubit/report_cubit.dart';
import '../cubit/report_state.dart';
import '../../../core/api/api_client.dart';
import '../../../core/models/report.dart';
import '../../../l10n/app_localizations.dart';

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
    return BlocBuilder<ReportCubit, ReportState>(
      builder: (context, state) {
        final appBarTitle = state is ReportLoaded
            ? 'Report #${state.report.id}'
            : AppLocalizations.of(context).reportDetails;
        return Scaffold(
          appBar: AppBar(
            title: Text(appBarTitle, style: const TextStyle(fontWeight: FontWeight.bold)),
          ),
          body: Builder(builder: (context) {
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
          }),
        );
      },
    );
  }
}

class _ReportDetail extends StatelessWidget {
  final Report report;
  const _ReportDetail({required this.report});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        // Report number banner
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.indigo.shade600, Colors.indigo.shade400],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              const Icon(Icons.tag, color: Colors.white, size: 20),
              const SizedBox(width: 8),
              Text(
                'Report #${report.id}',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
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
                  _statusLabel(report.status, l10n),
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
                    Text(l10n.votes, style: const TextStyle(color: Colors.grey, fontSize: 12)),
                  ],
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _urgencyBadge(report.urgency),
                      if (report.ward != null)
                        Text('${l10n.ward} ${report.ward}', style: const TextStyle(color: Colors.grey)),
                      if (report.isGramSabha)
                        Chip(
                          label: Text(l10n.gramSabha, style: const TextStyle(fontSize: 11)),
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
                      Text(l10n.aiConfidence, style: const TextStyle(fontSize: 10, color: Colors.grey)),
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
                Text(l10n.description, style: const TextStyle(fontWeight: FontWeight.bold)),
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
                _metaRow(l10n.reportedBy, report.reporterName.isNotEmpty ? report.reporterName : 'Anonymous'),
                _metaRow(l10n.villageLabel, report.villageName),
                _metaRow(l10n.dateLabel, _formatDate(report.createdAt)),
                if (report.latitude != null)
                  _metaRow(l10n.locationLabel, '${report.latitude!.toStringAsFixed(4)}, ${report.longitude!.toStringAsFixed(4)}'),
                if (report.latitude != null && report.longitude != null) ...[
                  const SizedBox(height: 12),
                  _LocationMap(lat: report.latitude!, lng: report.longitude!, category: report.category),
                ],
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

  String _statusLabel(String status, AppLocalizations l10n) => switch (status) {
    'reported' => l10n.reported,
    'adopted' => l10n.adopted,
    'in_progress' => l10n.inProgress,
    'completed' => l10n.completed,
    'delayed' => l10n.delayed,
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

class _LocationMap extends StatelessWidget {
  final double lat;
  final double lng;
  final String category;

  const _LocationMap({required this.lat, required this.lng, required this.category});

  Color get _pinColor {
    switch (category) {
      case 'water': return Colors.blue;
      case 'road': return Colors.orange;
      case 'health': return Colors.red;
      case 'education': return Colors.purple;
      case 'electricity': return Colors.yellow.shade800;
      case 'sanitation': return Colors.teal;
      default: return Colors.grey.shade700;
    }
  }

  Future<void> _navigate() async {
    final uri = Uri.parse('https://www.google.com/maps/dir/?api=1&destination=$lat,$lng');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: SizedBox(
        height: 200,
        child: Stack(
          children: [
            FlutterMap(
              options: MapOptions(
                initialCenter: LatLng(lat, lng),
                initialZoom: 15.5,
                interactionOptions: const InteractionOptions(
                  flags: InteractiveFlag.pinchZoom | InteractiveFlag.doubleTapZoom,
                ),
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.prajashakti.app',
                ),
                MarkerLayer(
                  markers: [
                    Marker(
                      point: LatLng(lat, lng),
                      width: 40,
                      height: 40,
                      child: Icon(Icons.location_pin, color: _pinColor, size: 40),
                    ),
                  ],
                ),
              ],
            ),
            // Navigate button — bottom right
            Positioned(
              bottom: 10,
              right: 10,
              child: ElevatedButton.icon(
                onPressed: _navigate,
                icon: const Icon(Icons.navigation, size: 16),
                label: const Text('Navigate', style: TextStyle(fontSize: 13)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.blue.shade700,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  elevation: 3,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
