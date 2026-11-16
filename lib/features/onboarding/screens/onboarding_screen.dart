import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../state/ports.dart';
import '../../../state/settings.dart';
import '../../design/play.dart';

/// First-run onboarding: a short location rationale shown once, then the map.
class OnboardingScreen extends ConsumerWidget {
  const OnboardingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final PlayColors colors = PlayColors.of(context);
    return PlayScaffold(
      child: Padding(
        padding: const EdgeInsets.all(PlaySpace.xl),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Icon(PlayIcons.brand, size: 72, color: colors.primary),
            const SizedBox(height: PlaySpace.xl),
            Text(
              'Welcome to OpenMaps',
              textAlign: TextAlign.center,
              style: PlayType.headline.copyWith(color: colors.ink),
            ),
            const SizedBox(height: PlaySpace.md),
            Text(
              'See your area on the map, search for places and get '
              'turn-by-turn directions.',
              textAlign: TextAlign.center,
              style: PlayType.body.copyWith(color: colors.ink),
            ),
            const SizedBox(height: PlaySpace.sm),
            Text(
              'Your location stays on your device.',
              textAlign: TextAlign.center,
              style: PlayType.caption.copyWith(color: colors.inkMuted),
            ),
            const SizedBox(height: PlaySpace.xxl),
            PlayButton(
              label: 'Allow location & continue',
              icon: PlayIcons.locate,
              size: PlayButtonSize.lg,
              expand: true,
              onPressed: () => unawaited(_finish(ref, requestLocation: true)),
            ),
            const SizedBox(height: PlaySpace.sm),
            PlayButton(
              label: 'Not now',
              variant: PlayButtonVariant.ghost,
              expand: true,
              onPressed: () => unawaited(_finish(ref, requestLocation: false)),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _finish(WidgetRef ref, {required bool requestLocation}) async {
    await ref.read(setOnboardingSeenProvider)(true);
    if (requestLocation) {
      // Prompts for permission; the service degrades to "no fix" if refused.
      unawaited(ref.read(locationServiceProvider).lastKnown());
    }
  }
}
