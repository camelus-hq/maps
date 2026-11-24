import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/errors/app_exception.dart';
import '../../../domain/entities/user_profile.dart';
import '../../../domain/entities/user_relay_lists.dart';
import '../../../state/ports.dart';
import '../../../state/social.dart';
import '../../design/play.dart';
import '../widgets/profile_form.dart';
import '../widgets/relays_form.dart';

/// The sign-up flow (`/signup`), in three easy steps:
/// 1. **Identity** — create a new key pair and back up the `nsec`.
/// 2. **Profile** — a public name, bio and picture.
/// 3. **Relays** — make sure both relay lists are set (defaulting to the app
///    relay when they are not) so the account can be reached.
class SignUpScreen extends ConsumerStatefulWidget {
  const SignUpScreen({super.key});

  @override
  ConsumerState<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends ConsumerState<SignUpScreen> {
  int _step = 0;
  String? _nsec;
  UserRelays _relays = const UserRelays();
  bool _busy = false;
  String? _error;

  Future<void> _createIdentity() async {
    if (_busy) {
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final String nsec = await ref.read(socialServiceProvider).createAccount();
      ref.invalidate(friendsProvider);
      // A brand-new account has no relay lists, so this comes back empty and
      // the defaults are filled in; if anything was published already it is
      // kept.
      UserRelays existing = const UserRelays();
      try {
        existing = await ref.read(socialServiceProvider).loadRelays();
      } catch (_) {
        // Offline is fine — the user can still edit and save the defaults.
      }
      if (!mounted) {
        return;
      }
      setState(() {
        _nsec = nsec;
        _relays = RelaysController.withDefaults(existing);
        _busy = false;
      });
    } on AppException catch (error) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = error.message;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = 'Could not create an identity. Try again.';
        });
      }
    }
  }

  Future<void> _saveProfile(ProfileSubmission submission) async {
    await ref
        .read(profileControllerProvider.notifier)
        .save(
          profile: submission.profile,
          pictureBytes: submission.pictureBytes,
          pictureMimeType: submission.pictureMimeType,
        );
    if (mounted) {
      setState(() => _step = 2);
    }
  }

  Future<void> _saveRelays(UserRelays relays) async {
    await ref.read(relaysControllerProvider.notifier).save(relays);
    if (mounted) {
      setState(() => _step = 3);
    }
  }

  @override
  Widget build(BuildContext context) {
    final PlayColors colors = PlayColors.of(context);
    return PlayScaffold(
      appBar: PlayAppBar(
        title: 'Create your identity',
        subtitle: _step < 3 ? 'Step ${_step + 1} of 3' : null,
        onBackFallback: () => context.go('/'),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          if (_step < 3)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                PlaySpace.lg,
                PlaySpace.sm,
                PlaySpace.lg,
                0,
              ),
              child: _StepBar(step: _step),
            ),
          Expanded(child: _body(context, colors)),
        ],
      ),
    );
  }

  Widget _body(BuildContext context, PlayColors colors) {
    switch (_step) {
      case 0:
        return _identityStep(context, colors);
      case 1:
        return _profileStep(context, colors);
      case 2:
        return _relaysStep(context, colors);
      default:
        return _doneStep(context, colors);
    }
  }

  Widget _identityStep(BuildContext context, PlayColors colors) {
    return ListView(
      padding: const EdgeInsets.all(PlaySpace.lg),
      children: <Widget>[
        if (_nsec == null) ...<Widget>[
          Text(
            'Create a new Nostr identity',
            style: PlayType.headline.copyWith(color: colors.ink),
          ),
          const SizedBox(height: PlaySpace.sm),
          Text(
            'We generate a key pair on this device. Your public key lets '
            'people find you; your private key (nsec) is how you sign in — '
            'nobody else should ever see it.',
            style: PlayType.body.copyWith(color: colors.inkMuted),
          ),
          const SizedBox(height: PlaySpace.xl),
          PlayButton(
            label: 'Create my identity',
            icon: PlayIcons.add,
            size: PlayButtonSize.lg,
            expand: true,
            onPressed: _busy ? null : () => unawaited(_createIdentity()),
          ),
        ] else ...<Widget>[
          Text(
            'Save your private key',
            style: PlayType.headline.copyWith(color: colors.ink),
          ),
          const SizedBox(height: PlaySpace.sm),
          Text(
            'This is the only time we show it. Store it somewhere safe — with '
            'it anyone can control your identity, and without it you cannot '
            'sign back in.',
            style: PlayType.body.copyWith(color: colors.inkMuted),
          ),
          const SizedBox(height: PlaySpace.lg),
          _SecretCard(nsec: _nsec!),
          const SizedBox(height: PlaySpace.xl),
          PlayButton(
            label: 'I saved my key — continue',
            icon: PlayIcons.arrowRight,
            size: PlayButtonSize.lg,
            expand: true,
            onPressed: () => setState(() => _step = 1),
          ),
        ],
        if (_error != null) ...<Widget>[
          const SizedBox(height: PlaySpace.md),
          Text(
            _error!,
            textAlign: TextAlign.center,
            style: PlayType.caption.copyWith(color: colors.coral),
          ),
        ],
      ],
    );
  }

  Widget _profileStep(BuildContext context, PlayColors colors) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.fromLTRB(
            PlaySpace.lg,
            PlaySpace.lg,
            PlaySpace.lg,
            0,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                'Your profile',
                style: PlayType.headline.copyWith(color: colors.ink),
              ),
              const SizedBox(height: PlaySpace.sm),
              Text(
                'Add a name, a short bio and a picture so friends recognise '
                'you. You can change all of this later.',
                style: PlayType.body.copyWith(color: colors.inkMuted),
              ),
            ],
          ),
        ),
        Expanded(
          child: ProfileForm(
            profile:
                ref.read(profileControllerProvider).value ??
                const UserProfile(),
            submitLabel: 'Save and continue',
            onSubmit: _saveProfile,
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(PlaySpace.sm),
          child: Center(
            child: PlayButton(
              label: 'Skip for now',
              variant: PlayButtonVariant.ghost,
              size: PlayButtonSize.sm,
              onPressed: () => setState(() => _step = 2),
            ),
          ),
        ),
      ],
    );
  }

  Widget _relaysStep(BuildContext context, PlayColors colors) {
    return ListView(
      padding: const EdgeInsets.all(PlaySpace.lg),
      children: <Widget>[
        Text(
          'Your relays',
          style: PlayType.headline.copyWith(color: colors.ink),
        ),
        const SizedBox(height: PlaySpace.sm),
        Text(
          'Relays are the servers that carry your notes and messages. We have '
          'filled in a good default for both lists; change them any time.',
          style: PlayType.body.copyWith(color: colors.inkMuted),
        ),
        const SizedBox(height: PlaySpace.xl),
        RelaysForm(
          relays: _relays,
          submitLabel: 'Finish',
          onSubmit: _saveRelays,
        ),
        const SizedBox(height: PlaySpace.sm),
        Center(
          child: PlayButton(
            label: 'Set up later',
            variant: PlayButtonVariant.ghost,
            size: PlayButtonSize.sm,
            onPressed: () => setState(() => _step = 3),
          ),
        ),
      ],
    );
  }

  Widget _doneStep(BuildContext context, PlayColors colors) {
    return ListView(
      padding: const EdgeInsets.all(PlaySpace.lg),
      children: <Widget>[
        const SizedBox(height: PlaySpace.xl),
        Icon(PlayIcons.check, size: 56, color: colors.primary),
        const SizedBox(height: PlaySpace.md),
        Text(
          'You are all set',
          textAlign: TextAlign.center,
          style: PlayType.headline.copyWith(color: colors.ink),
        ),
        const SizedBox(height: PlaySpace.sm),
        Text(
          'Your identity is ready. Find friends, share your live location and '
          'explore the map.',
          textAlign: TextAlign.center,
          style: PlayType.body.copyWith(color: colors.inkMuted),
        ),
        const SizedBox(height: PlaySpace.xl),
        PlayButton(
          label: 'Go to my profile',
          icon: PlayIcons.arrowRight,
          size: PlayButtonSize.lg,
          expand: true,
          onPressed: () => context.go('/profile'),
        ),
      ],
    );
  }
}

