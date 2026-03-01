import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import '../cubit/report_cubit.dart';
import '../cubit/report_state.dart';
import '../../../core/api/api_client.dart';
import '../../../l10n/app_localizations.dart';
import '../../auth/cubit/auth_cubit.dart';

class ReportScreen extends StatelessWidget {
  const ReportScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final authCubit = context.read<AuthCubit>();
    final user = authCubit.currentUser;
    return BlocProvider(
      create: (_) {
        final cubit = ReportCubit(context.read<ApiClient>());
        // Pre-fill location from user profile if they have a village set
        if (user?.panchayatId != null && user!.villageId != null) {
          cubit.loadUserLocation(user.villageId!);
        } else {
          cubit.loadStates();
        }
        return cubit;
      },
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
  double? _latitude, _longitude;

  // Resolved village + ward selection (from cascade)
  int? _selectedVillageId;
  VillageDetails? _villageDetails;
  int _selectedWard = 1;

  static const _categories = [
    ('water', Icons.water_drop, Colors.blue),
    ('road', Icons.add_road, Colors.orange),
    ('health', Icons.local_hospital, Colors.red),
    ('education', Icons.school, Colors.purple),
    ('electricity', Icons.bolt, Colors.amber),
    ('sanitation', Icons.wc, Colors.teal),
    ('other', Icons.more_horiz, Colors.grey),
  ];

  static const _urgencies = [
    ('low', Colors.green),
    ('medium', Colors.orange),
    ('high', Colors.deepOrange),
    ('critical', Colors.red),
  ];

  @override
  void initState() {
    super.initState();
    _fetchGps();
  }

  @override
  void dispose() {
    _descController.dispose();
    super.dispose();
  }

  Future<void> _fetchGps() async {
    try {
      final perm = await Geolocator.requestPermission();
      if (perm == LocationPermission.denied ||
          perm == LocationPermission.deniedForever) {
        return;
      }
      final pos = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.medium);
      if (mounted) {
        setState(() {
          _latitude = pos.latitude;
          _longitude = pos.longitude;
        });
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<ReportCubit, ReportState>(
      listener: (context, state) {
        if (state is ReportSubmitted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                  AppLocalizations.of(context).reportSubmitted(state.report.id)),
              backgroundColor: Colors.green,
            ),
          );
          context.go('/feed');
        } else if (state is ReportError) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text(state.message), backgroundColor: Colors.red),
          );
        } else if (state is LocationVillageSelected) {
          setState(() {
            _selectedVillageId = state.details.villageId;
            _villageDetails = state.details;
            _selectedWard = 1;
          });
          // Refresh auth profile so other screens (Map, Dashboard, Feed)
          // automatically switch to the newly selected village's data.
          context.read<AuthCubit>().checkAuth();
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
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── 1. Location Section ───────────────────────────────
              _sectionHeader('📍 Location'),
              const SizedBox(height: 12),
              const _LocationCascade(),

              // Village details card (shown after selection)
              if (_villageDetails != null) ...[
                const SizedBox(height: 12),
                _VillageDetailsCard(details: _villageDetails!),
              ],

              const SizedBox(height: 24),

              // ── 2. Ward ────────────────────────────────────────────
              _sectionHeader(AppLocalizations.of(context).wardNumberOptional),
              const SizedBox(height: 8),
              _WardDropdown(
                wardCount: _villageDetails?.wardCount ?? 15,
                selectedWard: _selectedWard,
                onChanged: (w) => setState(() => _selectedWard = w),
              ),

              const SizedBox(height: 24),

              // ── 3. Category ────────────────────────────────────────
              _sectionHeader(AppLocalizations.of(context).issueType),
              const SizedBox(height: 12),
              GridView.count(
                crossAxisCount: 4,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
                childAspectRatio: 0.9,
                children: _categories
                    .map((cat) => _CategoryTile(
                          label: _categoryLabel(
                              AppLocalizations.of(context), cat.$1),
                          icon: cat.$2,
                          color: cat.$3,
                          selected: _category == cat.$1,
                          onTap: () => setState(() => _category = cat.$1),
                        ))
                    .toList(),
              ),

              const SizedBox(height: 20),

              // ── 4. Description ─────────────────────────────────────
              _sectionHeader(AppLocalizations.of(context).description),
              const SizedBox(height: 8),
              TextField(
                controller: _descController,
                maxLines: 4,
                decoration: InputDecoration(
                  hintText:
                      '${AppLocalizations.of(context).description}...',
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12)),
                  filled: true,
                  fillColor: Colors.grey.shade50,
                ),
              ),

              const SizedBox(height: 20),

              // ── 5. Urgency ─────────────────────────────────────────
              _sectionHeader(AppLocalizations.of(context).urgencyLabel),
              const SizedBox(height: 8),
              Row(
                children: _urgencies
                    .map((u) => Expanded(
                          child: Padding(
                            padding: const EdgeInsets.only(right: 6),
                            child: _UrgencyChip(
                              label: _urgencyLabel(
                                  AppLocalizations.of(context), u.$1),
                              color: u.$2,
                              selected: _urgency == u.$1,
                              onTap: () =>
                                  setState(() => _urgency = u.$1),
                            ),
                          ),
                        ))
                    .toList(),
              ),

              const SizedBox(height: 16),

              // GPS confirmation chip
              if (_latitude != null && _longitude != null)
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.green.shade200),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.gps_fixed,
                          color: Colors.green.shade700, size: 16),
                      const SizedBox(width: 6),
                      Text(
                        'GPS: ${_latitude!.toStringAsFixed(4)}, '
                        '${_longitude!.toStringAsFixed(4)}',
                        style: TextStyle(
                            color: Colors.green.shade800, fontSize: 12),
                      ),
                    ],
                  ),
                ),

              const SizedBox(height: 28),

              // ── 6. Submit ──────────────────────────────────────────
              BlocBuilder<ReportCubit, ReportState>(
                builder: (context, state) {
                  final loading = state is ReportSubmitting;
                  return SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton.icon(
                      onPressed: loading ? null : _submit,
                      icon: loading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                  color: Colors.white, strokeWidth: 2))
                          : const Icon(Icons.send),
                      label: Text(
                          AppLocalizations.of(context).submitReport,
                          style: const TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green.shade700,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
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

  Widget _sectionHeader(String text) => Text(
        text,
        style:
            const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
      );

  static String _categoryLabel(AppLocalizations l10n, String key) =>
      switch (key) {
        'water' => l10n.water,
        'road' => l10n.road,
        'health' => l10n.health,
        'education' => l10n.education,
        'electricity' => l10n.electricity,
        'sanitation' => l10n.sanitation,
        _ => l10n.other,
      };

  static String _urgencyLabel(AppLocalizations l10n, String key) =>
      switch (key) {
        'low' => l10n.urgencyLow,
        'medium' => l10n.urgencyMedium,
        'high' => l10n.urgencyHigh,
        'critical' => l10n.urgencyCritical,
        _ => key,
      };

  void _submit() {
    final l10n = AppLocalizations.of(context);
    if (_descController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(l10n.enterDescription),
            backgroundColor: Colors.orange),
      );
      return;
    }

    final villageId = _selectedVillageId ??
        context.read<AuthCubit>().currentVillageId;

    if (villageId <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Please select your village first'),
            backgroundColor: Colors.orange),
      );
      return;
    }

    context.read<ReportCubit>().submitTextReport(
          villageId: villageId,
          description: _descController.text.trim(),
          category: _category,
          urgency: _urgency,
          latitude: _latitude,
          longitude: _longitude,
          ward: _selectedWard,
        );
  }
}

