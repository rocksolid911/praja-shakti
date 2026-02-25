import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:go_router/go_router.dart';
import '../cubit/map_cubit.dart';
import '../cubit/map_state.dart';
import '../../../core/api/api_client.dart';
import '../../../core/models/report.dart';
import '../../../core/models/project.dart';

const int _demoVillageId = 1; // Tusra village from demo data

class MapScreen extends StatelessWidget {
  const MapScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => MapCubit(context.read<ApiClient>())..loadVillageData(_demoVillageId),
      child: const _MapView(),
    );
  }
}

class _MapView extends StatelessWidget {
  const _MapView();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: BlocBuilder<MapCubit, MapState>(
        builder: (context, state) {
          if (state is MapLoading) {
            return const Center(child: CircularProgressIndicator());
          }
          if (state is MapError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 48, color: Colors.red),
                  const SizedBox(height: 12),
                  Text(state.message),
                  TextButton(
                    onPressed: () => context.read<MapCubit>().refresh(),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            );
          }
          if (state is MapLoaded) {
            return _buildMap(context, state);
          }
          return const SizedBox.shrink();
        },
      ),
    );
  }

  Widget _buildMap(BuildContext context, MapLoaded state) {
    final village = state.selectedVillage;
    final center = village?.latitude != null
        ? LatLng(village!.latitude!, village.longitude!)
        : const LatLng(20.5937, 78.9629); // India center fallback

    return Stack(
      children: [
        FlutterMap(
          options: MapOptions(initialCenter: center, initialZoom: village != null ? 14 : 5),
          children: [
            // Base tile layer
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.prajashakti.app',
            ),
            // Layer 2: Satellite NDVI overlay (Bhuvan WMS)
            if (state.showSatellite)
              TileLayer(
                wmsOptions: WMSTileLayerOptions(
                  baseUrl: 'https://bhuvan-vec1.nrsc.gov.in/bhuvan/wms?',
                  layers: ['lulc50k_1516'],
                  format: 'image/png',
                  version: '1.1.1',
                ),
                opacity: 0.6,
              ),
            // Layer 1: Report markers
            if (state.showReports)
              MarkerLayer(markers: _buildReportMarkers(context, state.reports)),
            // Layer 5: Project markers
            if (state.showProjects)
              MarkerLayer(markers: _buildProjectMarkers(context, state.projects)),
            // Cluster circles
            if (state.showReports)
              CircleLayer(circles: _buildClusterCircles(state.clusters)),
          ],
        ),
        // Top info bar
        Positioned(
          top: 0, left: 0, right: 0,
          child: _VillageInfoBar(state: state),
        ),
        // Bottom layer controls
        Positioned(
          bottom: 16, left: 16, right: 16,
          child: _LayerControls(state: state),
        ),
        // Priority score badge (top right)
        if (state.clusters.isNotEmpty)
          Positioned(
            top: 100, right: 12,
            child: _PriorityBadge(topCluster: state.clusters.first),
          ),
      ],
    );
  }

  List<Marker> _buildReportMarkers(BuildContext context, List<Report> reports) {
    return reports
        .where((r) => r.latitude != null && r.longitude != null)
        .map((r) => Marker(
              point: LatLng(r.latitude!, r.longitude!),
              width: 36,
              height: 36,
              child: GestureDetector(
                onTap: () => context.push('/report/${r.id}'),
                child: Container(
                  decoration: BoxDecoration(
                    color: _markerColor(r.status),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                    boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 4)],
                  ),
                  child: Icon(_categoryIcon(r.category), size: 16, color: Colors.white),
                ),
              ),
            ))
        .toList();
  }

  List<Marker> _buildProjectMarkers(BuildContext context, List<Project> projects) {
    return projects
        .where((p) => false) // Projects don't have direct lat/lng from list endpoint
        .map((p) => Marker(
              point: const LatLng(0, 0),
              child: const Icon(Icons.construction, color: Colors.blue),
            ))
        .toList();
  }

  List<CircleMarker> _buildClusterCircles(List<ReportCluster> clusters) {
    return clusters.map((c) => CircleMarker(
      point: LatLng(c.latitude, c.longitude),
      radius: c.radiusKm * 500, // approximate pixels
      color: _clusterColor(c.category).withOpacity(0.15),
      borderColor: _clusterColor(c.category).withOpacity(0.5),
      borderStrokeWidth: 2,
      useRadiusInMeter: true,
    )).toList();
  }

  Color _markerColor(String status) {
    switch (status) {
      case 'reported': return Colors.red;
      case 'adopted': return Colors.amber.shade700;
      case 'in_progress': return Colors.blue;
      case 'completed': return Colors.green;
      case 'delayed': return Colors.red.shade900;
      default: return Colors.grey;
    }
  }

  Color _clusterColor(String category) {
    switch (category) {
      case 'water': return Colors.blue;
      case 'road': return Colors.orange;
      case 'health': return Colors.red;
      case 'education': return Colors.purple;
      case 'electricity': return Colors.yellow.shade700;
      case 'sanitation': return Colors.teal;
      default: return Colors.grey;
    }
  }

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
}

