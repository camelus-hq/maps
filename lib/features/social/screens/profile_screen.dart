import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../domain/entities/friend.dart';
import '../../../state/commands/commands_provider.dart';
import '../../../state/ports.dart';
import '../../../state/social.dart';
import '../../design/play.dart';
import '../widgets/friend_avatar.dart';
import 'sign_in_screen.dart';

/// The "You" screen (`/profile`): the identity, a way to edit the profile and
/// relays, and sign out. Signed out, it shows the sign-in form inline.
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final String? pubkey = ref.watch(nostrPubkeyProvider).value;
    if (pubkey == null) {
      return const PlayScaffold(
        appBar: PlayAppBar(title: 'You'),
        child: SignInView(),
      );
    }
    return PlayScaffold(
      appBar: const PlayAppBar(title: 'You'),
      child: _signedIn(context, ref, pubkey),
    );
  }

  Widget _signedIn(BuildContext context, WidgetRef ref, String pubkey) {
    final PlayColors colors = PlayColors.of(context);
    final Friend? profile = ref.watch(myProfileProvider).value;
    final String name = profile?.label ?? 'You';
    final String npub =
        ref.read(socialServiceProvider).encodeNpub(pubkey) ?? _short(pubkey);

    return ListView(
      padding: const EdgeInsets.all(PlaySpace.lg),
      children: <Widget>[
        Row(
          children: <Widget>[
            FriendAvatar(
              label: name,
              pictureUrl: profile?.pictureUrl,
              size: 64,
              borderColor: colors.primary,
            ),
            const SizedBox(width: PlaySpace.lg),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: PlayType.title.copyWith(color: colors.ink),
                  ),
                  const SizedBox(height: PlaySpace.xs),
                  SelectableRegion(
                    selectionControls: emptyTextSelectionControls,
                    child: Text(
                      npub,
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
          icon: PlayIcons.user,
          label: 'Edit profile',
          subtitle: 'Name, bio and picture',
          onTap: () => context.push('/profile/edit'),
        ),
        const PlayDivider(),
        PlayRow(
          icon: PlayIcons.globe,
          label: 'Relays',
          subtitle: 'Where your notes and messages are carried',
          onTap: () => context.push('/profile/relays'),
        ),
        const PlayDivider(),
        PlayRow(
          icon: PlayIcons.friends,
          label: 'Friends',
          subtitle: 'See who is sharing and share your location',
          onTap: () => context.push('/friends'),
        ),
        const SizedBox(height: PlaySpace.lg),
        Text(
          'Your profile and relay lists are public. Your live location is '
          'gift-wrap encrypted to the friends you pick — relays never see your '
          'coordinates, your name or who you are.',
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

  Future<void> _signOut(WidgetRef ref) async {
    await ref
        .read(commandRegistryProvider)
        .dispatch('social.logout', const <String, Object?>{});
  }

  static String _short(String pubkey) =>
      pubkey.length <= 16 ? pubkey : '${pubkey.substring(0, 12)}…';
}