// ── Location Cascade Widget ────────────────────────────────────────────
// Hierarchy: State → District → Gram Panchayat → Village

class _LocationCascade extends StatelessWidget {
  const _LocationCascade();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ReportCubit, ReportState>(
      builder: (context, state) {
        // When no GPs exist for the district → show manual entry form
        if (state is LocationNoPanchayatsFound || state is LocationSettingUp) {
          final isSettingUp = state is LocationSettingUp;
          // Extract shared fields via explicit type cast
          final List<GeoOption> allStates;
          final GeoOption selSt;
          final List<GeoOption> allDistricts;
          final GeoOption selDist;
          if (state is LocationNoPanchayatsFound) {
            allStates = state.states;
            selSt = state.selectedState;
            allDistricts = state.districts;
            selDist = state.selectedDistrict;
          } else {
            final s = state as LocationSettingUp;
            allStates = s.states;
            selSt = s.selectedState;
            allDistricts = s.districts;
            selDist = s.selectedDistrict;
          }
          return Column(
            children: [
              _DropdownRow(
                label: 'State', icon: Icons.map_outlined,
                hint: 'State', value: selSt.name,
                items: allStates.map((e) => e.name).toList(),
                enabled: true, loading: false,
                onChanged: (name) {
                  final st = allStates.firstWhere((x) => x.name == name);
                  context.read<ReportCubit>().selectState(st, allStates);
                },
              ),
              const SizedBox(height: 10),
              _DropdownRow(
                label: 'District', icon: Icons.location_city_outlined,
                hint: 'District', value: selDist.name,
                items: allDistricts.map((e) => e.name).toList(),
                enabled: true, loading: false,
                onChanged: (name) {
                  final d = allDistricts.firstWhere((x) => x.name == name);
                  context.read<ReportCubit>().selectDistrict(
                      d, allStates, selSt, allDistricts);
                },
              ),
              const SizedBox(height: 10),
              _ManualLocationEntry(
                selectedDistrict: selDist,
                allStates: allStates,
                selectedState: selSt,
                allDistricts: allDistricts,
                isLoading: isSettingUp,
              ),
            ],
          );
        }

        final cd = _extractCascadeData(state);
        final states = cd.$1;
        final selState = cd.$2;
        final districts = cd.$3;
        final selDistrict = cd.$4;
        final panchayats = cd.$5;
        final selPanchayat = cd.$6;
        final villages = cd.$7;
        final selVillage = cd.$8;

        final loadingStates = state is LocationStatesLoading;
        final loadingDistricts = state is LocationDistrictsLoading;
        final loadingPanchayats = state is LocationPanchayatsLoading;
        final loadingVillages = state is LocationVillagesLoading;

        return Column(
          children: [
            // 1. State
            _DropdownRow(
              label: 'State',
              icon: Icons.map_outlined,
              hint: loadingStates ? 'Loading states...' : 'Select state',
              value: selState?.name,
              items: states?.map((s) => s.name).toList() ?? [],
              enabled: !loadingStates && states != null,
              loading: loadingStates,
              onChanged: (name) {
                final s = states!.firstWhere((x) => x.name == name);
                context.read<ReportCubit>().selectState(s, states);
              },
            ),
            const SizedBox(height: 10),

            // 2. District
            _DropdownRow(
              label: 'District',
              icon: Icons.location_city_outlined,
              hint: loadingDistricts
                  ? 'Loading districts...'
                  : selState == null
                      ? 'Select state first'
                      : 'Select district',
              value: selDistrict?.name,
              items: districts?.map((d) => d.name).toList() ?? [],
              enabled: !loadingDistricts &&
                  districts != null &&
                  districts.isNotEmpty,
              loading: loadingDistricts,
              onChanged: (name) {
                final d = districts!.firstWhere((x) => x.name == name);
                context.read<ReportCubit>().selectDistrict(
                    d, states!, selState!, districts);
              },
            ),
            const SizedBox(height: 10),

            // 3. Gram Panchayat
            _DropdownRow(
              label: 'Gram Panchayat',
              icon: Icons.account_balance_outlined,
              hint: loadingPanchayats
                  ? 'Loading panchayats...'
                  : selDistrict == null
                      ? 'Select district first'
                      : 'Select Gram Panchayat',
              value: selPanchayat?.name,
              items: panchayats?.map((p) => p.name).toList() ?? [],
              enabled: !loadingPanchayats &&
                  panchayats != null &&
                  panchayats.isNotEmpty,
              loading: loadingPanchayats,
              onChanged: (name) {
                final p = panchayats!.firstWhere((x) => x.name == name);
                context.read<ReportCubit>().selectPanchayat(
                    p, states!, selState!, districts!, selDistrict!,
                    panchayats);
              },
            ),
            const SizedBox(height: 10),

            // 4. Village
            _DropdownRow(
              label: 'Village',
              icon: Icons.cottage_outlined,
              hint: loadingVillages
                  ? 'Loading villages...'
                  : selPanchayat == null
                      ? 'Select GP first'
                      : villages != null && villages.isEmpty
                          ? 'No villages in this GP'
                          : 'Select village',
              value: selVillage?.name,
              items: villages?.map((v) => v.name).toList() ?? [],
              enabled: !loadingVillages &&
                  villages != null &&
                  villages.isNotEmpty,
              loading: loadingVillages,
              onChanged: (name) {
                final v = villages!.firstWhere((x) => x.name == name);
                context.read<ReportCubit>().selectVillage(
                    v,
                    states!,
                    selState!,
                    districts!,
                    selDistrict!,
                    panchayats!,
                    selPanchayat!,
                    villages);
              },
            ),
          ],
        );
      },
    );
  }

  /// Extract all 8 cascade data fields from whichever BLoC state is active.
  (
    List<GeoOption>?,   // states
    GeoOption?,         // selectedState
    List<GeoOption>?,   // districts
    GeoOption?,         // selectedDistrict
    List<GeoOption>?,   // panchayats
    GeoOption?,         // selectedPanchayat
    List<GeoOption>?,   // villages
    GeoOption?,         // selectedVillage
  ) _extractCascadeData(ReportState state) {
    if (state is LocationStatesLoaded) {
      return (state.states, null, null, null, null, null, null, null);
    }
    if (state is LocationDistrictsLoading) {
      return (state.states, state.selectedState, null, null, null, null, null, null);
    }
    if (state is LocationDistrictsLoaded) {
      return (state.states, state.selectedState, state.districts,
          null, null, null, null, null);
    }
    if (state is LocationPanchayatsLoading) {
      return (state.states, state.selectedState, state.districts,
          state.selectedDistrict, null, null, null, null);
    }
    if (state is LocationPanchayatsLoaded) {
      return (state.states, state.selectedState, state.districts,
          state.selectedDistrict, state.panchayats, null, null, null);
    }
    if (state is LocationVillagesLoading) {
      return (state.states, state.selectedState, state.districts,
          state.selectedDistrict, state.panchayats, state.selectedPanchayat,
          null, null);
    }
    if (state is LocationVillagesLoaded) {
      return (state.states, state.selectedState, state.districts,
          state.selectedDistrict, state.panchayats, state.selectedPanchayat,
          state.villages, null);
    }
    if (state is LocationVillageSelected) {
      return (state.states, state.selectedState, state.districts,
          state.selectedDistrict, state.panchayats, state.selectedPanchayat,
          state.villages, state.selectedVillage);
    }
    return (null, null, null, null, null, null, null, null);
  }
}

