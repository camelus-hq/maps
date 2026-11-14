import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../domain/entities/transit.dart';
import '../../../state/navigation.dart';
import '../../../state/settings.dart';
import '../nav_style.dart';
import 'nav_widgets.dart';
import 'transit_nav_banner.dart';

/// The public-transport guidance chrome: an indigo instruction card while the
/// same itinerary is followed on the shared map (the ETA and the live timeline
/// live in the shared [TransitNavBottomSheet]).
///
/// When the session carries the journey, the card is the transit-aware
/// [TransitNavBanner] (immediate action + line punctuality); otherwise it falls
/// back to the shared [NavBanner] (a journey started without an itinerary).
class TransitNavigationView extends ConsumerWidget {
  const TransitNavigationView({super.key, required this.nav});

  final NavState nav;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bool imperial = ref.watch(imperialUnitsProvider);
    final NavStyle style = NavStyle.forMode(nav.mode);
    final TransitItinerary? itinerary = nav.transit;
    final TransitProgress? progress = nav.transitProgress;
    final Widget banner = itinerary != null && progress != null
        ? TransitNavBanner(
            nav: nav,
            itinerary: itinerary,
            progress: progress,
            style: style,
            imperial: imperial,
          )
        : NavBanner(nav: nav, style: style, imperial: imperial);
    return Positioned(
      top: AppSpacing.sm,
      left: AppSpacing.sm,
      right: AppSpacing.sm,
      child: banner,
    );
  }
}
