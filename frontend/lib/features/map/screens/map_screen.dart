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
import '../../../l10n/app_localizations.dart';
import '../../auth/cubit/auth_cubit.dart';
import '../../auth/cubit/auth_state.dart';

// ── Design constants ──────────────────────────────────────────────────────────
const _kDeepNavy = Color(0xFF1A237E);
const _kStateBlue = Color(0xFF3F51B5);
const _kBgGrey = Color(0xFFF5F7FA);
const _kCardRadius = 16.0;

class MapScreen extends StatelessWidget {
  const MapScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final villageId = context.read<AuthCubit>().currentVillageId;
    return BlocProvider(
      create: (_) => MapCubit(context.read<ApiClient>())..loadVillageData(villageId),
      child: const _MapView(),
    );
  }
}

class _MapView extends StatefulWidget {
  const _MapView();

  @override
  State<_MapView> createState() => _MapViewState();
}

class _MapViewState extends State<_MapView> {
  // Selected marker popup state
  Report? _selectedReport;
  Project? _selectedProject;

  void _selectReport(Report r) => setState(() { _selectedReport = r; _selectedProject = null; });
  void _selectProject(Project p) => setState(() { _selectedProject = p; _selectedReport = null; });
  void _clearSelection() => setState(() { _selectedReport = null; _selectedProject = null; });