// ── Manual Location Entry (for districts with no pre-loaded GPs) ────────

class _ManualLocationEntry extends StatefulWidget {
  final GeoOption selectedDistrict;
  final List<GeoOption> allStates;
  final GeoOption selectedState;
  final List<GeoOption> allDistricts;
  final bool isLoading;

  const _ManualLocationEntry({
    required this.selectedDistrict,
    required this.allStates,
    required this.selectedState,
    required this.allDistricts,
    required this.isLoading,
  });

  @override
  State<_ManualLocationEntry> createState() => _ManualLocationEntryState();
}

class _ManualLocationEntryState extends State<_ManualLocationEntry> {
  final _gpController = TextEditingController();
  final _villageController = TextEditingController();

  @override
  void dispose() {
    _gpController.dispose();
    _villageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.orange.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orange.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.edit_location_alt, color: Colors.orange.shade700, size: 18),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Enter location for ${widget.selectedDistrict.name}',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: Colors.orange.shade800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'No pre-loaded data for this district. Type your Gram Panchayat and village name.',
            style: TextStyle(fontSize: 11, color: Colors.orange.shade700),
          ),
          const SizedBox(height: 12),
          _textField(
            controller: _gpController,
            icon: Icons.account_balance_outlined,
            hint: 'Gram Panchayat name (e.g., Gomti GP)',
          ),
          const SizedBox(height: 8),
          _textField(
            controller: _villageController,
            icon: Icons.cottage_outlined,
            hint: 'Village name (e.g., Rampur)',
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: widget.isLoading ? null : _submit,
              icon: widget.isLoading
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.check, size: 16),
              label: Text(widget.isLoading ? 'Setting up...' : 'Confirm Location'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange.shade700,
                foregroundColor: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _textField({
    required TextEditingController controller,
    required IconData icon,
    required String hint,
  }) {
    return TextField(
      controller: controller,
      decoration: InputDecoration(
        prefixIcon: Icon(icon, size: 18, color: Colors.orange.shade700),
        hintText: hint,
        hintStyle: const TextStyle(fontSize: 13),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        filled: true,
        fillColor: Colors.white,
      ),
    );
  }

  void _submit() {
    final gp = _gpController.text.trim();
    final village = _villageController.text.trim();
    if (gp.isEmpty || village.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter both Gram Panchayat and Village name'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }
    context.read<ReportCubit>().setupNewLocation(
      districtId: widget.selectedDistrict.id,
      panchayatName: gp,
      villageName: village,
      allStates: widget.allStates,
      selectedState: widget.selectedState,
      allDistricts: widget.allDistricts,
      selectedDistrict: widget.selectedDistrict,
    );
  }
}

class _DropdownRow extends StatelessWidget {
  final String label;
  final IconData icon;
  final String hint;
  final String? value;
  final List<String> items;
  final bool enabled;
  final bool loading;
  final ValueChanged<String> onChanged;

  const _DropdownRow({
    required this.label,
    required this.icon,
    required this.hint,
    required this.value,
    required this.items,
    required this.enabled,
    required this.loading,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      decoration: BoxDecoration(
        color: enabled ? Colors.white : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: value != null
              ? Colors.green.shade400
              : Colors.grey.shade300,
          width: value != null ? 1.5 : 1,
        ),
      ),
      child: Row(
        children: [
          Icon(icon,
              color: enabled
                  ? Colors.green.shade700
                  : Colors.grey.shade400,
              size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: loading
                ? Row(
                    children: [
                      const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2)),
                      const SizedBox(width: 8),
                      Text(hint,
                          style: TextStyle(
                              color: Colors.grey.shade500, fontSize: 14)),
                    ],
                  )
                : DropdownButton<String>(
                    value: value,
                    hint: Text(hint,
                        style: TextStyle(
                            color: Colors.grey.shade500, fontSize: 14)),
                    isExpanded: true,
                    underline: const SizedBox.shrink(),
                    icon: Icon(Icons.keyboard_arrow_down,
                        color: enabled
                            ? Colors.green.shade700
                            : Colors.grey.shade400),
                    onChanged: enabled
                        ? (v) {
                            if (v != null) onChanged(v);
                          }
                        : null,
                    items: items
                        .map((item) => DropdownMenuItem(
                              value: item,
                              child:
                                  Text(item, style: const TextStyle(fontSize: 14)),
                            ))
                        .toList(),
                  ),
          ),
        ],
      ),
    );
  }
}

