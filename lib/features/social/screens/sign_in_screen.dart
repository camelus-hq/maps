import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/errors/app_exception.dart';
import '../../../state/ports.dart';
import '../../../state/social.dart';
import '../../design/play.dart';

/// The sign-in screen (`/signin`): sign in with a NIP-55 signer app, a NIP-46
/// bunker, or a private key (`nsec`). All UI is Play — no Material widgets.
class SignInScreen extends StatelessWidget {
  const SignInScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return PlayScaffold(
      appBar: const PlayAppBar(title: 'Sign in'),
      child: SignInView(
        onSignedIn: () {
          if (context.canPop()) {
            context.pop();
          } else {
            context.go('/');
          }
        },
      ),
    );
  }
}

/// The reusable sign-in form, so the "You" tab can show it inline when signed
/// out and the `/signin` route can show it as a page.
class SignInView extends ConsumerStatefulWidget {
  const SignInView({super.key, this.onSignedIn});

  /// Called after a successful sign-in (the profile rebuilds reactively too).
  final VoidCallback? onSignedIn;

  @override
  ConsumerState<SignInView> createState() => _SignInViewState();
}

class _SignInViewState extends ConsumerState<SignInView> {
  final TextEditingController _nsec = TextEditingController();
  final TextEditingController _bunker = TextEditingController();
  bool _busy = false;
  String? _error;
  String? _bunkerAuthUrl;

  @override
  void dispose() {
    _nsec.dispose();
    _bunker.dispose();
    super.dispose();
  }

