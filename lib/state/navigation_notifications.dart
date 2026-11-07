import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/utils/format.dart';
import '../domain/entities/route.dart';
import '../domain/entities/travel_mode.dart';
import '../domain/ports/navigation_notifications.dart';
import 'navigation.dart';
import 'ports.dart';
import 'settings.dart';

/// What the running trip's notification currently shows (visible, the next
/// turn, remaining time/distance, trip progress and the status-bar chip's
/// upcoming-direction text). Hidden while guidance is idle or arrived.
class NavigationNotice {
  const NavigationNotice({
    this.visible = false,
    this.title = '',
    this.body = '',
    this.progress,
    this.statusChip,
    this.mode = TravelMode.drive,
  });

  final bool visible;
  final String title;
  final String body;

  /// Trip completion, 0–100 (Android progress bar); `null` when hidden.
  final int? progress;

  /// The Android 16 status-bar chip's short text — a glyph for the upcoming
  /// maneuver and the distance to it (e.g. "↰ 300 m"); `null` when hidden.
  final String? statusChip;

  /// The travel mode, which selects the notification / status-chip icon.
  final TravelMode mode;
}

/// Bridges turn-by-turn guidance to the OS notification.
///
/// Watches [navigationControllerProvider] and shows/updates/dismisses the
/// ongoing notice through the `NavigationNotifications` port, and turns the
/// notice's "Exit navigation" action into `NavigationController.stop()`. Kept
/// alive by the map home's `NavigationNotificationLayer`; [navigationNotice]
/// holds the current content so it is drivable/assertable (`nav.notification`).
class NavigationNoticeController extends Notifier<NavigationNotice> {
  StreamSubscription<void>? _exitSub;
  bool _permissionRequested = false;

  @override
  NavigationNotice build() {
    _exitSub = ref
        .read(navigationNotificationsProvider)
        .exitRequests
        .listen((_) => ref.read(navigationControllerProvider.notifier).stop());
    ref.onDispose(() => unawaited(_exitSub?.cancel()));

    ref.listen<NavState>(navigationControllerProvider, (
      NavState? previous,
      NavState next,
    ) {
      final NavigationNotice notice = _noticeFor(next);
      state = notice;
      unawaited(_apply(notice));
    });

    // Catch up when the layer mounts after guidance has already started (or is
    // already idle): sync the platform notice with the current state.
    final NavigationNotice notice = _noticeFor(
      ref.read(navigationControllerProvider),
    );
    unawaited(_apply(notice));
    return notice;
  }

  Future<void> _apply(NavigationNotice notice) async {
    final NavigationNotifications notifications = ref.read(
      navigationNotificationsProvider,
    );
    if (!notice.visible) {
      await notifications.dismiss();
      return;
    }
    if (!_permissionRequested) {
      _permissionRequested = true;
      unawaited(notifications.requestPermission());
    }
    // Showing the notice also keeps the process running (a location foreground
    // service on Android), so backgrounded position updates — and the notice's
    // status chip — keep coming.
    await notifications.show(
      title: notice.title,
      body: notice.body,
      progress: notice.progress,
      statusChip: notice.statusChip,
      mode: notice.mode,
    );
  }

  NavigationNotice _noticeFor(NavState nav) {
    if (nav.status == NavStatus.idle || nav.status == NavStatus.arrived) {
      return const NavigationNotice();
    }
    final bool imperial = ref.read(imperialUnitsProvider);
    final double total = nav.totalMeters;
    final double remaining = (total - nav.traveledMeters).clamp(
      0,
      double.infinity,
    );
    final int? progress = total > 0
        ? ((nav.traveledMeters / total) * 100).round().clamp(0, 100)
        : null;
    final Maneuver? maneuver = nav.nextManeuver;
    final String? instruction = maneuver?.instruction;
    final String title = switch (nav.status) {
      NavStatus.rerouting => 'Rerouting…',
      _ when instruction != null && instruction.isNotEmpty => instruction,
      _ => 'Navigating',
    };
    final String arrival = formatClockTime(DateTime.now().add(nav.remaining));
    final String body =
        '${formatDuration(nav.remaining)} · '
        '${formatDistance(remaining, imperial: imperial)} · '
        'Arrives $arrival';
    return NavigationNotice(
      visible: true,
      title: title,
      body: body,
      progress: progress,
      mode: nav.mode,
      statusChip: nav.status == NavStatus.rerouting
          ? '↻'
          : _statusChip(maneuver, nav.distanceToNextManeuver, imperial),
    );
  }

  /// The Android 16 status-bar chip text: a compact glyph for the upcoming
  /// maneuver plus the distance to it (the system shows only what fits).
  String? _statusChip(Maneuver? maneuver, double distance, bool imperial) {
    if (maneuver == null) {
      return null;
    }
    final String icon = switch (maneuver.type) {
      ManeuverType.depart => '●',
      ManeuverType.straight => '↑',
      ManeuverType.slightLeft => '↖',
      ManeuverType.turnLeft => '←',
      ManeuverType.sharpLeft => '↰',
      ManeuverType.uTurnLeft => '↶',
      ManeuverType.slightRight => '↗',
      ManeuverType.turnRight => '→',
      ManeuverType.sharpRight => '↱',
      ManeuverType.uTurnRight => '↷',
      ManeuverType.keepLeft => '⇦',
      ManeuverType.keepRight => '⇨',
      ManeuverType.rampLeft => '↙',
      ManeuverType.rampRight => '↘',
      ManeuverType.exitLeft => '⇙',
      ManeuverType.exitRight => '⇘',
      ManeuverType.merge => '⤒',
      ManeuverType.mergeLeft => '⤺',
      ManeuverType.mergeRight => '⤻',
      ManeuverType.roundabout => '⟳',
      ManeuverType.roundaboutExit => '⤴',
      ManeuverType.arrive => '⚑',
      ManeuverType.unknown => '?',
    };
    if (distance <= 0) {
      return icon;
    }
    return '$icon ${formatDistance(distance, imperial: imperial)}';
  }
}

final NotifierProvider<NavigationNoticeController, NavigationNotice>
navigationNoticeProvider =
    NotifierProvider<NavigationNoticeController, NavigationNotice>(
      NavigationNoticeController.new,
    );