// ── Ward Dropdown ──────────────────────────────────────────────────────

class _WardDropdown extends StatelessWidget {
  final int wardCount;
  final int selectedWard;
  final ValueChanged<int> onChanged;

  const _WardDropdown({
    required this.wardCount,
    required this.selectedWard,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final wards = List.generate(wardCount, (i) => i + 1);
    final safeSelected =
        wards.contains(selectedWard) ? selectedWard : wards.first;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.green.shade400, width: 1.5),
      ),
      child: Row(
        children: [
          Icon(Icons.format_list_numbered,
              color: Colors.green.shade700, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: DropdownButton<int>(
              value: safeSelected,
              isExpanded: true,
              underline: const SizedBox.shrink(),
              icon: Icon(Icons.keyboard_arrow_down,
                  color: Colors.green.shade700),
              onChanged: (v) {
                if (v != null) onChanged(v);
              },
              items: wards
                  .map((w) => DropdownMenuItem(
                        value: w,
                        child: Text('Ward $w',
                            style: const TextStyle(fontSize: 14)),
                      ))
                  .toList(),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Village Details Card ───────────────────────────────────────────────

class _VillageDetailsCard extends StatelessWidget {
  final VillageDetails details;
  const _VillageDetailsCard({required this.details});

  @override
  Widget build(BuildContext context) {
    final fund = details.fundAvailableInr;
    final fundStr = fund > 0
        ? '₹${(fund / 100000).toStringAsFixed(1)}L'
        : details.provisioning
            ? 'Loading...'
            : 'N/A';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.green.shade50, Colors.teal.shade50],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.green.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.check_circle, color: Colors.green.shade600, size: 18),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  '${details.villageName}, ${details.districtName}, ${details.stateName}',
                  style: TextStyle(
                      color: Colors.green.shade800,
                      fontWeight: FontWeight.bold,
                      fontSize: 14),
                ),
              ),
              if (details.provisioning)
                Tooltip(
                  message: 'Fetching live government data...',
                  child: SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.green.shade600),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              _InfoChip(
                icon: Icons.account_balance_wallet_outlined,
                label: 'Fund: $fundStr',
                color: Colors.green,
              ),
              if (details.population != null)
                _InfoChip(
                  icon: Icons.people_outline,
                  label: 'Pop: ${_fmt(details.population!)}',
                  color: Colors.blue,
                ),
              if (details.ndviScore != null)
                _InfoChip(
                  icon: Icons.eco_outlined,
                  label: 'NDVI: ${details.ndviScore!.toStringAsFixed(2)}',
                  color: details.ndviScore! < 0.3
                      ? Colors.deepOrange
                      : Colors.green,
                ),
              if (details.groundwaterDepthM != null)
                _InfoChip(
                  icon: Icons.water_outlined,
                  label: 'GW: ${details.groundwaterDepthM!.toStringAsFixed(1)}m',
                  color: details.groundwaterDepthM! > 10
                      ? Colors.deepOrange
                      : Colors.blue,
                ),
            ],
          ),
          if (details.provisioning) ...[
            const SizedBox(height: 8),
            Text(
              'Fetching schemes & fund data for ${details.districtName}...',
              style: TextStyle(
                  color: Colors.green.shade600,
                  fontSize: 11,
                  fontStyle: FontStyle.italic),
            ),
          ],
        ],
      ),
    );
  }

  static String _fmt(int n) {
    if (n >= 100000) return '${(n / 100000).toStringAsFixed(1)}L';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(0)}K';
    return n.toString();
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  const _InfoChip(
      {required this.icon, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(label,
              style: TextStyle(
                  fontSize: 11,
                  color: color.withOpacity(0.9),
                  fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}

// ── Category / Urgency Tiles ───────────────────────────────────────────

class _CategoryTile extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  const _CategoryTile({
    required this.label,
    required this.icon,
    required this.color,
    required this.selected,
    required this.onTap,
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
            Text(label,
                style: TextStyle(
                  fontSize: 10,
                  color: selected ? color : Colors.grey.shade700,
                  fontWeight:
                      selected ? FontWeight.bold : FontWeight.normal,
                ),
                textAlign: TextAlign.center),
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

  const _UrgencyChip(
      {required this.label,
      required this.color,
      required this.selected,
      required this.onTap});

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
          child: Text(label,
              style: TextStyle(
                color: selected ? Colors.white : Colors.grey.shade700,
                fontWeight:
                    selected ? FontWeight.bold : FontWeight.normal,
                fontSize: 13,
              )),
        ),
      ),
    );
  }
}
