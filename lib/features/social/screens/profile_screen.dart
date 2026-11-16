import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ndk_flutter/ndk_flutter.dart';

import '../../../core/errors/app_exception.dart';
import '../../../state/commands/commands_provider.dart';
import '../../../state/ports.dart';
import '../../../state/social.dart';
import '../../common/material_host.dart';
import '../../design/play.dart';
import '../widgets/friend_avatar.dart';

/// The "You" screen (`/profile`): sign in with Nostr, see the identity, sign out.
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final NdkFlutter? ndkFlutter = ref.watch(ndkFlutterProvider);
    final String? pubkey = ref.watch(nostrPubkeyProvider).value;
    final bool signedIn = pubkey != null;

    return PlayScaffold(
      appBar: const PlayAppBar(title: 'You'),
      child: signedIn
          ? _signedIn(context, ref, pubkey, ndkFlutter)
          : _signedOut(context, ref, ndkFlutter),
    );
  }

  Widget _signedIn(
    BuildContext context,
    WidgetRef ref,
    String pubkey,
    NdkFlutter? ndkFlutter,
  ) {
    final PlayColors colors = PlayColors.of(context);
    final String display = ndkFlutter?.formatNpub(pubkey) ?? _short(pubkey);
    return ListView(
      padding: const EdgeInsets.all(PlaySpace.lg),
      children: <Widget>[
        Row(
          children: <Widget>[
            FriendAvatar(label: display, size: 56),
            const SizedBox(width: PlaySpace.lg),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    'Signed in to Nostr',
                    style: PlayType.subtitle.copyWith(color: colors.ink),
                  ),
                  const SizedBox(height: PlaySpace.xs),
                  SelectableRegion(
                    selectionControls: emptyTextSelectionControls,
                    child: Text(
                      display,
                      style: PlayType.caption.copyWith(color: colors.inkMuted),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: PlaySpace.lg),
        PlayRow(
          icon: PlayIcons.friends,
          label: 'Friends',
          subtitle: 'See who is sharing and share your location',
          onTap: () => context.push('/friends'),
        ),
        const PlayDivider(),
        Text(
          'Your live location is gift-wrap encrypted to the friends you pick. '
          'Relays never see your coordinates, your name or who you are.',
          style: PlayType.caption.copyWith(color: colors.inkMuted),
        ),
        const SizedBox(height: PlaySpace.lg),
        PlayButton(
          label: 'Sign out',
          icon: PlayIcons.signOut,
          variant: PlayButtonVariant.ghost,
          onPressed: () => unawaited(_signOut(ref)),
        ),
      ],
    );
  }

  Widget _signedOut(
    BuildContext context,
    WidgetRef ref,
    NdkFlutter? ndkFlutter,
  ) {
    final PlayColors colors = PlayColors.of(context);
    if (ndkFlutter == null) {
      return _ManualSignIn(
        onSignIn: (String key) async {
          await ref.read(socialServiceProvider).signInWithPrivateKey(key);
          ref.invalidate(friendsProvider);
        },
      );
    }
    return SingleChildScrollView(
      padding: const EdgeInsets.all(PlaySpace.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(
            'Sign in to Nostr',
            style: PlayType.title.copyWith(color: colors.ink),
          ),
          const SizedBox(height: PlaySpace.sm),
          Text(
            'A Nostr identity lets you share your live location with friends, '
            'encrypted to each of them.',
            style: PlayType.body.copyWith(color: colors.inkMuted),
          ),
          const SizedBox(height: PlaySpace.md),
          // ndk_flutter's NLogin is built from the deprecated
          // `package:flutter/material.dart` library, whose TextField needs a
          // Material ancestor of that same library; the Play UI (and the app's
          // `material_ui`) deliberately have none. MaterialHost supplies just
          // that transparent ancestor around the third-party widget.
          MaterialHost(
            child: NLogin(
              ndkFlutter: ndkFlutter,
              onLoggedIn: () {
                ref.invalidate(friendsProvider);
                if (context.mounted) {
                  showPlayToast(context, 'Signed in');
                }
              },
            ),
          ),
          const SizedBox(height: PlaySpace.md),
          Text(
            'Only open-source relays are used. Your private key never leaves '
            'this device.',
            style: PlayType.caption.copyWith(color: colors.inkMuted),
          ),
        ],
      ),
    );
  }

  Future<void> _signOut(WidgetRef ref) async {
    await ref
        .read(commandRegistryProvider)
        .dispatch('social.logout', const <String, Object?>{});
  }

  static String _short(String pubkey) =>
      pubkey.length <= 16 ? pubkey : '${pubkey.substring(0, 12)}…';
}

