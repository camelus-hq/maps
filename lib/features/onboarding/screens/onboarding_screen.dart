import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/legal_links.dart';
import '../../../state/ports.dart';
import '../../../state/settings.dart';
import '../../design/play.dart';

/// First-run onboarding, in two steps: accept the terms of service and privacy
/// policy, then decide whether to share the device location.
///
/// The location permission is requested **only** when the user taps "Allow
/// location & continue" — nothing here reads the location at launch, so the OS
/// permission prompt waits for the user's choice.
class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

enum _OnboardingStep { terms, location }

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  _OnboardingStep _step = _OnboardingStep.terms;

  @override
  Widget build(BuildContext context) {
    final PlayColors colors = PlayColors.of(context);
    return PlayScaffold(
      child: Padding(
        padding: const EdgeInsets.all(PlaySpace.xl),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: switch (_step) {
            _OnboardingStep.terms => _terms(colors),
            _OnboardingStep.location => _location(colors),
          },
        ),
      ),
    );
  }

  /// Step 1: the terms of service and privacy policy must be accepted before
  /// the app is used.
  List<Widget> _terms(PlayColors colors) => <Widget>[
    Icon(PlayIcons.brand, size: 72, color: colors.primary),
    const SizedBox(height: PlaySpace.xl),
    Text(
      'Welcome to Camelus Maps',
      textAlign: TextAlign.center,
      style: PlayType.headline.copyWith(color: colors.ink),
    ),
    const SizedBox(height: PlaySpace.md),
    Text(
      'A private, open map for exploring the places around you.',
      textAlign: TextAlign.center,
      style: PlayType.body.copyWith(color: colors.ink),
    ),
    const SizedBox(height: PlaySpace.xxl),
    PlayButton(
      label: 'Accept & continue',
      icon: PlayIcons.arrowRight,
      size: PlayButtonSize.lg,
      expand: true,
      onPressed: () => setState(() => _step = _OnboardingStep.location),
    ),
    const SizedBox(height: PlaySpace.md),
    _LegalNotice(colors: colors),
  ];

  /// Step 2: the location rationale, shown only after the terms are accepted.
  List<Widget> _location(PlayColors colors) => <Widget>[
    Icon(PlayIcons.locate, size: 72, color: colors.primary),
    const SizedBox(height: PlaySpace.xl),
    Text(
      'Turn on location',
      textAlign: TextAlign.center,
      style: PlayType.headline.copyWith(color: colors.ink),
    ),
    const SizedBox(height: PlaySpace.md),
    Text(
      'See your area on the map, search for places and get turn-by-turn '
      'directions.',
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
      onPressed: () => unawaited(_finish(requestLocation: true)),
    ),
    const SizedBox(height: PlaySpace.sm),
    PlayButton(
      label: 'Not now',
      variant: PlayButtonVariant.ghost,
      expand: true,
      onPressed: () => unawaited(_finish(requestLocation: false)),
    ),
  ];

  Future<void> _finish({required bool requestLocation}) async {
    await ref.read(setOnboardingSeenProvider)(true);
    if (requestLocation) {
      // Prompts for permission; the service degrades to "no fix" if refused.
      unawaited(ref.read(locationServiceProvider).lastKnown());
    }
  }
}

/// The small "if you continue you accept…" line under the accept button, with
/// the terms and privacy policy as inline links.
class _LegalNotice extends ConsumerWidget {
  const _LegalNotice({required this.colors});

  final PlayColors colors;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final TextStyle base = PlayType.caption.copyWith(color: colors.inkMuted);
    final TextStyle link = base.copyWith(
      color: colors.primary,
      fontWeight: FontWeight.w700,
      decoration: TextDecoration.underline,
      decorationColor: colors.primary,
    );
    return Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: <Widget>[
        Text('By continuing, you accept our ', style: base),
        _LegalLink(
          label: 'Terms of Service',
          style: link,
          onTap: () =>
              ref.read(externalActionsProvider).openWebsite(LegalLinks.terms),
        ),
        Text(' and ', style: base),
        _LegalLink(
          label: 'Privacy Policy',
          style: link,
          onTap: () =>
              ref.read(externalActionsProvider).openWebsite(LegalLinks.privacy),
        ),
        Text('.', style: base),
      ],
    );
  }
}

class _LegalLink extends StatelessWidget {
  const _LegalLink({
    required this.label,
    required this.style,
    required this.onTap,
  });

  final String label;
  final TextStyle style;
  final Future<bool> Function() onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => unawaited(onTap()),
      child: Semantics(
        link: true,
        label: label,
        child: Text(label, style: style),
      ),
    );
  }
}
