import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import '../cubit/report_cubit.dart';
import '../cubit/report_state.dart';
import '../../../core/api/api_client.dart';

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
    ('water', 'पानी', Icons.water_drop, Colors.blue),
    ('road', 'सड़क', Icons.add_road, Colors.orange),
    ('health', 'स्वास्थ्य', Icons.local_hospital, Colors.red),
    ('education', 'शिक्षा', Icons.school, Colors.purple),
    ('electricity', 'बिजली', Icons.bolt, Colors.yellow),
    ('sanitation', 'स्वच्छता', Icons.wc, Colors.teal),
    ('other', 'अन्य', Icons.more_horiz, Colors.grey),
  ];

  static const _urgencies = [
    ('low', 'कम', Colors.green),
    ('medium', 'मध्यम', Colors.orange),
    ('high', 'अधिक', Colors.deepOrange),
    ('critical', 'गंभीर', Colors.red),
  ];

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
              content: Text('रिपोर्ट सबमिट हुई! ID: WTR-${state.report.id}'),
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
          title: const Text('समस्या रिपोर्ट करें'),
          backgroundColor: Colors.green.shade700,
          foregroundColor: Colors.white,
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Category selection
              const Text('समस्या का प्रकार', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 12),
              GridView.count(
                crossAxisCount: 4,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
                childAspectRatio: 0.9,
                children: _categories.map((cat) => _CategoryTile(
                  label: cat.$2, icon: cat.$3, color: cat.$4,
                  selected: _category == cat.$1,
                  onTap: () => setState(() => _category = cat.$1),
                )).toList(),
              ),
              const SizedBox(height: 20),
              // Description
              const Text('विवरण', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 8),
              TextField(
                controller: _descController,
                maxLines: 4,
                decoration: InputDecoration(
                  hintText: 'समस्या के बारे में विस्तार से लिखें...',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  filled: true,
                  fillColor: Colors.grey.shade50,
                ),
              ),
              const SizedBox(height: 20),
              // Urgency
              const Text('गंभीरता', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 8),
              Row(
                children: _urgencies.map((u) => Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: _UrgencyChip(
                      label: u.$2, color: u.$3,
                      selected: _urgency == u.$1,
                      onTap: () => setState(() => _urgency = u.$1),
                    ),
                  ),
                )).toList(),
              ),
              const SizedBox(height: 20),
              // Ward number
              const Text('वार्ड नंबर (वैकल्पिक)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 8),
              TextField(
                keyboardType: TextInputType.number,
                onChanged: (v) => _ward = int.tryParse(v),
                decoration: InputDecoration(
                  hintText: 'जैसे: 3',
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
                            ? 'स्थान मिला: ${_latitude?.toStringAsFixed(4)}, ${_longitude?.toStringAsFixed(4)}'
                            : 'स्थान नहीं मिला — रिपोर्ट बिना GPS के भी जमा होगी',
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
                  return SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton.icon(
                      onPressed: loading ? null : _submit,
                      icon: loading
                          ? const SizedBox(width: 20, height: 20,
                              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                          : const Icon(Icons.send),
                      label: const Text('रिपोर्ट जमा करें', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
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
          ),
        ),
      ),
    );
  }

  void _submit() {
    if (_descController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('कृपया विवरण लिखें'), backgroundColor: Colors.orange),
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
