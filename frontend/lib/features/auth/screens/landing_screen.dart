import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../cubit/auth_cubit.dart';
import '../cubit/auth_state.dart';
import '../../../core/api/api_client.dart';
import '../../../core/cubit/locale_cubit.dart';

class LandingScreen extends StatefulWidget {
  const LandingScreen({super.key});

  @override
  State<LandingScreen> createState() => _LandingScreenState();
}

class _LandingScreenState extends State<LandingScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<AuthCubit, AuthState>(
      listener: (context, state) {
        if (state is AuthOtpSent) {
          context.go('/otp', extra: {
            'phone': state.phone,
            'otpDebug': state.otpDebug,
          });
        } else if (state is AuthError) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(state.message), backgroundColor: Colors.red),
          );
        }
      },
      child: Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
          child: Column(
            children: [
              // ── Hero ─────────────────────────────────────────────────────
              _HeroSection(),

              // ── Tab bar ──────────────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Container(
                  height: 44,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(22),
                  ),
                  child: TabBar(
                    controller: _tabController,
                    indicatorSize: TabBarIndicatorSize.tab,
                    dividerColor: Colors.transparent,
                    indicator: BoxDecoration(
                      color: Colors.green.shade700,
                      borderRadius: BorderRadius.circular(22),
                    ),
                    labelColor: Colors.white,
                    unselectedLabelColor: Colors.grey.shade600,
                    labelStyle: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 14),
                    tabs: const [
                      Tab(text: 'Login'),
                      Tab(text: 'Register'),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 4),

              // ── Tab content ───────────────────────────────────────────────
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: const [
                    _LoginTab(),
                    _RegisterTab(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Hero Section ─────────────────────────────────────────────────────────────

class _HeroSection extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(24, 32, 24, 20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Colors.green.shade800, Colors.green.shade600],
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(Icons.grass, size: 34, color: Colors.white),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'PrajaShakti AI',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.3,
                  ),
                ),
                Text(
                  'Voice of Rural Development',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.85),
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          const _LanguagePickerChip(),
        ],
      ),
    );
  }
}

// ── Compact language picker for login page ────────────────────────────────────

class _LanguagePickerChip extends StatelessWidget {
  const _LanguagePickerChip();