  @override
  Widget build(BuildContext context) {
    return BlocListener<AuthCubit, AuthState>(
      listenWhen: (prev, curr) {
        int prevId = 1, currId = 1;
        if (prev is AuthAuthenticated) prevId = prev.user.villageId ?? 1;
        if (prev is AuthProfileLoaded) prevId = prev.user.villageId ?? 1;
        if (curr is AuthAuthenticated) currId = curr.user.villageId ?? 1;
        if (curr is AuthProfileLoaded) currId = curr.user.villageId ?? 1;
        return prevId != currId;
      },
      listener: (context, state) {
        final villageId = context.read<AuthCubit>().currentVillageId;
        context.read<MapCubit>().loadVillageData(villageId);
      },
      child: Scaffold(
        body: BlocBuilder<MapCubit, MapState>(
          builder: (context, state) {
            if (state is MapLoading) {
              return const Center(child: CircularProgressIndicator(color: _kStateBlue));
            }
            if (state is MapError) {
              final l10n = AppLocalizations.of(context);
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 64, height: 64,
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.error_outline, size: 32, color: Colors.red.shade400),
                    ),
                    const SizedBox(height: 16),
                    Text(state.message, style: const TextStyle(fontSize: 15, color: Color(0xFF263238))),
                    const SizedBox(height: 12),
                    TextButton.icon(
                      onPressed: () => context.read<MapCubit>().refresh(),
                      icon: const Icon(Icons.refresh_rounded, size: 18),
                      label: Text(l10n.retry),
                      style: TextButton.styleFrom(foregroundColor: _kStateBlue),
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
      ),
    );
  }

  Widget _buildMap(BuildContext context, MapLoaded state) {
    final village = state.selectedVillage;
    final center = village?.latitude != null
        ? LatLng(village!.latitude!, village.longitude!)
        : const LatLng(20.5937, 78.9629);
    final isMobile = MediaQuery.of(context).size.width < 600;
    final markerSize = isMobile ? 28.0 : 36.0;
    final iconSize = isMobile ? 13.0 : 16.0;

    return Stack(
      children: [
        // ── Map ────────────────────────────────────────────────────────────
        GestureDetector(
          onTap: _clearSelection,
          child: FlutterMap(
            options: MapOptions(initialCenter: center, initialZoom: village != null ? 17 : 5, maxZoom: 19),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.prajashakti.app',
              ),
              if (state.showSatellite)
                TileLayer(
                  urlTemplate:
                      'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}',
                  userAgentPackageName: 'com.prajashakti.app',
                  maxZoom: 19,
                ),
              if (state.showReports)
                MarkerLayer(markers: _buildReportMarkers(context, state.reports, markerSize, iconSize)),
              if (state.showInfrastructure)
                MarkerLayer(markers: _buildInfraMarkers(context, state.infrastructure, markerSize, iconSize)),
              if (state.showHeatmap)
                CircleLayer(circles: _buildHeatmapCircles(state.heatmapPoints)),
              if (state.showProjects)
                MarkerLayer(markers: _buildProjectMarkers(context, state.projects, markerSize, iconSize)),
              if (state.showReports)
                CircleLayer(circles: _buildClusterCircles(state.clusters)),
            ],
          ),
        ),

        // ── Top: village header bar ────────────────────────────────────────
        Positioned(
          top: 0, left: 0, right: 0,
          child: _MapHeader(state: state),
        ),

        // ── Fund Status overlay (top-left, below header) ─────────────────
        if (state.showFundStatus && state.fundStatus.isNotEmpty)
          Positioned(
            top: 80, left: 12,
            child: _FundStatusOverlay(fundStatus: state.fundStatus),
          ),

        // ── Demographics overlay (bottom-left) ───────────────────────────
        if (state.showDemographics && state.demographics.isNotEmpty)
          Positioned(
            bottom: 90, left: 12,
            child: _DemographicsOverlay(demographics: state.demographics),
          ),

        // ── Priority score badge (top right, below header) ───────────────
        if (state.clusters.isNotEmpty)
          Positioned(
            top: 80, right: 12,
            child: _PriorityBadge(topCluster: state.clusters.first),
          ),

        // ── Right-side floating controls ──────────────────────────────────
        Positioned(
          right: 14, bottom: 28,
          child: _FloatingControls(
            state: state,
            onReport: () => context.push('/report'),
          ),
        ),

        // ── Selected marker info card ─────────────────────────────────────
        if (_selectedReport != null)
          Positioned(
            bottom: 16, left: 12, right: 76,
            child: _MarkerInfoCard(
              color: _markerColor(_selectedReport!.status),
              icon: _categoryIcon(_selectedReport!.category),
              title: _selectedReport!.category.isNotEmpty
                  ? '${_selectedReport!.category[0].toUpperCase()}${_selectedReport!.category.substring(1)} Issue'
                  : 'Report',
              subtitle: _selectedReport!.descriptionText.length > 80
                  ? '${_selectedReport!.descriptionText.substring(0, 80)}...'
                  : _selectedReport!.descriptionText,
              trailing: _selectedReport!.urgency.toUpperCase(),
              trailingColor: _urgencyColor(_selectedReport!.urgency),
              votes: _selectedReport!.voteCount,
              onDetails: () {
                context.push('/report/${_selectedReport!.id}');
                _clearSelection();
              },
              onClose: _clearSelection,
            ),
          ),
        if (_selectedProject != null)
          Positioned(
            bottom: 16, left: 12, right: 76,
            child: _MarkerInfoCard(
              color: _kStateBlue,
              icon: Icons.construction,
              title: _selectedProject!.title,
              subtitle: _selectedProject!.category.isNotEmpty
                  ? _selectedProject!.category[0].toUpperCase() + _selectedProject!.category.substring(1)
                  : '',
              trailing: '₹${(_selectedProject!.estimatedCostInr / 100000).toStringAsFixed(1)}L',
              trailingColor: Colors.green.shade700,
              status: _selectedProject!.status,
              onDetails: () {
                context.push('/project/${_selectedProject!.id}');
                _clearSelection();
              },
              onClose: _clearSelection,
            ),
          ),
      ],
    );
  }

  Color _urgencyColor(String urgency) {
    switch (urgency) {
      case 'critical': return const Color(0xFFB71C1C);
      case 'high': return const Color(0xFFFF5252);
      case 'medium': return const Color(0xFFFF9800);
      default: return const Color(0xFF4CAF50);
    }
  }

  // ── Marker builders (unchanged logic) ───────────────────────────────────────

