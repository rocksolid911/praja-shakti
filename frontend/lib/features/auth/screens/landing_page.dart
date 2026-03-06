import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../core/cubit/locale_cubit.dart';
import '../../../l10n/app_localizations.dart';
import '../cubit/auth_cubit.dart';
import '../cubit/auth_state.dart';

// ─── Theme constants ───────────────────────────────────────────────────────────
const _primary = Color(0xFF1565C0);
const _saffron = Color(0xFFFF9933);
const _green = Color(0xFF138808);
const _textPrimary = Color(0xFF1A1A2E);
const _textSecondary = Color(0xFF6B7280);

class LandingPage extends StatelessWidget {
  const LandingPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AuthCubit, AuthState>(
      builder: (context, authState) {
        // Show splash while checking auth OR while waiting for GoRouter redirect
        // (BlocBuilder fires before GoRouter redirect, so we must cover all non-initial states)
        if (authState is! AuthInitial) {
          return const Scaffold(
            backgroundColor: Color(0xFF1A237E),
            body: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.how_to_vote_rounded, size: 64, color: Colors.white),
                  SizedBox(height: 16),
                  Text('PrajaShakti', style: TextStyle(
                    fontSize: 28, fontWeight: FontWeight.w800,
                    color: Colors.white, letterSpacing: 0.5,
                  )),
                  SizedBox(height: 24),
                  SizedBox(
                    width: 24, height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5, color: Colors.white70,
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        // Show the actual landing page for unauthenticated users
        return Scaffold(
          backgroundColor: Colors.white,
          body: CustomScrollView(
            slivers: [
              _LandingNavBar(onGetStarted: () => context.go('/login')),
              SliverToBoxAdapter(child: _HeroSection(onGetStarted: () => context.go('/login'))),
              const SliverToBoxAdapter(child: _FeaturesSection()),
              const SliverToBoxAdapter(child: _HowItWorksSection()),
              const SliverToBoxAdapter(child: _StatsSection()),
              const SliverToBoxAdapter(child: _PanchayatSection()),
              SliverToBoxAdapter(child: _FooterSection(onGetStarted: () => context.go('/login'))),
            ],
          ),
        );
      },
    );
  }
}

// ─── Navbar ───────────────────────────────────────────────────────────────────
class _LandingNavBar extends StatelessWidget {
  final VoidCallback onGetStarted;
  const _LandingNavBar({required this.onGetStarted});

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width >= 768;
    final l10n = AppLocalizations.of(context)!;
    return SliverAppBar(
      pinned: true,
      floating: true,
      backgroundColor: Colors.white.withOpacity(0.95),
      surfaceTintColor: Colors.transparent,
      elevation: 1,
      shadowColor: Colors.black12,
      toolbarHeight: 64,
      titleSpacing: 0,
      title: Padding(
        padding: EdgeInsets.symmetric(horizontal: isDesktop ? 48 : 20),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: _green,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.account_balance, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 10),
            const Text(
              'PrajaShakti',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: _textPrimary),
            ),
            const Spacer(),
            if (isDesktop) ...[
              _navItem(l10n.landingNavFeatures),
              _navItem(l10n.landingNavHowItWorks),
              _navItem(l10n.landingNavImpact),
              _navItem(l10n.landingNavGramPanchayat),
              const SizedBox(width: 16),
            ],
            const _NavLanguagePicker(),
            const SizedBox(width: 12),
            ElevatedButton(
              onPressed: onGetStarted,
              style: ElevatedButton.styleFrom(
                backgroundColor: _primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                elevation: 0,
              ),
              child: Text(l10n.landingOpenApp,
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _navItem(String label) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14),
        child: Text(label,
            style: const TextStyle(color: _textSecondary, fontSize: 14, fontWeight: FontWeight.w500)),
      );
}

// ─── Hero Section ─────────────────────────────────────────────────────────────
class _HeroSection extends StatelessWidget {
  final VoidCallback onGetStarted;
  const _HeroSection({required this.onGetStarted});

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width >= 900;
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF0D1B2A),
            _primary.withOpacity(0.95),
            _green.withOpacity(0.85),
          ],
          stops: const [0.0, 0.55, 1.0],
        ),
      ),
      child: Stack(
        children: [
          Positioned(
              top: -80,
              right: -80,
              child: _glowCircle(320, _saffron.withOpacity(0.06))),
          Positioned(
              bottom: -60,
              left: -60,
              child: _glowCircle(260, _primary.withOpacity(0.1))),
          Padding(
            padding: EdgeInsets.fromLTRB(
              isDesktop ? 80 : 24,
              isDesktop ? 100 : 60,
              isDesktop ? 80 : 24,
              isDesktop ? 80 : 50,
            ),
            child: isDesktop
                ? Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(flex: 5, child: _heroContent(context)),
                      const SizedBox(width: 60),
                      Expanded(flex: 4, child: _heroCard(context)),
                    ],
                  )
                : Column(
                    children: [
                      _heroContent(context),
                      const SizedBox(height: 40),
                      _heroCard(context),
                    ],
                  ),
          ),
          Positioned(
            bottom: 0, left: 0, right: 0,
            child: _VillageSilhouette(),
          ),
        ],
      ),
    );
  }

  Widget _glowCircle(double size, Color color) =>
      Container(width: size, height: size, decoration: BoxDecoration(shape: BoxShape.circle, color: color));

  Widget _heroContent(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            border: Border.all(color: _saffron.withOpacity(0.5)),
            borderRadius: BorderRadius.circular(20),
            color: _saffron.withOpacity(0.1),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.star, color: _saffron, size: 14),
              const SizedBox(width: 6),
              Text(l10n.landingHeroBadge,
                  style: const TextStyle(color: _saffron, fontSize: 12, fontWeight: FontWeight.w600)),
            ],
          ),
        ),
        const SizedBox(height: 24),
        Text(
          l10n.landingHeroTitle,
          style: const TextStyle(
              color: Colors.white, fontSize: 44, fontWeight: FontWeight.bold, height: 1.2),
        ),
        const SizedBox(height: 16),
        Text(
          l10n.landingHeroSubtitle,
          style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 17, height: 1.6),
        ),
        const SizedBox(height: 32),
        Wrap(
          spacing: 20,
          runSpacing: 10,
          children: [
            _badge(Icons.shield_outlined, l10n.landingBadgeGovt, _green),
            _badge(Icons.psychology_outlined, l10n.landingBadgeAi, _saffron),
            _badge(Icons.people_outline, l10n.landingBadgePanchayats, _primary),
          ],
        ),
        const SizedBox(height: 40),
        Wrap(
          spacing: 16,
          runSpacing: 12,
          children: [
            ElevatedButton.icon(
              onPressed: onGetStarted,
              icon: const Icon(Icons.arrow_forward, size: 18),
              label: Text(l10n.landingGetStarted,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: _saffron,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                elevation: 0,
              ),
            ),
            OutlinedButton.icon(
              onPressed: onGetStarted,
              icon: const Icon(Icons.play_circle_outline, size: 18),
              label: Text(l10n.landingWatchDemo, style: const TextStyle(fontSize: 16)),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white,
                side: const BorderSide(color: Colors.white54),
                padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _badge(IconData icon, String label, Color color) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          const SizedBox(width: 8),
          Icon(icon, color: Colors.white70, size: 16),
          const SizedBox(width: 6),
          Text(label, style: const TextStyle(color: Colors.white70, fontSize: 13)),
        ],
      );

  Widget _heroCard(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.15)),
        boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 30, spreadRadius: 5)],
      ),
      child: Column(
        children: [
          // Map preview
          Container(
            height: 200,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withOpacity(0.1)),
            ),
            child: Stack(
              children: [
                Positioned.fill(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: CustomPaint(painter: _MapGridPainter()),
                  ),
                ),
                // Markers
                ...[
                  const Offset(0.25, 0.40),
                  const Offset(0.55, 0.25),
                  const Offset(0.45, 0.60),
                  const Offset(0.72, 0.70),
                  const Offset(0.15, 0.65),
                ].map((p) => Positioned(
                      left: p.dx * 260,
                      top: p.dy * 200,
                      child: const Icon(Icons.location_on, color: Colors.red, size: 22),
                    )),
                Positioned(
                  top: 10,
                  left: 10,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.red.shade700,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.circle, color: Colors.white, size: 7),
                        const SizedBox(width: 4),
                        Text(l10n.landingLive,
                            style: const TextStyle(
                                color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                ),
                const Positioned(
                  top: 10,
                  right: 10,
                  child: SizedBox(
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: Color(0x1AFFFFFF),
                          borderRadius: BorderRadius.all(Radius.circular(8)),
                        ),
                        child: Padding(
                          padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          child: Text('59 Reports',
                              style: TextStyle(color: Colors.white70, fontSize: 11)),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          // Active issue card
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withOpacity(0.12)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.water_drop, color: Colors.red, size: 20),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Broken Hand Pump, Ward 3',
                          style: TextStyle(
                              color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13)),
                      SizedBox(height: 3),
                      Text('47 upvotes · AI Priority: Critical',
                          style: TextStyle(color: Colors.white54, fontSize: 11)),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.amber.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.amber.withOpacity(0.4)),
                  ),
                  child: Text(l10n.adopted,
                      style: const TextStyle(
                          color: Colors.amber, fontSize: 11, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          // Mini stats
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _miniStat('94/100', 'AI Score'),
              Container(width: 1, height: 30, color: Colors.white.withOpacity(0.2)),
              _miniStat('Rs.4.5L', 'Funded'),
              Container(width: 1, height: 30, color: Colors.white.withOpacity(0.2)),
              _miniStat('60%', 'PM-KUSUM'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _miniStat(String val, String lbl) => Column(
        children: [
          Text(val,
              style: const TextStyle(
                  color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
          Text(lbl, style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 11)),
        ],
      );
}

// ─── Features Section ─────────────────────────────────────────────────────────
class _FeaturesSection extends StatelessWidget {
  const _FeaturesSection();

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width >= 768;
    final l10n = AppLocalizations.of(context)!;
    final items = [
      (Icons.camera_alt_outlined, l10n.featurePhotoReportingTitle, l10n.featurePhotoReportingDesc, const Color(0xFF1565C0)),
      (Icons.map_outlined, l10n.featureLiveTrackingTitle, l10n.featureLiveTrackingDesc, const Color(0xFF138808)),
      (Icons.thumb_up_alt_outlined, l10n.featureCommunityUpvotesTitle, l10n.featureCommunityUpvotesDesc, const Color(0xFFFF9933)),
      (Icons.wifi_off, l10n.featureOfflineSupportTitle, l10n.featureOfflineSupportDesc, const Color(0xFF7B1FA2)),
      (Icons.translate, l10n.featureMultiLanguageTitle, l10n.featureMultiLanguageDesc, const Color(0xFFE91E63)),
      (Icons.notifications_outlined, l10n.featureWhatsappAlertsTitle, l10n.featureWhatsappAlertsDesc, const Color(0xFF00838F)),
    ];
    return Container(
      color: const Color(0xFFF8F9FA),
      padding: EdgeInsets.symmetric(horizontal: isDesktop ? 80 : 24, vertical: 80),
      child: Column(
        children: [
          _SectionLabel(label: l10n.landingFeaturesLabel, title: l10n.landingFeaturesTitle),
          const SizedBox(height: 56),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: isDesktop ? 3 : 1,
              crossAxisSpacing: 20,
              mainAxisSpacing: 20,
              childAspectRatio: isDesktop ? 1.4 : 3.8,
            ),
            itemCount: items.length,
            itemBuilder: (_, i) => _FeatureCard(
              icon: items[i].$1,
              title: items[i].$2,
              subtitle: items[i].$3,
              color: items[i].$4,
            ),
          ),
        ],
      ),
    );
  }
}

class _FeatureCard extends StatefulWidget {
  final IconData icon;
  final String title, subtitle;
  final Color color;
  const _FeatureCard(
      {required this.icon, required this.title, required this.subtitle, required this.color});

  @override
  State<_FeatureCard> createState() => _FeatureCardState();
}

class _FeatureCardState extends State<_FeatureCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
              color: _hovered ? widget.color.withOpacity(0.35) : Colors.grey.shade200),
          boxShadow: _hovered
              ? [BoxShadow(color: widget.color.withOpacity(0.12), blurRadius: 20, spreadRadius: 2)]
              : [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10)],
        ),
        child: Row(
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: widget.color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(widget.icon, color: widget.color, size: 26),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(widget.title,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 15, color: _textPrimary)),
                  const SizedBox(height: 5),
                  Text(widget.subtitle,
                      style: const TextStyle(
                          color: _textSecondary, fontSize: 13, height: 1.4)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── How It Works ─────────────────────────────────────────────────────────────
class _HowItWorksSection extends StatelessWidget {
  const _HowItWorksSection();

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width >= 900;
    final l10n = AppLocalizations.of(context)!;
    final steps = [
      (Icons.mic_none, '1', l10n.stepReportTitle, l10n.stepReportSubtitle,
          l10n.stepReportDesc, const Color(0xFF1565C0)),
      (Icons.account_balance_outlined, '2', l10n.stepRouteTitle, l10n.stepRouteSubtitle,
          l10n.stepRouteDesc, const Color(0xFF138808)),
      (Icons.check_circle_outline, '3', l10n.stepResolveTitle, l10n.stepResolveSubtitle,
          l10n.stepResolveDesc, const Color(0xFFFF9933)),
    ];

    return Container(
      color: Colors.white,
      padding: EdgeInsets.symmetric(horizontal: isDesktop ? 80 : 24, vertical: 80),
      child: Column(
        children: [
          _SectionLabel(label: l10n.landingProcessLabel, title: l10n.landingProcessTitle),
          const SizedBox(height: 56),
          if (isDesktop)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: steps
                  .map((s) => Expanded(
                        child: _StepCard(
                          icon: s.$1,
                          number: s.$2,
                          title: s.$3,
                          subtitle: s.$4,
                          description: s.$5,
                          color: s.$6,
                          showArrow: s.$2 != '3',
                        ),
                      ))
                  .toList(),
            )
          else
            Column(
              children: steps
                  .map((s) => Padding(
                        padding: const EdgeInsets.only(bottom: 28),
                        child: _StepCard(
                          icon: s.$1,
                          number: s.$2,
                          title: s.$3,
                          subtitle: s.$4,
                          description: s.$5,
                          color: s.$6,
                        ),
                      ))
                  .toList(),
            ),
        ],
      ),
    );
  }
}