/// The three-dot progress indicator for the sign-up steps.
class _StepBar extends StatelessWidget {
  const _StepBar({required this.step});

  final int step;

  @override
  Widget build(BuildContext context) {
    final PlayColors colors = PlayColors.of(context);
    return Row(
      children: <Widget>[
        for (int i = 0; i < 3; i++) ...<Widget>[
          Expanded(
            child: Container(
              height: 4,
              decoration: BoxDecoration(
                color: i <= step ? colors.primary : colors.surfaceSunken,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          if (i < 2) const SizedBox(width: PlaySpace.xs),
        ],
      ],
    );
  }
}

/// The private key with a visibility toggle, copy button and a warning.
class _SecretCard extends StatefulWidget {
  const _SecretCard({required this.nsec});

  final String nsec;

  @override
  State<_SecretCard> createState() => _SecretCardState();
}

class _SecretCardState extends State<_SecretCard> {
  bool _visible = false;

  @override
  Widget build(BuildContext context) {
    final PlayColors colors = PlayColors.of(context);
    final String displayedKey = _visible
        ? widget.nsec
        : List<String>.filled(widget.nsec.length, '•').join();

    return PlaySurface(
      radius: PlayRadii.md,
      borderWidth: 1,
      borderColor: colors.coral,
      shadow: PlayShadow.none,
      padding: const EdgeInsets.all(PlaySpace.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(PlayIcons.lock, size: 18, color: colors.coral),
              const SizedBox(width: PlaySpace.sm),
              Text(
                'Private key (nsec)',
                style: PlayType.bodyStrong.copyWith(color: colors.ink),
              ),
              const Spacer(),
              PlayIconButton(
                icon: _visible ? PlayIcons.private : PlayIcons.eye,
                variant: PlayIconButtonVariant.plain,
                size: 40,
                iconSize: 20,
                semanticLabel: _visible ? 'Hide private key' : 'Show private key',
                onPressed: () => setState(() => _visible = !_visible),
              ),
            ],
          ),
          const SizedBox(height: PlaySpace.sm),
          SelectableRegion(
            selectionControls: emptyTextSelectionControls,
            child: Text(
              displayedKey,
              style: PlayType.body.copyWith(
                color: colors.ink,
                fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
              ),
            ),
          ),
          const SizedBox(height: PlaySpace.sm),
          Align(
            alignment: Alignment.centerLeft,
            child: PlayButton(
              label: 'Copy key',
              icon: PlayIcons.copy,
              variant: PlayButtonVariant.ghost,
              size: PlayButtonSize.sm,
              onPressed: () => unawaited(_copy(context, widget.nsec)),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _copy(BuildContext context, String value) async {
    try {
      await Clipboard.setData(ClipboardData(text: value));
      if (context.mounted) {
        showPlayToast(context, 'Private key copied');
      }
    } catch (_) {
      // Clipboard is unavailable in some environments.
    }
  }
}
