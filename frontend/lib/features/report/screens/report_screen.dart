import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import '../cubit/report_cubit.dart';
import '../cubit/report_state.dart';
import '../../../core/api/api_client.dart';
import '../../../l10n/app_localizations.dart';

class ReportScreen extends StatelessWidget {
  const ReportScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => ReportCubit(context.read<ApiClient>()),
      child: const _ReportView(),
    );
  }
}

class _ReportView extends StatefulWidget {
  const _ReportView();

  @override
  State<_ReportView> createState() => _ReportViewState();
}

class _ReportViewState extends State<_ReportView> {
  final _descController = TextEditingController();
  String _category = 'water';
  String _urgency = 'medium';
  int? _ward;
  double? _latitude, _longitude;
  bool _locationFetched = false;

  static const _categories = [
    ('water', Icons.water_drop, Colors.blue),
    ('road', Icons.add_road, Colors.orange),
    ('health', Icons.local_hospital, Colors.red),
    ('education', Icons.school, Colors.purple),
    ('electricity', Icons.bolt, Colors.yellow),
    ('sanitation', Icons.wc, Colors.teal),
    ('other', Icons.more_horiz, Colors.grey),
  ];

  static const _urgencies = [
    ('low', Colors.green),
    ('medium', Colors.orange),
    ('high', Colors.deepOrange),
    ('critical', Colors.red),
  ];

  static String _categoryLabel(AppLocalizations l10n, String key) => switch (key) {
    'water' => l10n.water,
    'road' => l10n.road,
    'health' => l10n.health,
    'education' => l10n.education,
    'electricity' => l10n.electricity,
    'sanitation' => l10n.sanitation,
    _ => l10n.other,
  };

  static String _urgencyLabel(AppLocalizations l10n, String key) => switch (key) {
    'low' => l10n.urgencyLow,
    'medium' => l10n.urgencyMedium,
    'high' => l10n.urgencyHigh,
    'critical' => l10n.urgencyCritical,
    _ => key,
  };

  @override
  void initState() {
    super.initState();
    _fetchLocation();
  }

  @override
  void dispose() {
    _descController.dispose();
    super.dispose();
  }

  Future<void> _fetchLocation() async {
    try {
      final perm = await Geolocator.requestPermission();
      if (perm == LocationPermission.denied || perm == LocationPermission.deniedForever) return;
      final pos = await Geolocator.getCurrentPosition();
      setState(() {
        _latitude = pos.latitude;
        _longitude = pos.longitude;
        _locationFetched = true;
      });
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<ReportCubit, ReportState>(
      listener: (context, state) {
        if (state is ReportSubmitted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(AppLocalizations.of(context).reportSubmitted(state.report.id)),
              backgroundColor: Colors.green,
            ),
          );
          context.go('/feed');
        } else if (state is ReportError) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(state.message), backgroundColor: Colors.red),
          );
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(AppLocalizations.of(context).reportIssue),
          backgroundColor: Colors.green.shade700,
          foregroundColor: Colors.white,
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Builder(builder: (context) {
            final l10n = AppLocalizations.of(context);
            return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Category selection
              Text(l10n.issueType, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 12),
              GridView.count(
                crossAxisCount: 4,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
                childAspectRatio: 0.9,
                children: _categories.map((cat) => _CategoryTile(
                  label: _categoryLabel(l10n, cat.$1), icon: cat.$2, color: cat.$3,
                  selected: _category == cat.$1,
                  onTap: () => setState(() => _category = cat.$1),
                )).toList(),
              ),
              const SizedBox(height: 20),
              // Description
              Text(l10n.description, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 8),
              TextField(
                controller: _descController,
                maxLines: 4,
                decoration: InputDecoration(
                  hintText: '${l10n.description}...',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  filled: true,
                  fillColor: Colors.grey.shade50,
                ),
              ),
              const SizedBox(height: 20),
              // Urgency
              Text(l10n.urgencyLabel, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 8),
              Row(
                children: _urgencies.map((u) => Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: _UrgencyChip(
                      label: _urgencyLabel(l10n, u.$1), color: u.$2,
                      selected: _urgency == u.$1,
                      onTap: () => setState(() => _urgency = u.$1),
                    ),
                  ),
                )).toList(),
              ),
              const SizedBox(height: 20),
              // Ward number
              Text(l10n.wardNumberOptional, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 8),
              TextField(
                keyboardType: TextInputType.number,
                onChanged: (v) => _ward = int.tryParse(v),
                decoration: InputDecoration(
                  hintText: l10n.ward,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  filled: true, fillColor: Colors.grey.shade50,
                ),
              ),
              const SizedBox(height: 16),
              // Location status
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _locationFetched ? Colors.green.shade50 : Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    Icon(
                      _locationFetched ? Icons.location_on : Icons.location_off,
                      color: _locationFetched ? Colors.green : Colors.orange,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _locationFetched
                            ? '${l10n.locationFound}: ${_latitude?.toStringAsFixed(4)}, ${_longitude?.toStringAsFixed(4)}'
                            : l10n.locationNotAvailable,
                        style: TextStyle(
                          color: _locationFetched ? Colors.green.shade800 : Colors.orange.shade800,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 28),
              BlocBuilder<ReportCubit, ReportState>(
                builder: (context, state) {
                  final loading = state is ReportSubmitting;
                  final l10n = AppLocalizations.of(context);
                  return SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton.icon(
                      onPressed: loading ? null : _submit,
                      icon: loading
                          ? const SizedBox(width: 20, height: 20,
                              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                          : const Icon(Icons.send),
                      label: Text(l10n.submitReport, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green.shade700,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 20),
            ],
          );
          }),
        ),
      ),
    );
  }

  void _submit() {
    final l10n = AppLocalizations.of(context);
    if (_descController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.enterDescription), backgroundColor: Colors.orange),
      );
      return;
    }
    context.read<ReportCubit>().submitTextReport(
      villageId: 1,
      description: _descController.text.trim(),
      category: _category,
      urgency: _urgency,
      latitude: _latitude,
      longitude: _longitude,
      ward: _ward,
    );
  }
}

class _CategoryTile extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  const _CategoryTile({
    required this.label, required this.icon, required this.color,
    required this.selected, required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: selected ? color.withOpacity(0.15) : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(12),
          border: selected ? Border.all(color: color, width: 2) : null,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: selected ? color : Colors.grey, size: 28),
            const SizedBox(height: 4),
            Text(label, style: TextStyle(
              fontSize: 10, color: selected ? color : Colors.grey.shade700,
              fontWeight: selected ? FontWeight.bold : FontWeight.normal,
            ), textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}

class _UrgencyChip extends StatelessWidget {
  final String label;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  const _UrgencyChip({required this.label, required this.color, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: selected ? color : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Center(
          child: Text(label, style: TextStyle(
            color: selected ? Colors.white : Colors.grey.shade700,
            fontWeight: selected ? FontWeight.bold : FontWeight.normal,
            fontSize: 13,
          )),
        ),
      ),
    );
  }
}
