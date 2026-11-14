import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:ndk_flutter/ndk_flutter.dart';

import '../../../core/errors/app_exception.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../state/commands/commands_provider.dart';
import '../../../state/ports.dart';
import '../../../state/social.dart';
import '../widgets/friend_avatar.dart';

/// The "You" screen (`/profile`): sign in with Nostr, see the identity, sign out.
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ThemeData theme = Theme.of(context);
    final NdkFlutter? ndkFlutter = ref.watch(ndkFlutterProvider);
    final String? pubkey = ref.watch(nostrPubkeyProvider).value;
    final bool signedIn = pubkey != null;

    return Scaffold(
      appBar: AppBar(title: const Text('You')),
      body: SafeArea(
        child: signedIn
            ? _signedIn(context, ref, theme, pubkey, ndkFlutter)
            : _signedOut(context, ref, theme, ndkFlutter),
      ),
    );
  }

  Widget _signedIn(
    BuildContext context,
    WidgetRef ref,
    ThemeData theme,
    String pubkey,
    NdkFlutter? ndkFlutter,
  ) {
    final String display = ndkFlutter?.formatNpub(pubkey) ?? _short(pubkey);
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.md),
      children: <Widget>[
        Row(
          children: <Widget>[
            FriendAvatar(label: display, size: 56),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    'Signed in to Nostr',
                    style: theme.textTheme.titleMedium,
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  SelectableText(display, style: theme.textTheme.bodySmall),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.people_outline),
          title: const Text('Friends'),
          subtitle: const Text('See who is sharing and share your location'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => context.push('/friends'),
        ),
        const Divider(),
        Text(
          'Your live location is gift-wrap encrypted to the friends you pick. '
          'Relays never see your coordinates, your name or who you are.',
          style: theme.textTheme.bodySmall,
        ),
        const SizedBox(height: AppSpacing.lg),
        OutlinedButton.icon(
          onPressed: () => unawaited(_signOut(ref)),
          icon: const Icon(Icons.logout),
          label: const Text('Sign out'),
        ),
      ],
    );
  }

  Widget _signedOut(
    BuildContext context,
    WidgetRef ref,
    ThemeData theme,
    NdkFlutter? ndkFlutter,
  ) {
    if (ndkFlutter == null) {
      return _ManualSignIn(
        onSignIn: (String key) async {
          await ref.read(socialServiceProvider).signInWithPrivateKey(key);
          ref.invalidate(friendsProvider);
        },
      );
    }
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text('Sign in to Nostr', style: theme.textTheme.titleLarge),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'A Nostr identity lets you share your live location with friends, '
            'encrypted to each of them.',
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: AppSpacing.md),
          NLogin(
            ndkFlutter: ndkFlutter,
            onLoggedIn: () {
              ref.invalidate(friendsProvider);
              if (context.mounted) {
                ScaffoldMessenger.of(context)
                    .showSnackBar(const SnackBar(content: Text('Signed in')));
              }
            },
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            'Only open-source relays are used. Your private key never leaves '
            'this device.',
            style: theme.textTheme.bodySmall,
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
    final ThemeData theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.md),
      children: <Widget>[
        Text('Sign in to Nostr', style: theme.textTheme.titleLarge),
        const SizedBox(height: AppSpacing.sm),
        Text(
          'Enter a private key (nsec…) to sign in. This build has no Nostr '
          'client wired, so only the demo identity is available.',
          style: theme.textTheme.bodyMedium,
        ),
        const SizedBox(height: AppSpacing.md),
        TextField(
          controller: _controller,
          obscureText: true,
          decoration: const InputDecoration(
            labelText: 'Private key',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        FilledButton(
          onPressed: _busy ? null : _submit,
          child: _busy
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Sign in'),
        ),
      ],
    );
  }

  Future<void> _submit() async {
    setState(() => _busy = true);
    try {
      await widget.onSignIn(_controller.text);
    } on AppException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(error.message)));
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }
}
