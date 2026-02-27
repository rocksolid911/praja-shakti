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
            // Layer 2: Satellite imagery (ESRI World Imagery — free, no CORS, works on web)
            if (state.showSatellite)
              TileLayer(
                urlTemplate:
                    'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}',
                userAgentPackageName: 'com.prajashakti.app',
                maxZoom: 19,
              ),
            // Layer 1: Report markers
            if (state.showReports)
              MarkerLayer(markers: _buildReportMarkers(context, state.reports)),
            // Layer 3: Infrastructure markers
            if (state.showInfrastructure)
              MarkerLayer(markers: _buildInfraMarkers(context, state.infrastructure)),
            // Layer 4: Heatmap (gap analysis circles)
            if (state.showHeatmap)
              CircleLayer(circles: _buildHeatmapCircles(state.heatmapPoints)),
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
        // Layer 6: Fund Status overlay (top-left)
        if (state.showFundStatus && state.fundStatus.isNotEmpty)
          Positioned(
            top: 100, left: 12,
            child: _FundStatusOverlay(fundStatus: state.fundStatus),
          ),
        // Layer 7: Demographics overlay (bottom-left, above layer controls)
        if (state.showDemographics && state.demographics.isNotEmpty)
          Positioned(
            bottom: 100, left: 12,
            child: _DemographicsOverlay(demographics: state.demographics),
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
        .where((p) => p.lat != null && p.lng != null)
        .map((p) => Marker(
              point: LatLng(p.lat!, p.lng!),
              width: 36,
              height: 36,
              child: GestureDetector(
                onTap: () => context.push('/project/${p.id}'),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.blue.shade700,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                    boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 4)],
                  ),
                  child: const Icon(Icons.construction, size: 16, color: Colors.white),
                ),
              ),
            ))
        .toList();
  }

  List<Marker> _buildInfraMarkers(BuildContext context, List<Map<String, dynamic>> infrastructure) {
    return infrastructure.map((i) => Marker(
      point: LatLng(i['lat'] as double, i['lng'] as double),
      width: 36,
      height: 36,
      child: GestureDetector(
        onTap: () => _showInfraDetail(context, i),
        child: Container(
          decoration: BoxDecoration(
            color: _infraColor(i['type'] as String),
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 1.5),
            boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 4)],
          ),
          child: Icon(_infraIcon(i['type'] as String), size: 16, color: Colors.white),
        ),
      ),
    )).toList();
  }

  void _showInfraDetail(BuildContext context, Map<String, dynamic> infra) {
    final type = infra['type'] as String;
    final name = (infra['name'] as String?) ?? '';
    final lat = infra['lat'] as double;
    final lng = infra['lng'] as double;

    const typeLabels = {
      'school': 'School',
      'hospital': 'Hospital / Health Centre',
      'market': 'Market / Haat',
      'water_source': 'Water Source',
      'road': 'Road',
    };

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: _infraColor(type),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(_infraIcon(type), color: Colors.white, size: 24),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name.isNotEmpty ? name : (typeLabels[type] ?? type),
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        typeLabels[type] ?? type,
                        style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 8),
            _InfoRow(icon: Icons.location_on, label: 'Coordinates',
                value: '${lat.toStringAsFixed(4)}°N, ${lng.toStringAsFixed(4)}°E'),
            const SizedBox(height: 8),
            _InfoRow(icon: Icons.category, label: 'Type',
                value: typeLabels[type] ?? type),
          ],
        ),
      ),
    );
  }

  List<CircleMarker> _buildHeatmapCircles(List<Map<String, dynamic>> heatmapPoints) {
    return heatmapPoints.map((h) => CircleMarker(
      point: LatLng(h['lat'] as double, h['lng'] as double),
      radius: 300 + ((h['weight'] as double) * 20),
      color: Colors.deepOrange.withOpacity(((h['weight'] as double).clamp(0.0, 1.0)) * 0.4),
      useRadiusInMeter: true,
    )).toList();
  }

  Color _infraColor(String type) {
    switch (type) {
      case 'school': return Colors.purple;
      case 'hospital': return Colors.red;
      case 'market': return Colors.orange;
      case 'water_source': return Colors.blue;
      case 'road': return Colors.brown;
      default: return Colors.grey;
    }
  }

  IconData _infraIcon(String type) {
    switch (type) {
      case 'school': return Icons.school;
      case 'hospital': return Icons.local_hospital;
      case 'market': return Icons.store;
      case 'water_source': return Icons.water_drop;
      case 'road': return Icons.add_road;
      default: return Icons.place;
    }
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

class _FundStatusOverlay extends StatelessWidget {
  final Map<String, dynamic> fundStatus;
  const _FundStatusOverlay({required this.fundStatus});

  @override
  Widget build(BuildContext context) {
    final fundInr = (fundStatus['fund_available_inr'] as num?)?.toInt() ?? 0;
    final panchayatName = fundStatus['panchayat_name'] ?? '';
    final fundLabel = fundInr >= 100000
        ? '₹${(fundInr / 100000).toStringAsFixed(1)}L'
        : '₹${(fundInr / 1000).toStringAsFixed(0)}K';
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 4)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.account_balance, size: 14, color: Colors.green.shade700),
              const SizedBox(width: 4),
              Text('Funds', style: TextStyle(fontSize: 10, color: Colors.grey.shade600)),
            ],
          ),
          Text(fundLabel, style: TextStyle(
            fontSize: 16, fontWeight: FontWeight.bold, color: Colors.green.shade700,
          )),
          if (panchayatName.isNotEmpty)
            Text(panchayatName, style: const TextStyle(fontSize: 9, color: Colors.grey)),
          Text('available', style: const TextStyle(fontSize: 9, color: Colors.grey)),
        ],
      ),
    );
  }
}

class _DemographicsOverlay extends StatelessWidget {
  final Map<String, dynamic> demographics;
  const _DemographicsOverlay({required this.demographics});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 4)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.people, size: 14, color: Colors.teal.shade700),
              const SizedBox(width: 4),
              Text('Demographics', style: TextStyle(fontSize: 10, color: Colors.grey.shade600)),
            ],
          ),
          const SizedBox(height: 4),
          _DemoRow('Population', '${demographics['population'] ?? '—'}'),
          _DemoRow('Households', '${demographics['households'] ?? '—'}'),
          _DemoRow('Agri HH', '${demographics['agricultural_households'] ?? '—'}'),
          if (demographics['groundwater_depth_m'] != null)
            _DemoRow('Groundwater', '${demographics['groundwater_depth_m']}m'),
        ],
      ),
    );
  }
}

class _DemoRow extends StatelessWidget {
  final String label, value;
  const _DemoRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('$label: ', style: const TextStyle(fontSize: 10, color: Colors.grey)),
        Text(value, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
      ],
    );
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

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _InfoRow({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: Colors.grey.shade500),
        const SizedBox(width: 8),
        Text('$label: ', style: TextStyle(fontSize: 13, color: Colors.grey.shade600)),
        Expanded(
          child: Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
        ),
      ],
    );
  }
}