  static const _languages = [
    ('en', 'English', '🇬🇧'),
    ('hi', 'हिंदी', '🇮🇳'),
    ('or', 'ଓଡ଼ିଆ', '🇮🇳'),
    ('te', 'తెలుగు', '🇮🇳'),
    ('ta', 'தமிழ்', '🇮🇳'),
    ('mr', 'मराठी', '🇮🇳'),
    ('bn', 'বাংলা', '🇮🇳'),
    ('gu', 'ગુજરાતી', '🇮🇳'),
    ('kn', 'ಕನ್ನಡ', '🇮🇳'),
    ('ml', 'മലയാളം', '🇮🇳'),
    ('pa', 'ਪੰਜਾਬੀ', '🇮🇳'),
  ];

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<LocaleCubit, Locale>(
      builder: (context, locale) {
        final current = _languages.firstWhere(
          (l) => l.$1 == locale.languageCode,
          orElse: () => _languages.first,
        );
        return GestureDetector(
          onTap: () => _showPicker(context),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white.withOpacity(0.3)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(current.$3, style: const TextStyle(fontSize: 16)),
                const SizedBox(width: 6),
                Text(current.$1.toUpperCase(),
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold)),
                const SizedBox(width: 4),
                const Icon(Icons.expand_more, color: Colors.white, size: 16),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showPicker(BuildContext context) {
    final cubit = context.read<LocaleCubit>();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => BlocProvider.value(
        value: cubit,
        child: DraggableScrollableSheet(
          initialChildSize: 0.6,
          minChildSize: 0.4,
          maxChildSize: 0.85,
          expand: false,
          builder: (_, controller) => BlocBuilder<LocaleCubit, Locale>(
            builder: (ctx, locale) => Column(
              children: [
                const SizedBox(height: 12),
                Container(
                  width: 40, height: 4,
                  decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2)),
                ),
                const SizedBox(height: 16),
                const Text('Select Language',
                    style:
                        TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text('Choose your preferred language',
                    style: TextStyle(
                        color: Colors.grey.shade600, fontSize: 13)),
                const SizedBox(height: 12),
                const Divider(height: 1),
                Expanded(
                  child: ListView.builder(
                    controller: controller,
                    itemCount: _languages.length,
                    itemBuilder: (context, i) {
                      final lang = _languages[i];
                      final selected = locale.languageCode == lang.$1;
                      return ListTile(
                        leading: Container(
                          width: 40, height: 40,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: selected
                                ? Colors.green.shade100
                                : Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(lang.$3,
                              style: const TextStyle(fontSize: 22)),
                        ),
                        title: Text(lang.$2,
                            style: TextStyle(
                                fontWeight: selected
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                                color: selected
                                    ? Colors.green.shade800
                                    : Colors.black87)),
                        subtitle: Text(lang.$1.toUpperCase(),
                            style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade500)),
                        trailing: selected
                            ? Icon(Icons.check_circle,
                                color: Colors.green.shade700)
                            : null,
                        onTap: () {
                          ctx.read<LocaleCubit>().setLocale(Locale(lang.$1));
                          Navigator.pop(context);
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Login Tab ─────────────────────────────────────────────────────────────────

class _LoginTab extends StatefulWidget {
  const _LoginTab();

  @override
  State<_LoginTab> createState() => _LoginTabState();
}

class _LoginTabState extends State<_LoginTab> {
  final _phoneController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  String get _normalizedPhone {
    final digits = _phoneController.text.replaceAll(RegExp(r'\D'), '');
    return digits.length > 10 ? digits.substring(digits.length - 10) : digits;
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Enter your mobile number',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
            const SizedBox(height: 4),
            Text(
              'Login with OTP — no password needed',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              decoration: InputDecoration(
                hintText: '+91 98765 43210',
                prefixIcon: const Icon(Icons.phone_outlined),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12)),
                filled: true,
                fillColor: Colors.grey.shade50,
              ),
              validator: (v) {
                if (v == null || v.isEmpty) return 'Mobile number is required';
                final d = v.replaceAll(RegExp(r'\D'), '');
                if (d.length < 10) return 'Enter a 10-digit number';
                return null;
              },
            ),
            const SizedBox(height: 24),
            BlocBuilder<AuthCubit, AuthState>(
              builder: (context, state) {
                final loading = state is AuthLoading;
                return SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton.icon(
                    onPressed: loading ? null : _submit,
                    icon: loading
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                                color: Colors.white, strokeWidth: 2),
                          )
                        : const Icon(Icons.sms_outlined),
                    label: const Text('Send OTP',
                        style: TextStyle(
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
            Center(
              child: Text(
                'For registered citizens',
                style: TextStyle(color: Colors.grey.shade400, fontSize: 11),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _submit() {
    if (_formKey.currentState!.validate()) {
      context.read<AuthCubit>().sendOtp(_normalizedPhone);
    }
  }
}

// ── Register Tab ──────────────────────────────────────────────────────────────

class _RegisterTab extends StatefulWidget {
  const _RegisterTab();

  @override
  State<_RegisterTab> createState() => _RegisterTabState();
}

class _RegisterTabState extends State<_RegisterTab> {
  final _formKey = GlobalKey<FormState>();
  final _firstNameCtrl = TextEditingController();
  final _lastNameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();

  // ── Cascade state ──────────────────────────────────────────────────
  List<_GeoOpt> _states = [];
  List<_GeoOpt> _districts = [];
  List<_GeoOpt> _panchayats = [];
  List<_GeoOpt> _villages = [];

  _GeoOpt? _selState;
  _GeoOpt? _selDistrict;
  _GeoOpt? _selPanchayat;
  _GeoOpt? _selVillage;

  bool _loadingStates = false;
  bool _loadingDistricts = false;
  bool _loadingPanchayats = false;
  bool _loadingVillages = false;
  bool _noPanchayatsFound = false;

  // Manual entry when no pre-loaded GPs for district
  final _gpCtrl = TextEditingController();
  final _villageManualCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadStates();
  }

  @override
  void dispose() {
    _firstNameCtrl.dispose();
    _lastNameCtrl.dispose();
    _phoneCtrl.dispose();
    _gpCtrl.dispose();
    _villageManualCtrl.dispose();
    super.dispose();
  }

  ApiClient get _api => context.read<ApiClient>();

  Future<void> _loadStates() async {
    setState(() => _loadingStates = true);
    try {
      final resp = await _api.get('/states/');
      final list = (resp.data is List ? resp.data : resp.data['results'] ?? []) as List;
      setState(() {
        _states = list.map((s) => _GeoOpt(s['id'] as int, s['name'] as String)).toList();
        _loadingStates = false;
      });
    } catch (_) {
      setState(() => _loadingStates = false);
    }
  }

  Future<void> _onStateSelected(_GeoOpt state) async {
    setState(() {
      _selState = state;
      _selDistrict = null;
      _selPanchayat = null;
      _selVillage = null;
      _districts = [];
      _panchayats = [];
      _villages = [];
      _noPanchayatsFound = false;
      _loadingDistricts = true;
    });
    try {
      final resp = await _api.get('/districts/', queryParameters: {'state': state.id});
      final list = (resp.data is List ? resp.data : resp.data['results'] ?? []) as List;
      setState(() {
        _districts = list.map((d) => _GeoOpt(d['id'] as int, d['name'] as String)).toList();
        _loadingDistricts = false;
      });
    } catch (_) {
      setState(() => _loadingDistricts = false);
    }
  }

  Future<void> _onDistrictSelected(_GeoOpt district) async {
    setState(() {
      _selDistrict = district;
      _selPanchayat = null;
      _selVillage = null;
      _panchayats = [];
      _villages = [];
      _noPanchayatsFound = false;
      _loadingPanchayats = true;
    });
    try {
      final resp = await _api.get('/panchayats/', queryParameters: {'district': district.id});
      final list = (resp.data is List ? resp.data : resp.data['results'] ?? []) as List;
      setState(() {
        _panchayats = list.map((p) => _GeoOpt(p['id'] as int, p['name'] as String)).toList();
        _noPanchayatsFound = _panchayats.isEmpty;
        _loadingPanchayats = false;
      });
    } catch (_) {
      setState(() {
        _loadingPanchayats = false;
        _noPanchayatsFound = true;
      });
    }
  }

  Future<void> _onPanchayatSelected(_GeoOpt panchayat) async {
    setState(() {
      _selPanchayat = panchayat;
      _selVillage = null;
      _villages = [];
      _loadingVillages = true;
    });
    try {
      final resp = await _api.get('/villages/', queryParameters: {'panchayat': panchayat.id});
      final list = (resp.data is List ? resp.data : resp.data['results'] ?? []) as List;
      setState(() {
        _villages = list.map((v) => _GeoOpt(v['id'] as int, v['name'] as String)).toList();
        _loadingVillages = false;
      });
    } catch (_) {
      setState(() => _loadingVillages = false);
    }
  }

  bool get _locationComplete {
    if (_noPanchayatsFound) {
      return _gpCtrl.text.trim().isNotEmpty &&
          _villageManualCtrl.text.trim().isNotEmpty;
    }
    return _selVillage != null;
  }

  String get _normalizedPhone {
    final d = _phoneCtrl.text.replaceAll(RegExp(r'\D'), '');
    return d.length > 10 ? d.substring(d.length - 10) : d;
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Name fields ──────────────────────────────────────────────
            _sectionLabel('Full Name *'),
            Row(
              children: [
                Expanded(
                  child: _inputField(
                    controller: _firstNameCtrl,
                    hint: 'First name',
                    icon: Icons.person_outline,
                    validator: (v) =>
                        (v == null || v.trim().isEmpty) ? 'Required' : null,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _inputField(
                    controller: _lastNameCtrl,
                    hint: 'Last name',
                    icon: Icons.person_outline,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // ── Phone ────────────────────────────────────────────────────
            _sectionLabel('Mobile Number *'),
            _inputField(
              controller: _phoneCtrl,
              hint: '+91 98765 43210',
              icon: Icons.phone_outlined,
              keyboardType: TextInputType.phone,
              validator: (v) {
                if (v == null || v.isEmpty) return 'Mobile number is required';
                final d = v.replaceAll(RegExp(r'\D'), '');
                if (d.length < 10) return 'Enter a 10-digit number';
                return null;
              },
            ),
            const SizedBox(height: 14),

            // ── Location ─────────────────────────────────────────────────
            _sectionLabel('Your Location *'),
            _buildLocationCascade(),

            const SizedBox(height: 24),

            // ── Submit ───────────────────────────────────────────────────
            BlocBuilder<AuthCubit, AuthState>(
              builder: (context, state) {
                final loading = state is AuthLoading;
                return SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton.icon(
                    onPressed: (loading || !_locationComplete) ? null : _submit,
                    icon: loading
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                                color: Colors.white, strokeWidth: 2),
                          )
                        : const Icon(Icons.how_to_reg_outlined),
                    label: const Text('Register & Get OTP',
                        style: TextStyle(
                            fontSize: 15, fontWeight: FontWeight.bold)),
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
          ],
        ),
      ),
    );
  }

  Widget _buildLocationCascade() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.green.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.green.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // State
          _cascadeDropdown(
            label: 'State',
            icon: Icons.map_outlined,
            value: _selState?.name,
            items: _states.map((s) => s.name).toList(),
            loading: _loadingStates,
            onChanged: (name) {
              final s = _states.firstWhere((e) => e.name == name);
              _onStateSelected(s);
            },
          ),
          if (_selState != null) ...[
            const SizedBox(height: 10),
            // District
            _cascadeDropdown(
              label: 'District',
              icon: Icons.location_city_outlined,
              value: _selDistrict?.name,
              items: _districts.map((d) => d.name).toList(),
              loading: _loadingDistricts,
              onChanged: (name) {
                final d = _districts.firstWhere((e) => e.name == name);
                _onDistrictSelected(d);
              },
            ),
          ],
          if (_selDistrict != null && !_noPanchayatsFound) ...[
            const SizedBox(height: 10),
            // Gram Panchayat
            _cascadeDropdown(
              label: 'Gram Panchayat',
              icon: Icons.account_balance_outlined,
              value: _selPanchayat?.name,
              items: _panchayats.map((p) => p.name).toList(),
              loading: _loadingPanchayats,
              onChanged: (name) {
                final p = _panchayats.firstWhere((e) => e.name == name);
                _onPanchayatSelected(p);
              },
            ),
          ],
          if (_selPanchayat != null) ...[
            const SizedBox(height: 10),
            // Village
            _cascadeDropdown(
              label: 'Village',
              icon: Icons.cottage_outlined,
              value: _selVillage?.name,
              items: _villages.map((v) => v.name).toList(),
              loading: _loadingVillages,
              onChanged: (name) {
                final v = _villages.firstWhere((e) => e.name == name);
                setState(() => _selVillage = v);
              },
            ),
          ],
          // Manual entry when no panchayats found
          if (_noPanchayatsFound && _selDistrict != null) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange.shade300),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.edit_location_alt,
                          size: 14, color: Colors.orange.shade700),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'No data for ${_selDistrict!.name} — please enter names',
                          style: TextStyle(
                              fontSize: 11, color: Colors.orange.shade800),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  _inputField(
                    controller: _gpCtrl,
                    hint: 'Gram Panchayat name',
                    icon: Icons.account_balance_outlined,
                    onChanged: (_) => setState(() {}),
                  ),
                  const SizedBox(height: 6),
                  _inputField(
                    controller: _villageManualCtrl,
                    hint: 'Village name',
                    icon: Icons.cottage_outlined,
                    onChanged: (_) => setState(() {}),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _cascadeDropdown({
    required String label,
    required IconData icon,
    required String? value,
    required List<String> items,
    required bool loading,
    required ValueChanged<String> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 14, color: Colors.green.shade700),
            const SizedBox(width: 4),
            Text(label,
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.green.shade800)),
          ],
        ),
        const SizedBox(height: 4),
        loading
            ? const SizedBox(
                height: 36,
                child: Center(
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ))
            : DropdownButtonFormField<String>(
                value: value,
                hint: Text('Select $label',
                    style: const TextStyle(fontSize: 13)),
                isExpanded: true,
                decoration: InputDecoration(
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 8),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8)),
                  filled: true,
                  fillColor: Colors.white,
                  isDense: true,
                ),
                items: items
                    .map((name) => DropdownMenuItem(
                          value: name,
                          child: Text(name,
                              style: const TextStyle(fontSize: 13),
                              overflow: TextOverflow.ellipsis),
                        ))
                    .toList(),
                onChanged: items.isEmpty ? null : (v) => onChanged(v!),
              ),
      ],
    );
  }

  Widget _sectionLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(text,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
    );
  }

  Widget _inputField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    String? Function(String?)? validator,
    ValueChanged<String>? onChanged,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      onChanged: onChanged,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(fontSize: 13),
        prefixIcon: Icon(icon, size: 18),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        filled: true,
        fillColor: Colors.grey.shade50,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        isDense: true,
      ),
      validator: validator,
    );
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    if (!_locationComplete) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select your location')),
      );
      return;
    }

    final authCubit = context.read<AuthCubit>();

    if (_noPanchayatsFound) {
      // New location: district_id + manual GP + village names
      authCubit.startRegistration(
        phone: _normalizedPhone,
        firstName: _firstNameCtrl.text.trim(),
        lastName: _lastNameCtrl.text.trim(),
        districtId: _selDistrict!.id,
        panchayatName: _gpCtrl.text.trim(),
        villageName: _villageManualCtrl.text.trim(),
      );
    } else {
      // Existing village from dropdown
      authCubit.startRegistration(
        phone: _normalizedPhone,
        firstName: _firstNameCtrl.text.trim(),
        lastName: _lastNameCtrl.text.trim(),
        existingVillageId: _selVillage!.id,
      );
    }
  }
}

// ── Small helpers ─────────────────────────────────────────────────────────────

class _GeoOpt {
  final int id;
  final String name;
  const _GeoOpt(this.id, this.name);
}