class _StepCard extends StatelessWidget {
  final IconData icon;
  final String number, title, subtitle, description;
  final Color color;
  final bool showArrow;
  const _StepCard({
    required this.icon,
    required this.number,
    required this.title,
    required this.subtitle,
    required this.description,
    required this.color,
    this.showArrow = false,
  });

  @override
  Widget build(BuildContext context) {
    final card = Column(
      children: [
        Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                  color: color.withOpacity(0.12), shape: BoxShape.circle),
              child: Icon(icon, color: color, size: 36),
            ),
            Positioned(
              right: -4,
              top: -4,
              child: Container(
                width: 26,
                height: 26,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                child: Center(
                  child: Text(number,
                      style: const TextStyle(
                          color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        Text(title,
            style: const TextStyle(
                fontWeight: FontWeight.bold, fontSize: 18, color: _textPrimary),
            textAlign: TextAlign.center),
        const SizedBox(height: 6),
        Text(subtitle,
            style: TextStyle(
                color: color, fontSize: 13, fontStyle: FontStyle.italic),
            textAlign: TextAlign.center),
        const SizedBox(height: 12),
        Text(description,
            style: const TextStyle(color: _textSecondary, fontSize: 14, height: 1.6),
            textAlign: TextAlign.center),
      ],
    );

    if (!showArrow) return card;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: card),
        Padding(
          padding: const EdgeInsets.only(top: 38),
          child: Icon(Icons.arrow_forward, color: Colors.grey.shade300, size: 28),
        ),
      ],
    );
  }
}

