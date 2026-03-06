import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../cubit/auth_cubit.dart';
import '../cubit/auth_state.dart';
import '../../../core/api/api_client.dart';
import '../../../core/cubit/locale_cubit.dart';
import '../../../l10n/app_localizations.dart';

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
    final l10n = AppLocalizations.of(context);
    final isWide = MediaQuery.sizeOf(context).width >= 900;

    return BlocListener<AuthCubit, AuthState>(
      listener: (context, state) {
        if (state is AuthOtpSent) {
          context.go('/otp', extra: {
            'phone': state.phone,
          });
        } else if (state is AuthError) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(state.message), backgroundColor: Colors.red),
          );
        }
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFF5F7FA),
        body: SafeArea(
          child: isWide ? _buildWebLayout(l10n) : _buildMobileLayout(l10n),
        ),
      ),
    );
  }

  Widget _buildMobileLayout(AppLocalizations l10n) {
    return Center(
      child: SingleChildScrollView(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 420),
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.06),
                blurRadius: 20, offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 32),
              // Logo
              Container(
                width: 80, height: 80,
                decoration: BoxDecoration(
                  color: const Color(0xFFE8F5E9),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.agriculture_rounded, size: 42, color: Color(0xFF00C853)),
              ),
              const SizedBox(height: 16),
              const Text(
                'PrajaShakti AI',
                style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: Color(0xFF1A1A2E)),
              ),
              const SizedBox(height: 4),
              Text(
                'VOICE OF RURAL DEVELOPMENT',
                style: TextStyle(
                  fontSize: 12, fontWeight: FontWeight.w700,
                  color: const Color(0xFF00C853),
                  letterSpacing: 1.5,
                ),
              ),
              const SizedBox(height: 20),
              // Hero image
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 24),
                height: 160,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  image: const DecorationImage(
                    image: AssetImage('assets/images/village-hero.jpg'),
                    fit: BoxFit.cover,
                  ),
                ),
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    gradient: LinearGradient(
                      colors: [Colors.black.withValues(alpha: 0.5), Colors.transparent],
                      begin: Alignment.bottomCenter, end: Alignment.center,
                    ),
                  ),
                  alignment: Alignment.bottomCenter,
                  padding: const EdgeInsets.only(bottom: 12),
                  child: const Text('Smart Villages, Stronger India',
                      style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700, letterSpacing: 0.5)),
                ),
              ),
              const SizedBox(height: 20),
              // Tab bar
              _buildTabBar(l10n),
              // Tab content
              SizedBox(
                height: 400,
                child: TabBarView(
                  controller: _tabController,
                  children: const [
                    _LoginTab(),
                    _RegisterTab(),
                  ],
                ),
              ),
              // Language picker
              Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  border: Border(top: BorderSide(color: Colors.grey.shade200)),
                ),
                child: const _LanguageStrip(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWebLayout(AppLocalizations l10n) {
    return Column(
      children: [
        // Top nav
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
          color: Colors.white,
          child: Row(
            children: [
              Container(
                width: 36, height: 36,
                decoration: BoxDecoration(
                  color: const Color(0xFF1A237E),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.account_balance_rounded, color: Colors.white, size: 20),
              ),
              const SizedBox(width: 10),
              const Text('PrajaShakti AI',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16, color: Color(0xFF1A1A2E))),
              const Spacer(),
              const _LanguagePickerChip(),
            ],
          ),
        ),
        // Main content
        Expanded(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(40),
              child: Container(
                constraints: const BoxConstraints(maxWidth: 1000),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.06),
                      blurRadius: 24, offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    // Left: hero image panel
                    Expanded(
                      child: Container(
                        height: 600,
                        decoration: BoxDecoration(
                          borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(24),
                            bottomLeft: Radius.circular(24),
                          ),
                          image: const DecorationImage(
                            image: AssetImage('assets/images/village-hero.jpg'),
                            fit: BoxFit.cover,
                          ),
                        ),
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: const BorderRadius.only(
                              topLeft: Radius.circular(24),
                              bottomLeft: Radius.circular(24),
                            ),
                            gradient: LinearGradient(
                              colors: [
                                Colors.black.withValues(alpha: 0.65),
                                Colors.black.withValues(alpha: 0.1),
                              ],
                              begin: Alignment.bottomCenter,
                              end: Alignment.topCenter,
                            ),
                          ),
                          padding: const EdgeInsets.all(40),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.end,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Voice of Rural\nDevelopment',
                                style: TextStyle(
                                  color: Colors.white, fontSize: 32,
                                  fontWeight: FontWeight.w800, height: 1.2,
                                  shadows: [Shadow(blurRadius: 8, color: Colors.black54)],
                                ),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'Empowering rural communities through AI-driven insights and sustainable development initiatives for a better tomorrow.',
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.9),
                                  fontSize: 15, height: 1.5,
                                  shadows: [Shadow(blurRadius: 6, color: Colors.black54)],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    // Right: form
                    Expanded(
                      child: Container(
                        height: 600,
                        padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 40),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Welcome Back',
                              style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: Color(0xFF1A1A2E)),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Join the movement for smarter rural growth.',
                              style: TextStyle(fontSize: 15, color: Colors.grey.shade600),
                            ),
                            const SizedBox(height: 28),
                            _buildTabBar(l10n),
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
                  ],
                ),
              ),
            ),
          ),
        ),
        // Footer
        Container(
          padding: const EdgeInsets.all(16),
          child: Text(
            '\u00A9 2026 PrajaShakti AI. Empowering India\'s Heartland.',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
          ),
        ),
      ],
    );
  }

  Widget _buildTabBar(AppLocalizations l10n) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Container(
        height: 46,
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(12),
        ),
        child: TabBar(
          controller: _tabController,
          indicatorSize: TabBarIndicatorSize.tab,
          dividerColor: Colors.transparent,
          indicator: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.08),
                blurRadius: 4, offset: const Offset(0, 1),
              ),
            ],
          ),
          labelColor: const Color(0xFF1A1A2E),
          unselectedLabelColor: Colors.grey.shade500,
          labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
          unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14),
          tabs: [
            Tab(text: l10n.login),
            Tab(text: l10n.register),
          ],
        ),
      ),
    );
  }
}

