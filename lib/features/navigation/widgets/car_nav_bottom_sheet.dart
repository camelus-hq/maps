import 'package:material_ui/material_ui.dart';

import '../../../state/navigation.dart';
import 'nav_sheet.dart';

/// The car navigation sheet: the ETA header collapsed, the trip options when
/// expanded. This is the reference layout the other modes adapt.
class CarNavBottomSheet extends StatelessWidget {
  const CarNavBottomSheet({
    super.key,
    required this.nav,
    required this.tracking,
    required this.onExit,
    required this.onToggleOverview,
  });

  final NavState nav;
  final bool tracking;
  final VoidCallback onExit;
  final VoidCallback onToggleOverview;

  @override
  Widget build(BuildContext context) {
    return NavSheet(
      nav: nav,
      tracking: tracking,
      onExit: onExit,
      onToggleOverview: onToggleOverview,
    );
  }
}
