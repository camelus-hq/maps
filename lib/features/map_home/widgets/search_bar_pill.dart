import 'package:flutter/material.dart';
import 'package:flutter/widget_previews.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../domain/entities/friend.dart';
import '../../../state/social.dart';
import '../../social/widgets/friend_avatar.dart';

/// The floating search bar at the top of the map-home shell.
///
/// Has our own leading logo slot plus microphone and account slots, mirroring
/// the Google Maps layout (our own iconography, never Google's). The account
/// slot shows the signed-in Nostr user's profile picture (monogram fallback),
/// or a generic person icon when signed out.
class SearchBarPill extends ConsumerWidget {
  const SearchBarPill({super.key, required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final BorderRadius radius = BorderRadius.circular(AppSpacing.pillRadius);
    return Material(
      color: scheme.surface,
      elevation: 2,
      borderRadius: radius,
      child: InkWell(
        borderRadius: radius,
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.md,
            10,
            AppSpacing.sm,
            10,
          ),
          child: Row(
            children: <Widget>[
              // Our own brand mark (not Google's multicolour logo).
              Icon(Icons.place, color: scheme.primary),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  'Search here',
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
              ),
              Tooltip(
                message: 'Voice search (coming soon)',
                child: Icon(Icons.mic_none, color: scheme.onSurfaceVariant),
              ),
              const SizedBox(width: AppSpacing.sm),
              InkWell(
                onTap: () => context.push('/settings'),
                customBorder: const CircleBorder(),
                child: _AccountAvatar(scheme: scheme),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The account slot: the signed-in user's Nostr picture/monogram, else a
/// generic person icon. Watches the profile so a picture that resolves later
/// replaces the monogram.
class _AccountAvatar extends ConsumerWidget {
  const _AccountAvatar({required this.scheme});

  final ColorScheme scheme;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final String? pubkey = ref.watch(nostrPubkeyProvider).value;
    if (pubkey == null) {
      return CircleAvatar(
        radius: 16,
        backgroundColor: scheme.primaryContainer,
        child: Icon(Icons.person, size: 18, color: scheme.onPrimaryContainer),
      );
    }
    final Friend? profile = ref.watch(myProfileProvider).value;
    return FriendAvatar(
      label: profile?.label ?? 'You',
      pictureUrl: profile?.pictureUrl,
      size: 32,
    );
  }
}

@Preview(name: 'Search bar pill', size: Size(400, 80))
Widget preview() {
  return ProviderScope(
    child: Padding(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: SearchBarPill(onTap: () {}),
    ),
  );
}

@Preview(name: 'Search bar pill', size: Size(400, 80))
Widget searchBarPillPreview() {
  return ProviderScope(
    child: MaterialApp.router(
      routerConfig: GoRouter(
        routes: <RouteBase>[
          GoRoute(
            path: '/',
            builder: (BuildContext context, GoRouterState state) {
              return Scaffold(
                body: SafeArea(
                  child: Padding(
                    padding: EdgeInsets.all(AppSpacing.md),
                    child: Center(child: SearchBarPill(onTap: () {})),
                  ),
                ),
              );
            },
          ),
          GoRoute(
            path: '/settings',
            builder: (BuildContext context, GoRouterState state) {
              return const Scaffold(body: Center(child: Text('Settings')));
            },
          ),
        ],
      ),
    ),
  );
}