// ── Language strip (horizontal row of language pills for mobile login) ────────

class _LanguageStrip extends StatelessWidget {
  const _LanguageStrip();

  static const _languages = [
    ('en', 'EN'),
    ('hi', 'हिं'),
    ('or', 'ଓ'),
    ('te', 'తె'),
    ('ta', 'த'),
    ('mr', 'मरा'),
    ('bn', 'বাং'),
    ('gu', 'ગુ'),
    ('kn', 'ಕ'),
    ('ml', 'മ'),
    ('pa', 'ਪ'),
  ];

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<LocaleCubit, Locale>(
      builder: (context, locale) {
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: _languages.map((lang) {
              final selected = locale.languageCode == lang.$1;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: GestureDetector(
                  onTap: () => context.read<LocaleCubit>().setLocale(Locale(lang.$1)),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                      color: selected ? const Color(0xFF1A237E) : Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: selected ? const Color(0xFF1A237E) : Colors.grey.shade300,
                      ),
                    ),
                    child: Text(
                      lang.$2,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                        color: selected ? Colors.white : Colors.grey.shade700,
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        );
      },
    );
  }
}

// ── Compact language picker for web layout ────────────────────────────────────

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
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
              color: const Color(0xFFF0F2F5),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(current.$3, style: const TextStyle(fontSize: 16)),
                const SizedBox(width: 6),
                Text(current.$1.toUpperCase(),
                    style: const TextStyle(
                        color: Color(0xFF1A1A2E),
                        fontSize: 12,
                        fontWeight: FontWeight.bold)),
                const SizedBox(width: 4),
                Icon(Icons.expand_more, color: Colors.grey.shade600, size: 16),
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
                BlocBuilder<LocaleCubit, Locale>(
                  builder: (ctx2, _) => Text(
                    AppLocalizations.of(ctx2).selectLanguage,
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(height: 4),
                BlocBuilder<LocaleCubit, Locale>(
                  builder: (ctx2, _) => Text(
                    AppLocalizations.of(ctx2).choosePreferredLanguage,
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                  ),
                ),
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
                                ? const Color(0xFFEDF2FF)
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
                                    ? const Color(0xFF1A237E)
                                    : Colors.black87)),
                        subtitle: Text(lang.$1.toUpperCase(),
                            style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade500)),
                        trailing: selected
                            ? const Icon(Icons.check_circle,
                                color: Color(0xFF3F51B5))
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
    final l10n = AppLocalizations.of(context);
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Code + Mobile Number side by side
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Country Code
                SizedBox(
                  width: 100,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Code', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.grey.shade700)),
                      const SizedBox(height: 6),
                      Container(
                        height: 52,
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey.shade300),
                        ),
                        alignment: Alignment.centerLeft,
                        child: const Text('+91', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                // Mobile Number
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Mobile Number', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.grey.shade700)),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _phoneController,
                        keyboardType: TextInputType.phone,
                        style: const TextStyle(fontSize: 16),
                        decoration: InputDecoration(
                          hintText: 'Enter 10 digit number',
                          hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
                          prefixIcon: Icon(Icons.smartphone_rounded, size: 20, color: Colors.grey.shade400),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: Colors.grey.shade300),
                          ),
                          filled: true,
                          fillColor: Colors.grey.shade50,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
                        ),
                        validator: (v) {
                          if (v == null || v.isEmpty) return l10n.mobileRequired;
                          final d = v.replaceAll(RegExp(r'\D'), '');
                          if (d.length < 10) return l10n.enterTenDigits;
                          return null;
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 22),
            // Send OTP button (green)
            BlocBuilder<AuthCubit, AuthState>(
              builder: (context, state) {
                final loading = state is AuthLoading;
                final l = AppLocalizations.of(context);
                return SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: ElevatedButton(
                    onPressed: loading ? null : _submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF00C853),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      elevation: 0,
                    ),
                    child: loading
                        ? const SizedBox(width: 22, height: 22,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                        : Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(l.sendOtp, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
                              const SizedBox(width: 8),
                              const Icon(Icons.arrow_forward_rounded, size: 20),
                            ],
                          ),
                  ),
                );
              },
            ),
            const SizedBox(height: 20),
            // OR divider
            Row(
              children: [
                Expanded(child: Divider(color: Colors.grey.shade300)),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text('OR', style: TextStyle(color: Colors.grey.shade400, fontSize: 12, fontWeight: FontWeight.w600)),
                ),
                Expanded(child: Divider(color: Colors.grey.shade300)),
              ],
            ),
            const SizedBox(height: 20),
            // Continue as Guest
            BlocBuilder<AuthCubit, AuthState>(
              builder: (context, state) {
                final loading = state is AuthLoading;
                return SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: OutlinedButton.icon(
                    onPressed: loading ? null : () {
                      context.read<AuthCubit>().signInAnonymously();
                    },
                    icon: Icon(Icons.group_outlined, size: 20, color: Colors.grey.shade700),
                    label: Text(l10n.continueAsGuest,
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Colors.grey.shade700)),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: Colors.grey.shade300),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      backgroundColor: Colors.grey.shade50,
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 16),
            // Terms text
            Center(
              child: Text.rich(
                TextSpan(
                  text: 'By continuing, you agree to our ',
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                  children: [
                    TextSpan(
                      text: 'Terms of Service',
                      style: TextStyle(color: const Color(0xFF00C853), fontWeight: FontWeight.w600),
                    ),
                    const TextSpan(text: ' and '),
                    TextSpan(
                      text: 'Privacy Policy',
                      style: TextStyle(color: const Color(0xFF00C853), fontWeight: FontWeight.w600),
                    ),
                    const TextSpan(text: '.'),
                  ],
                ),
                textAlign: TextAlign.center,
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
    final l10n = AppLocalizations.of(context);
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Name fields ──────────────────────────────────────────────
            _sectionLabel('${l10n.fullName} *'),
            Row(
              children: [
                Expanded(
                  child: _inputField(
                    controller: _firstNameCtrl,
                    hint: l10n.firstName,
                    icon: Icons.person_outline,
                    validator: (v) =>
                        (v == null || v.trim().isEmpty) ? l10n.required : null,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _inputField(
                    controller: _lastNameCtrl,
                    hint: l10n.lastName,
                    icon: Icons.person_outline,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // ── Phone ────────────────────────────────────────────────────
            _sectionLabel('${l10n.mobileNumberLabel} *'),
            _inputField(
              controller: _phoneCtrl,
              hint: '+91 98765 43210',
              icon: Icons.phone_outlined,
              keyboardType: TextInputType.phone,
              validator: (v) {
                if (v == null || v.isEmpty) return l10n.mobileRequired;
                final d = v.replaceAll(RegExp(r'\D'), '');
                if (d.length < 10) return l10n.enterTenDigits;
                return null;
              },
            ),
            const SizedBox(height: 14),

            // ── Location ─────────────────────────────────────────────────
            _sectionLabel('${l10n.yourLocation} *'),
            _buildLocationCascade(l10n),

            const SizedBox(height: 24),

            // ── Submit ───────────────────────────────────────────────────
            BlocBuilder<AuthCubit, AuthState>(
              builder: (context, state) {
                final loading = state is AuthLoading;
                final l = AppLocalizations.of(context);
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
                    label: Text(l.registerGetOtp,
                        style: const TextStyle(
                            fontSize: 15, fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF00C853),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
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

  Widget _buildLocationCascade(AppLocalizations l10n) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F7FA),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // State
          _cascadeDropdown(
            label: l10n.stateLabel,
            icon: Icons.map_outlined,
            value: _selState?.name,
            items: _states.map((s) => s.name).toList(),
            loading: _loadingStates,
            hint: l10n.selectItem(l10n.stateLabel),
            onChanged: (name) {
              final s = _states.firstWhere((e) => e.name == name);
              _onStateSelected(s);
            },
          ),
          if (_selState != null) ...[
            const SizedBox(height: 10),
            // District
            _cascadeDropdown(
              label: l10n.districtLabel,
              icon: Icons.location_city_outlined,
              value: _selDistrict?.name,
              items: _districts.map((d) => d.name).toList(),
              loading: _loadingDistricts,
              hint: l10n.selectItem(l10n.districtLabel),
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
              label: l10n.gramPanchayatLabel,
              icon: Icons.account_balance_outlined,
              value: _selPanchayat?.name,
              items: _panchayats.map((p) => p.name).toList(),
              loading: _loadingPanchayats,
              hint: l10n.selectItem(l10n.gramPanchayatLabel),
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
              label: l10n.villageLabel,
              icon: Icons.cottage_outlined,
              value: _selVillage?.name,
              items: _villages.map((v) => v.name).toList(),
              loading: _loadingVillages,
              hint: l10n.selectItem(l10n.villageLabel),
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
                          l10n.noDataForDistrict(_selDistrict!.name),
                          style: TextStyle(
                              fontSize: 11, color: Colors.orange.shade800),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  _inputField(
                    controller: _gpCtrl,
                    hint: l10n.gramPanchayatName,
                    icon: Icons.account_balance_outlined,
                    onChanged: (_) => setState(() {}),
                  ),
                  const SizedBox(height: 6),
                  _inputField(
                    controller: _villageManualCtrl,
                    hint: l10n.villageName,
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
    required String hint,
    required ValueChanged<String> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 14, color: const Color(0xFF3F51B5)),
            const SizedBox(width: 4),
            Text(label,
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF263238))),
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
                hint: Text(hint, style: const TextStyle(fontSize: 13)),
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
        SnackBar(content: Text(AppLocalizations.of(context).pleaseSelectLocation)),
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