class _VillageInfoBar extends StatelessWidget {
  final MapLoaded state;
  const _VillageInfoBar({required this.state});

  @override
  Widget build(BuildContext context) {
    final village = state.selectedVillage;
    return Container(
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 8,
        left: 16, right: 16, bottom: 12,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 4)],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  village?.name ?? 'Village Intelligence Map',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                if (village != null)
                  Text(
                    '${village.panchayatName ?? ''} • ${village.districtName ?? ''}',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
              ],
            ),
          ),
          _StatChip(icon: Icons.report, value: '${state.reports.length}', color: Colors.red),
          const SizedBox(width: 8),
          _StatChip(icon: Icons.construction, value: '${state.projects.length}', color: Colors.blue),
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => context.read<MapCubit>().refresh(),
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final IconData icon;
  final String value;
  final Color color;
  const _StatChip({required this.icon, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(value, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 13)),
        ],
      ),
    );
  }
}

class _LayerControls extends StatelessWidget {
  final MapLoaded state;
  const _LayerControls({required this.state});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 8)],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(bottom: 6),
            child: Text('Map Layers', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _LayerChip(label: 'रिपोर्ट', layer: 'reports', active: state.showReports,
                    icon: Icons.report, color: Colors.red),
                _LayerChip(label: 'Satellite', layer: 'satellite', active: state.showSatellite,
                    icon: Icons.satellite_alt, color: Colors.green),
                _LayerChip(label: 'Infra', layer: 'infrastructure', active: state.showInfrastructure,
                    icon: Icons.business, color: Colors.orange),
                _LayerChip(label: 'Heatmap', layer: 'heatmap', active: state.showHeatmap,
                    icon: Icons.whatshot, color: Colors.deepOrange),
                _LayerChip(label: 'Projects', layer: 'projects', active: state.showProjects,
                    icon: Icons.construction, color: Colors.blue),
                _LayerChip(label: 'Funds', layer: 'fund_status', active: state.showFundStatus,
                    icon: Icons.account_balance, color: Colors.purple),
                _LayerChip(label: 'People', layer: 'demographics', active: state.showDemographics,
                    icon: Icons.people, color: Colors.teal),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LayerChip extends StatelessWidget {
  final String label, layer;
  final bool active;
  final IconData icon;
  final Color color;
  const _LayerChip({required this.label, required this.layer, required this.active,
      required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: FilterChip(
        label: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: active ? Colors.white : color),
            const SizedBox(width: 4),
            Text(label, style: TextStyle(
              fontSize: 11, color: active ? Colors.white : Colors.black87,
            )),
          ],
        ),
        selected: active,
        onSelected: (_) => context.read<MapCubit>().toggleLayer(layer),
        selectedColor: color,
        showCheckmark: false,
        padding: const EdgeInsets.symmetric(horizontal: 2),
        visualDensity: VisualDensity.compact,
      ),
    );
  }
}

class _PriorityBadge extends StatelessWidget {
  final ReportCluster topCluster;
  const _PriorityBadge({required this.topCluster});

  @override
  Widget build(BuildContext context) {
    final score = topCluster.priorityScore ?? 0;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 6)],
      ),
      child: Column(
        children: [
          const Text('Priority', style: TextStyle(fontSize: 10, color: Colors.grey)),
          Text(
            '${score.toStringAsFixed(0)}/100',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 18,
              color: score > 70 ? Colors.red : score > 40 ? Colors.orange : Colors.green,
            ),
          ),
          Text(topCluster.category.toUpperCase(),
              style: const TextStyle(fontSize: 9, color: Colors.grey)),
        ],
      ),
    );
  }
}