  List<Marker> _buildReportMarkers(BuildContext context, List<Report> reports, double size, double iconSz) {
    return reports
        .where((r) => r.latitude != null && r.longitude != null)
        .map((r) => Marker(
              point: LatLng(r.latitude!, r.longitude!),
              width: size,
              height: size,
              child: GestureDetector(
                onTap: () => _selectReport(r),
                child: Container(
                  decoration: BoxDecoration(
                    color: _markerColor(r.status),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: size > 30 ? 2 : 1.5),
                    boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 4)],
                  ),
                  child: Icon(_categoryIcon(r.category), size: iconSz, color: Colors.white),
                ),
              ),
            ))
        .toList();
  }

  List<Marker> _buildProjectMarkers(BuildContext context, List<Project> projects, double size, double iconSz) {
    return projects
        .where((p) => p.lat != null && p.lng != null)
        .map((p) => Marker(
              point: LatLng(p.lat!, p.lng!),
              width: size,
              height: size,
              child: GestureDetector(
                onTap: () => _selectProject(p),
                child: Container(
                  decoration: BoxDecoration(
                    color: _kStateBlue,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: size > 30 ? 2 : 1.5),
                    boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 4)],
                  ),
                  child: Icon(Icons.construction, size: iconSz, color: Colors.white),
                ),
              ),
            ))
        .toList();
  }

  List<Marker> _buildInfraMarkers(BuildContext context, List<Map<String, dynamic>> infrastructure, double size, double iconSz) {
    return infrastructure.map((i) => Marker(
      point: LatLng(i['lat'] as double, i['lng'] as double),
      width: size,
      height: size,
      child: GestureDetector(
        onTap: () => _showInfraDetail(context, i),
        child: Container(
          decoration: BoxDecoration(
            color: _infraColor(i['type'] as String),
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: size > 30 ? 1.5 : 1),
            boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 4)],
          ),
          child: Icon(_infraIcon(i['type'] as String), size: iconSz, color: Colors.white),
        ),
      ),
    )).toList();
  }

  void _showInfraDetail(BuildContext context, Map<String, dynamic> infra) {
    final type = infra['type'] as String;
    final name = (infra['name'] as String?) ?? '';
    final lat = infra['lat'] as double;
    final lng = infra['lng'] as double;
    final l10n = AppLocalizations.of(context);

    final typeLabels = {
      'school': l10n.infraSchool,
      'hospital': l10n.infraHospital,
      'market': l10n.infraMarket,
      'water_source': l10n.infraWaterSource,
      'road': l10n.infraRoad,
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
                  width: 48, height: 48,
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
            _InfoRow(icon: Icons.location_on, label: l10n.coordinates,
                value: '${lat.toStringAsFixed(4)}°N, ${lng.toStringAsFixed(4)}°E'),
            const SizedBox(height: 8),
            _InfoRow(icon: Icons.category, label: l10n.type,
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
      radius: c.radiusKm * 500,
      color: _clusterColor(c.category).withOpacity(0.15),
      borderColor: _clusterColor(c.category).withOpacity(0.5),
      borderStrokeWidth: 2,
      useRadiusInMeter: true,
    )).toList();
  }

  Color _markerColor(String status) {
    switch (status) {
      case 'reported': return const Color(0xFFFF5252);
      case 'adopted': return const Color(0xFFFFC107);
      case 'in_progress': return const Color(0xFF90A4AE);
      case 'completed': return const Color(0xFF2E7D32);
      case 'delayed': return const Color(0xFFB71C1C);
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

// ── Map Header Bar ────────────────────────────────────────────────────────────

class _MapHeader extends StatelessWidget {
  final MapLoaded state;
  const _MapHeader({required this.state});

  @override
  Widget build(BuildContext context) {
    final village = state.selectedVillage;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 12, 10),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 8, offset: const Offset(0, 2)),
        ],
      ),
      child: Row(
        children: [
          // Village info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  village?.name ?? 'Village Intelligence Map',
                  style: const TextStyle(
                    fontWeight: FontWeight.w700, fontSize: 17, color: Color(0xFF263238),
                  ),
                ),
                if (village != null)
                  Text(
                    '${village.panchayatName ?? ''} • ${village.districtName ?? ''}',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
              ],
            ),
          ),
          // Stats badges
          _StatBadge(
            icon: Icons.report_rounded,
            value: '${state.reports.length}',
            color: const Color(0xFFFF5252),
          ),
          const SizedBox(width: 6),
          _StatBadge(
            icon: Icons.construction_rounded,
            value: '${state.projects.length}',
            color: _kStateBlue,
          ),
          const SizedBox(width: 4),
          // Refresh
          Material(
            color: Colors.transparent,
            shape: const CircleBorder(),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: () => context.read<MapCubit>().refresh(),
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Icon(Icons.refresh_rounded, size: 22, color: Colors.grey.shade600),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Stat Badge ────────────────────────────────────────────────────────────────

class _StatBadge extends StatelessWidget {
  final IconData icon;
  final String value;
  final Color color;
  const _StatBadge({required this.icon, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(value, style: TextStyle(
            color: color, fontWeight: FontWeight.w700, fontSize: 13,
          )),
        ],
      ),
    );
  }
}