  Future<void> _run(Future<void> Function() action) async {
    if (_busy) {
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action();
      if (!mounted) {
        return;
      }
      ref.invalidate(friendsProvider);
      widget.onSignedIn?.call();
    } on AppException catch (error) {
      if (mounted) {
        setState(() => _error = error.message);
      }
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Could not sign in. Try again.');
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final PlayColors colors = PlayColors.of(context);
    final bool supportsSignerApp = ref
        .read(socialServiceProvider)
        .supportsSignerApp;

    return ListView(
      padding: const EdgeInsets.all(PlaySpace.lg),
      children: <Widget>[
        Icon(PlayIcons.brand, size: 40, color: colors.primary),
        const SizedBox(height: PlaySpace.md),
        Text(
          'Sign in to Nostr',
          style: PlayType.headline.copyWith(color: colors.ink),
        ),
        const SizedBox(height: PlaySpace.sm),
        Text(
          'A Nostr identity lets you share your live location with friends, '
          'encrypted to each of them.',
          style: PlayType.body.copyWith(color: colors.inkMuted),
        ),
        const SizedBox(height: PlaySpace.xl),

        if (supportsSignerApp) ...<Widget>[
          Text(
            'SIGNER APP',
            style: PlayType.overline.copyWith(color: colors.inkMuted),
          ),
          const SizedBox(height: PlaySpace.xs),
          PlayButton(
            label: 'Sign in with a signer app',
            icon: PlayIcons.device,
            expand: true,
            onPressed: _busy
                ? null
                : () => _run(
                    () => ref
                        .read(socialServiceProvider)
                        .signInWithExternalSigner(),
                  ),
          ),
          const SizedBox(height: PlaySpace.sm),
          Text(
            'Approves a sign-in request in an installed Nostr signer app '
            '(for example Amber) — your key never enters OpenMaps.',
            style: PlayType.caption.copyWith(color: colors.inkMuted),
          ),
          const SizedBox(height: PlaySpace.xl),
        ],

        Text(
          'BUNKER',
          style: PlayType.overline.copyWith(color: colors.inkMuted),
        ),
        const SizedBox(height: PlaySpace.xs),
        PlayTextField(
          controller: _bunker,
          hint: 'bunker://…',
          onChanged: (String _) {
            if (_error != null) {
              setState(() => _error = null);
            }
          },
        ),
        const SizedBox(height: PlaySpace.sm),
        PlayButton(
          label: 'Connect with a bunker',
          icon: PlayIcons.globe,
          variant: PlayButtonVariant.ghost,
          expand: true,
          onPressed: _busy
              ? null
              : () => _run(
                  () => ref
                      .read(socialServiceProvider)
                      .signInWithBunker(
                        _bunker.text,
                        onAuthUrl: (String url) {
                          if (mounted) {
                            setState(() => _bunkerAuthUrl = url);
                          }
                        },
                      ),
                ),
        ),
        if (_bunkerAuthUrl != null) ...<Widget>[
          const SizedBox(height: PlaySpace.sm),
          _AuthLink(url: _bunkerAuthUrl!),
        ],
        const SizedBox(height: PlaySpace.xl),

        Text(
          'PRIVATE KEY',
          style: PlayType.overline.copyWith(color: colors.inkMuted),
        ),
        const SizedBox(height: PlaySpace.xs),
        PlayTextField(
          controller: _nsec,
          hint: 'nsec… or 64-character hex key',
          obscureText: true,
          onSubmitted: (String _) => _run(
            () => ref
                .read(socialServiceProvider)
                .signInWithPrivateKey(_nsec.text),
          ),
          onChanged: (String _) {
            if (_error != null) {
              setState(() => _error = null);
            }
          },
        ),
        const SizedBox(height: PlaySpace.sm),
        PlayButton(
          label: 'Sign in with a private key',
          icon: PlayIcons.lock,
          variant: PlayButtonVariant.ghost,
          expand: true,
          onPressed: _busy
              ? null
              : () => _run(
                  () => ref
                      .read(socialServiceProvider)
                      .signInWithPrivateKey(_nsec.text),
                ),
        ),
        const SizedBox(height: PlaySpace.sm),
        Text(
          'Your private key never leaves this device. Only paste it into apps '
          'you trust.',
          style: PlayType.caption.copyWith(color: colors.inkMuted),
        ),

        if (_error != null) ...<Widget>[
          const SizedBox(height: PlaySpace.md),
          Text(
            _error!,
            textAlign: TextAlign.center,
            style: PlayType.caption.copyWith(color: colors.coral),
          ),
        ],

        const SizedBox(height: PlaySpace.xl),
        const PlayDivider(),
        const SizedBox(height: PlaySpace.lg),
        Text(
          'New to Nostr?',
          style: PlayType.subtitle.copyWith(color: colors.ink),
        ),
        const SizedBox(height: PlaySpace.xs),
        Text(
          'Create a new identity — we generate the keys and walk you through '
          'your profile and relays.',
          style: PlayType.caption.copyWith(color: colors.inkMuted),
        ),
        const SizedBox(height: PlaySpace.md),
        PlayButton(
          label: 'Create a new identity',
          icon: PlayIcons.add,
          variant: PlayButtonVariant.soft,
          expand: true,
          onPressed: _busy ? null : () => context.push('/signup'),
        ),
      ],
    );
  }
}

/// The "open this URL to approve the bunker connection" affordance.
class _AuthLink extends StatelessWidget {
  const _AuthLink({required this.url});

  final String url;

  @override
  Widget build(BuildContext context) {
    final PlayColors colors = PlayColors.of(context);
    return PlaySurface(
      radius: PlayRadii.md,
      borderWidth: 1,
      shadow: PlayShadow.none,
      padding: const EdgeInsets.all(PlaySpace.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'Approve the connection',
            style: PlayType.bodyStrong.copyWith(color: colors.ink),
          ),
          const SizedBox(height: PlaySpace.xs),
          SelectableRegion(
            selectionControls: emptyTextSelectionControls,
            child: Text(
              url,
              style: PlayType.caption.copyWith(color: colors.inkMuted),
            ),
          ),
          const SizedBox(height: PlaySpace.sm),
          PlayButton(
            label: 'Open link',
            icon: PlayIcons.goTo,
            variant: PlayButtonVariant.ghost,
            size: PlayButtonSize.sm,
            onPressed: () => unawaited(_open(url)),
          ),
        ],
      ),
    );
  }

  Future<void> _open(String url) async {
    try {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } catch (_) {
      // Best effort; the URL is shown so it can be copied manually.
    }
  }
}