/// Fallback sign-in when the Nostr client is not wired (keyless builds/tests).
class _ManualSignIn extends StatefulWidget {
  const _ManualSignIn({required this.onSignIn});

  final Future<void> Function(String key) onSignIn;

  @override
  State<_ManualSignIn> createState() => _ManualSignInState();
}

class _ManualSignInState extends State<_ManualSignIn> {
  final TextEditingController _controller = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final PlayColors colors = PlayColors.of(context);
    return ListView(
      padding: const EdgeInsets.all(PlaySpace.lg),
      children: <Widget>[
        Text(
          'Sign in to Nostr',
          style: PlayType.title.copyWith(color: colors.ink),
        ),
        const SizedBox(height: PlaySpace.sm),
        Text(
          'Enter a private key (nsec…) to sign in. This build has no Nostr '
          'client wired, so only the demo identity is available.',
          style: PlayType.body.copyWith(color: colors.inkMuted),
        ),
        const SizedBox(height: PlaySpace.md),
        _SecretField(
          controller: _controller,
          hint: 'Private key',
          onSubmitted: (String _) => unawaited(_submit()),
        ),
        const SizedBox(height: PlaySpace.md),
        PlayButton(label: 'Sign in', onPressed: _busy ? null : _submit),
      ],
    );
  }

  Future<void> _submit() async {
    if (_busy) {
      return;
    }
    setState(() => _busy = true);
    try {
      await widget.onSignIn(_controller.text);
    } on AppException catch (error) {
      if (mounted) {
        showPlayToast(context, error.message);
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }
}

/// A masked single-line field for the private key.
///
/// Built directly on the widgets-layer [EditableText] (like [PlayTextField]) so
/// it stays Material-free while obscuring the secret; [PlayTextField] has no
/// obscure mode of its own.
class _SecretField extends StatefulWidget {
  const _SecretField({
    required this.controller,
    required this.hint,
    this.onSubmitted,
  });

  final TextEditingController controller;
  final String hint;
  final ValueChanged<String>? onSubmitted;

  @override
  State<_SecretField> createState() => _SecretFieldState();
}

class _SecretFieldState extends State<_SecretField> {
  final FocusNode _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onChanged);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onChanged);
    _focus.dispose();
    super.dispose();
  }

  void _onChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final PlayColors colors = PlayColors.of(context);
    final bool hasText = widget.controller.text.isNotEmpty;
    return PlaySurface(
      radius: PlayRadii.pill,
      borderWidth: 1,
      shadow: PlayShadow.none,
      padding: const EdgeInsets.symmetric(
        horizontal: PlaySpace.lg,
        vertical: PlaySpace.md,
      ),
      child: Row(
        children: <Widget>[
          Icon(PlayIcons.lock, size: 20, color: colors.inkMuted),
          const SizedBox(width: PlaySpace.sm),
          Expanded(
            child: Stack(
              children: <Widget>[
                if (!hasText)
                  Text(
                    widget.hint,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: PlayType.body.copyWith(color: colors.inkFaint),
                  ),
                EditableText(
                  controller: widget.controller,
                  focusNode: _focus,
                  obscureText: true,
                  style: PlayType.body.copyWith(color: colors.ink),
                  cursorColor: colors.primary,
                  backgroundCursorColor: colors.inkFaint,
                  selectionColor: colors.primary.withValues(alpha: 0.25),
                  maxLines: 1,
                  keyboardType: TextInputType.text,
                  onSubmitted: widget.onSubmitted,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
