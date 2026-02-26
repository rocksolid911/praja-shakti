import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

const double kMobileBreakpoint = 600;
const double kTabletBreakpoint = 1024;

extension ResponsiveContext on BuildContext {
  double get screenWidth => MediaQuery.sizeOf(this).width;
  bool get isMobile => screenWidth < kMobileBreakpoint;
  bool get isTablet => screenWidth >= kMobileBreakpoint && screenWidth < kTabletBreakpoint;
  bool get isDesktop => screenWidth >= kTabletBreakpoint;
  bool get isWide => screenWidth >= kMobileBreakpoint;

  int get gridColumnCount {
    if (isDesktop) return 3;
    if (isTablet) return 2;
    return 1;
  }

  EdgeInsets get responsivePadding {
    if (isDesktop) return const EdgeInsets.symmetric(horizontal: 32, vertical: 16);
    if (isTablet) return const EdgeInsets.symmetric(horizontal: 20, vertical: 12);
    return const EdgeInsets.all(12);
  }
}

/// Builds different layouts depending on screen width breakpoints.
class ResponsiveLayout extends StatelessWidget {
  final Widget mobile;
  final Widget? tablet;
  final Widget desktop;

  const ResponsiveLayout({
    super.key,
    required this.mobile,
    this.tablet,
    required this.desktop,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (_, constraints) {
        if (constraints.maxWidth >= kTabletBreakpoint) return desktop;
        if (constraints.maxWidth >= kMobileBreakpoint) return tablet ?? desktop;
        return mobile;
      },
    );
  }
}

/// Returns platform-appropriate icons (Cupertino on iOS, Material elsewhere).
class AdaptiveIcons {
  AdaptiveIcons._();

  static bool _isIOS(BuildContext context) =>
      !kIsWeb && Theme.of(context).platform == TargetPlatform.iOS;

  static IconData share(BuildContext context) =>
      _isIOS(context) ? CupertinoIcons.share : Icons.share;

  static IconData back(BuildContext context) =>
      _isIOS(context) ? CupertinoIcons.back : Icons.arrow_back;

  static IconData more(BuildContext context) =>
      _isIOS(context) ? CupertinoIcons.ellipsis_vertical : Icons.more_vert;

  static IconData search(BuildContext context) =>
      _isIOS(context) ? CupertinoIcons.search : Icons.search;

  static IconData person(BuildContext context) =>
      _isIOS(context) ? CupertinoIcons.person : Icons.person;
}