// ─── Stats Section ─────────────────────────────────────────────────────────────
class _StatsSection extends StatelessWidget {
  const _StatsSection();

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width >= 768;
    final l10n = AppLocalizations.of(context)!;
    final stats = [
      ('5,200+', l10n.statVillagesConnected, Icons.location_city_outlined),
      ('1,84,000+', l10n.statGrievancesFiled, Icons.assignment_outlined),
      ('89%', l10n.statIssuesResolved, Icons.check_circle_outline),
      ('14 Days', l10n.statAvgResolution, Icons.schedule),
    ];
    return Container(
      width: double.infinity,
      color: _primary,
      padding: EdgeInsets.symmetric(horizontal: isDesktop ? 80 : 24, vertical: 64),
      child: Column(
        children: [
          Text(l10n.statsTitle,
              style: const TextStyle(
                  color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text(l10n.statsSubtitle,
              style: TextStyle(
                  color: Colors.white.withOpacity(0.65),
                  fontSize: 16,
                  fontStyle: FontStyle.italic)),
          const SizedBox(height: 48),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: isDesktop ? 4 : 2,
              crossAxisSpacing: 20,
              mainAxisSpacing: 20,
              childAspectRatio: 1.3,
            ),
            itemCount: stats.length,
            itemBuilder: (_, i) => Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white.withOpacity(0.15)),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(stats[i].$3, color: _saffron, size: 32),
                  const SizedBox(height: 12),
                  Text(stats[i].$1,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 28,
                          fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  Text(stats[i].$2,
                      style: TextStyle(
                          color: Colors.white.withOpacity(0.75), fontSize: 13),
                      textAlign: TextAlign.center),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Panchayat Benefits ───────────────────────────────────────────────────────
class _PanchayatSection extends StatelessWidget {
  const _PanchayatSection();

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width >= 768;
    final l10n = AppLocalizations.of(context)!;
    final benefits = [
      (Icons.account_balance_outlined, l10n.benefitDigitalGramTitle, l10n.benefitDigitalGramDesc,
          const Color(0xFF1565C0)),
      (Icons.verified_outlined, l10n.benefitGovtPartnershipTitle, l10n.benefitGovtPartnershipDesc,
          const Color(0xFF138808)),
      (Icons.bar_chart, l10n.benefitDataDrivenTitle, l10n.benefitDataDrivenDesc,
          const Color(0xFFFF9933)),
      (Icons.groups_outlined, l10n.benefitGramSabhaTitle, l10n.benefitGramSabhaDesc,
          const Color(0xFF7B1FA2)),
    ];
    return Container(
      color: const Color(0xFFF0F4FF),
      padding: EdgeInsets.symmetric(horizontal: isDesktop ? 80 : 24, vertical: 80),
      child: Column(
        children: [
          _SectionLabel(
              label: l10n.landingPanchayatLabel, title: l10n.landingPanchayatTitle),
          const SizedBox(height: 56),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: isDesktop ? 2 : 1,
              crossAxisSpacing: 20,
              mainAxisSpacing: 20,
              childAspectRatio: isDesktop ? 2.8 : 4.0,
            ),
            itemCount: benefits.length,
            itemBuilder: (_, i) => Container(
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey.shade200),
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10)
                ],
              ),
              child: Row(
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: benefits[i].$4.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(benefits[i].$1, color: benefits[i].$4, size: 28),
                  ),
                  const SizedBox(width: 20),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(benefits[i].$2,
                            style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                color: _textPrimary)),
                        const SizedBox(height: 6),
                        Text(benefits[i].$3,
                            style: const TextStyle(
                                color: _textSecondary, fontSize: 13, height: 1.5)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Footer ───────────────────────────────────────────────────────────────────
class _FooterSection extends StatelessWidget {
  final VoidCallback onGetStarted;
  const _FooterSection({required this.onGetStarted});

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width >= 768;
    final l10n = AppLocalizations.of(context)!;
    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: EdgeInsets.symmetric(
              horizontal: isDesktop ? 80 : 24, vertical: 80),
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF0D1B2A), Color(0xFF1565C0)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Column(
            children: [
              Text(l10n.footerEyebrow,
                  style: const TextStyle(
                      color: _saffron,
                      fontSize: 15,
                      fontWeight: FontWeight.w600)),
              const SizedBox(height: 12),
              Text(l10n.footerTitle,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 36,
                      fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center),
              const SizedBox(height: 16),
              Text(
                l10n.footerSubtitle,
                style: TextStyle(
                    color: Colors.white.withOpacity(0.72),
                    fontSize: 16,
                    height: 1.6),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 40),
              Wrap(
                spacing: 16,
                runSpacing: 12,
                alignment: WrapAlignment.center,
                children: [
                  ElevatedButton.icon(
                    onPressed: onGetStarted,
                    icon: const Icon(Icons.rocket_launch, size: 18),
                    label: Text(l10n.footerOpenAppNow,
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _saffron,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 32, vertical: 16),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                      elevation: 0,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 14),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.white30),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.phone_outlined, color: Colors.white70, size: 18),
                        SizedBox(width: 8),
                        Text('Missed Call: 1800-XXX-XXXX',
                            style: TextStyle(color: Colors.white70, fontSize: 14)),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        Container(
          color: const Color(0xFF0A1628),
          padding:
              EdgeInsets.symmetric(horizontal: isDesktop ? 80 : 24, vertical: 24),
          child: Row(
            children: [
              const Icon(Icons.account_balance, color: Colors.white38, size: 18),
              const SizedBox(width: 8),
              const Text('PrajaShakti AI',
                  style: TextStyle(color: Colors.white38, fontSize: 14)),
              const Spacer(),
              Text(l10n.footerCopyright,
                  style: const TextStyle(color: Colors.white38, fontSize: 12)),
            ],
          ),
        ),
      ],
    );
  }
}

// ─── Shared Widgets ───────────────────────────────────────────────────────────
class _SectionLabel extends StatelessWidget {
  final String label, title;
  const _SectionLabel({required this.label, required this.title});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            color: _primary.withOpacity(0.08),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: _primary.withOpacity(0.2)),
          ),
          child: Text(label,
              style: const TextStyle(
                  color: _primary, fontSize: 13, fontWeight: FontWeight.w600)),
        ),
        const SizedBox(height: 16),
        Text(title,
            style: const TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: _textPrimary,
                height: 1.3),
            textAlign: TextAlign.center),
      ],
    );
  }
}

