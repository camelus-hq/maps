import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../domain/entities/friend.dart';
import '../../../state/social.dart';
import '../../design/play.dart';

/// The floating search bar at the top of the map-home shell, in the play style.
///
/// Our own compass mark, a voice-search slot and the signed-in account avatar
/// (with a monogram fallback). Tapping the bar opens the search screen; the
/// avatar opens settings. Built entirely from the play kit — no Material chrome.
class SearchBarPill extends ConsumerWidget {
  const SearchBarPill({super.key, required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final PlayColors colors = PlayColors.of(context);
    return PlaySurface(
      radius: PlayRadii.pill,
      borderWidth: 1,
      shadow: PlayShadow.soft,
      padding: const EdgeInsets.all(PlaySpace.sm),
      onTap: onTap,
      child: Row(
        children: <Widget>[
          // Our own brand mark (a compass tile), never Google's logo.
          PlaySurface(
            radius: PlayRadii.xs,
            tone: PlayTone.teal,
            shadow: PlayShadow.none,
            padding: const EdgeInsets.all(7),
            child: Icon(PlayIcons.brand, size: 20, color: colors.onTeal),
          ),
          const SizedBox(width: PlaySpace.md),
          Expanded(
            child: Text(
              'Search here',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: PlayType.body.copyWith(color: colors.inkMuted),
            ),
          ),
          const SizedBox(width: PlaySpace.xs),
          Semantics(
            label: 'Voice search (coming soon)',
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: PlaySpace.sm),
              child: Icon(
                PlayIcons.microphone,
                size: 22,
                color: colors.inkMuted,
              ),
            ),
          ),
          const SizedBox(width: PlaySpace.xs),
          PlayPressable(
            onTap: () => context.push('/settings'),
            child: const _AccountAvatar(),
          ),
        ],
      ),
    );
  }
}

/// The account slot: the signed-in user's Nostr picture/monogram, else a
/// generic person glyph. Watches the profile so a picture that resolves later
/// replaces the monogram.
class _AccountAvatar extends ConsumerWidget {
  const _AccountAvatar();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final String? pubkey = ref.watch(nostrPubkeyProvider).value;
    if (pubkey == null) {
      return const PlayAvatar(
        label: 'You',
        icon: PlayIcons.user,
        size: 36,
        tone: PlayTone.soft,
      );
    }
    final Friend? profile = ref.watch(myProfileProvider).value;
    return PlayAvatar(
      label: profile?.label ?? 'You',
      imageUrl: profile?.pictureUrl,
      size: 36,
      tone: PlayTone.soft,
    );
  }
}

@PlayPreview(name: 'SearchBarPill', size: Size(460, 140))
Widget searchBarPillPreview() {
  return PlayPreviewFrame(
    alignment: Alignment.topCenter,
    child: ProviderScope(child: SearchBarPill(onTap: () {})),
  );
}