// ── Floating Controls (right side) ────────────────────────────────────────────

class _FloatingControls extends StatelessWidget {
  final MapLoaded state;
  final VoidCallback onReport;
  const _FloatingControls({required this.state, required this.onReport});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Layers button
        _FloatingBtn(
          icon: Icons.layers_rounded,
          tooltip: 'Layers',
          onTap: () => _showLayerSheet(context, state),
        ),
        const SizedBox(height: 10),
        // Location button
        _FloatingBtn(
          icon: Icons.my_location_rounded,
          tooltip: 'My Location',
          onTap: () => context.read<MapCubit>().refresh(),
        ),
        const SizedBox(height: 10),
        // Report button (accent)
        _FloatingBtn(
          icon: Icons.add_rounded,
          tooltip: 'Report Issue',
          onTap: onReport,
          filled: true,
        ),
      ],
    );
  }

  void _showLayerSheet(BuildContext context, MapLoaded state) {
    final l10n = AppLocalizations.of(context);
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => BlocProvider.value(
        value: context.read<MapCubit>(),
        child: BlocBuilder<MapCubit, MapState>(
          builder: (ctx, mapState) {
            if (mapState is! MapLoaded) return const SizedBox.shrink();
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
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
                    const Text('Map Layers', style: TextStyle(
                      fontSize: 18, fontWeight: FontWeight.w700, color: Color(0xFF263238),
                    )),
                    const SizedBox(height: 4),
                    Text('Toggle map data layers on/off',
                        style: TextStyle(fontSize: 13, color: Colors.grey.shade600)),
                    const SizedBox(height: 16),
                    Flexible(
                      child: SingleChildScrollView(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _LayerToggle(label: l10n.layerReports, icon: Icons.report_rounded,
                                active: mapState.showReports, layer: 'reports', color: const Color(0xFFFF5252)),
                            _LayerToggle(label: l10n.layerProjects, icon: Icons.construction_rounded,
                                active: mapState.showProjects, layer: 'projects', color: _kStateBlue),
                            _LayerToggle(label: l10n.layerSatellite, icon: Icons.satellite_alt_rounded,
                                active: mapState.showSatellite, layer: 'satellite', color: const Color(0xFF00695C)),
                            _LayerToggle(label: l10n.layerInfra, icon: Icons.business_rounded,
                                active: mapState.showInfrastructure, layer: 'infrastructure', color: const Color(0xFFFF9800)),
                            _LayerToggle(label: l10n.layerHeatmap, icon: Icons.whatshot_rounded,
                                active: mapState.showHeatmap, layer: 'heatmap', color: Colors.deepOrange),
                            _LayerToggle(label: l10n.layerFunds, icon: Icons.account_balance_rounded,
                                active: mapState.showFundStatus, layer: 'fund_status', color: Colors.purple),
                            _LayerToggle(label: l10n.layerPeople, icon: Icons.people_rounded,
                                active: mapState.showDemographics, layer: 'demographics', color: Colors.teal),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _FloatingBtn extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  final bool filled;
  const _FloatingBtn({
    required this.icon, required this.tooltip, required this.onTap,
    this.filled = false,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: filled ? _kStateBlue : Colors.white,
      shape: const CircleBorder(),
      elevation: 3,
      shadowColor: Colors.black26,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(
          width: 48,
          height: 48,
          child: Icon(icon, size: 22, color: filled ? Colors.white : _kDeepNavy),
        ),
      ),
    );
  }
}

class _LayerToggle extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool active;
  final String layer;
  final Color color;
  const _LayerToggle({
    required this.label, required this.icon, required this.active,
    required this.layer, required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: SwitchListTile(
        secondary: Container(
          width: 36, height: 36,
          decoration: BoxDecoration(
            color: color.withOpacity(0.12),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 18, color: color),
        ),
        title: Text(label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
        value: active,
        activeColor: color,
        dense: true,
        onChanged: (_) => context.read<MapCubit>().toggleLayer(layer),
      ),
    );
  }
}

// ── Overlays ──────────────────────────────────────────────────────────────────

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
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 8)],
      ),
      child: Builder(builder: (context) {
        final l10n = AppLocalizations.of(context);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.account_balance, size: 14, color: Colors.green.shade700),
                const SizedBox(width: 4),
                Text(l10n.layerFunds, style: TextStyle(fontSize: 10, color: Colors.grey.shade600)),
              ],
            ),
            Text(fundLabel, style: TextStyle(
              fontSize: 16, fontWeight: FontWeight.bold, color: Colors.green.shade700,
            )),
            if (panchayatName.isNotEmpty)
              Text(panchayatName, style: const TextStyle(fontSize: 9, color: Colors.grey)),
            Text(l10n.fundsAvailable, style: const TextStyle(fontSize: 9, color: Colors.grey)),
          ],
        );
      }),
    );
  }
}