class _VillageSilhouette extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 56,
      child: CustomPaint(
        painter: _SilhouettePainter(),
        child: const SizedBox.expand(),
      ),
    );
  }
}

class _SilhouettePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.white.withOpacity(0.05);
    final path = Path()
      ..moveTo(0, size.height)
      ..lineTo(size.width * 0.04, size.height)
      ..lineTo(size.width * 0.04, size.height * 0.55)
      ..lineTo(size.width * 0.07, size.height * 0.15)
      ..lineTo(size.width * 0.10, size.height * 0.55)
      ..lineTo(size.width * 0.10, size.height)
      ..lineTo(size.width * 0.20, size.height)
      ..lineTo(size.width * 0.20, size.height * 0.38)
      ..lineTo(size.width * 0.225, size.height * 0.05)
      ..lineTo(size.width * 0.25, size.height * 0.38)
      ..lineTo(size.width * 0.25, size.height)
      ..lineTo(size.width * 0.45, size.height)
      ..lineTo(size.width * 0.45, size.height * 0.5)
      ..lineTo(size.width * 0.48, size.height * 0.25)
      ..lineTo(size.width * 0.51, size.height * 0.5)
      ..lineTo(size.width * 0.51, size.height)
      ..lineTo(size.width * 0.70, size.height)
      ..lineTo(size.width * 0.70, size.height * 0.42)
      ..lineTo(size.width * 0.73, size.height * 0.1)
      ..lineTo(size.width * 0.76, size.height * 0.42)
      ..lineTo(size.width * 0.76, size.height)
      ..lineTo(size.width, size.height)
      ..close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter _) => false;
}

// ─── Navbar Language Picker ───────────────────────────────────────────────────
class _NavLanguagePicker extends StatelessWidget {
  const _NavLanguagePicker();

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
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(current.$3, style: const TextStyle(fontSize: 15)),
                const SizedBox(width: 5),
                Text(
                  current.$1.toUpperCase(),
                  style: const TextStyle(
                      color: _textPrimary,
                      fontSize: 12,
                      fontWeight: FontWeight.bold),
                ),
                const SizedBox(width: 3),
                Icon(Icons.expand_more, color: Colors.grey.shade600, size: 15),
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
            builder: (ctx, locale) {
              final l10n = AppLocalizations.of(ctx)!;
              return Column(
                children: [
                  const SizedBox(height: 12),
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(2)),
                  ),
                  const SizedBox(height: 16),
                  Text(l10n.selectLanguage,
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text(l10n.choosePreferredLanguage,
                      style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
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
                            width: 40,
                            height: 40,
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
                                  fontSize: 12, color: Colors.grey.shade500)),
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
              );
            },
          ),
        ),
      ),
    );
  }
}

class _MapGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.07)
      ..strokeWidth = 1;
    for (double x = 0; x < size.width; x += 28) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y < size.height; y += 28) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter _) => false;
}