class _DemographicsOverlay extends StatelessWidget {
  final Map<String, dynamic> demographics;
  const _DemographicsOverlay({required this.demographics});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 8)],
      ),
      child: Builder(builder: (context) {
        final l10n = AppLocalizations.of(context);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.people, size: 14, color: Colors.teal.shade700),
                const SizedBox(width: 4),
                Text(l10n.demographics, style: TextStyle(fontSize: 10, color: Colors.grey.shade600)),
              ],
            ),
            const SizedBox(height: 4),
            _DemoRow(l10n.population, '${demographics['population'] ?? '—'}'),
            _DemoRow(l10n.households, '${demographics['households'] ?? '—'}'),
            _DemoRow(l10n.agriHouseholds, '${demographics['agricultural_households'] ?? '—'}'),
            if (demographics['groundwater_depth_m'] != null)
              _DemoRow(l10n.groundwater, '${demographics['groundwater_depth_m']}m'),
          ],
        );
      }),
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
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 8)],
      ),
      child: Builder(builder: (context) {
        final l10n = AppLocalizations.of(context);
        return Column(
          children: [
            Text(l10n.priority, style: const TextStyle(fontSize: 10, color: Colors.grey)),
            Text(
              '${score.toStringAsFixed(0)}/100',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 18,
                color: score > 70
                    ? const Color(0xFFFF5252)
                    : score > 40
                        ? const Color(0xFFFF9800)
                        : const Color(0xFF2E7D32),
              ),
            ),
            Text(topCluster.category.toUpperCase(),
                style: const TextStyle(fontSize: 9, color: Colors.grey)),
          ],
        );
      }),
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

// ── Marker Info Card (floating popup) ────────────────────────────────────────

class _MarkerInfoCard extends StatelessWidget {
  final Color color;
  final IconData icon;
  final String title;
  final String subtitle;
  final String trailing;
  final Color trailingColor;
  final int? votes;
  final String? status;
  final VoidCallback onDetails;
  final VoidCallback onClose;

  const _MarkerInfoCard({
    required this.color, required this.icon, required this.title,
    required this.subtitle, required this.trailing, required this.trailingColor,
    this.votes, this.status, required this.onDetails, required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 6,
      shadowColor: Colors.black26,
      borderRadius: BorderRadius.circular(14),
      color: Colors.white,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onDetails,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
          child: Row(
            children: [
              // Category icon
              Container(
                width: 40, height: 40,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 20, color: color),
              ),
              const SizedBox(width: 10),
              // Title + subtitle
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(title, style: const TextStyle(
                      fontWeight: FontWeight.w700, fontSize: 13, color: Color(0xFF263238),
                    ), maxLines: 1, overflow: TextOverflow.ellipsis),
                    if (subtitle.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(subtitle, style: TextStyle(
                          fontSize: 11, color: Colors.grey.shade600,
                        ), maxLines: 2, overflow: TextOverflow.ellipsis),
                      ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        // Trailing badge (urgency or cost)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: trailingColor.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(trailing, style: TextStyle(
                            fontSize: 10, fontWeight: FontWeight.w700, color: trailingColor,
                          )),
                        ),
                        if (votes != null && votes! > 0) ...[
                          const SizedBox(width: 8),
                          Icon(Icons.thumb_up_alt_outlined, size: 11, color: Colors.grey.shade500),
                          const SizedBox(width: 2),
                          Text('$votes', style: TextStyle(fontSize: 10, color: Colors.grey.shade600)),
                        ],
                        if (status != null) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: _kStateBlue.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(status!, style: const TextStyle(
                              fontSize: 10, fontWeight: FontWeight.w600, color: _kStateBlue,
                            )),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              // Arrow + close
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  GestureDetector(
                    onTap: onClose,
                    child: Icon(Icons.close, size: 16, color: Colors.grey.shade400),
                  ),
                  const SizedBox(height: 8),
                  Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Colors.grey.shade400),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
