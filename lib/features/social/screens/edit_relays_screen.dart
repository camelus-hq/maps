import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../domain/entities/user_relay_lists.dart';
import '../../../state/social.dart';
import '../../design/play.dart';
import '../widgets/relays_form.dart';

/// Edit the signed-in user's NIP-65 and NIP-17 DM relay lists
/// (`/profile/relays`).
class EditRelaysScreen extends ConsumerWidget {
  const EditRelaysScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<UserRelays> relays = ref.watch(relaysControllerProvider);
    return PlayScaffold(
      appBar: const PlayAppBar(title: 'Relays'),
      child: relays.when(
        loading: () => const Center(child: PlaySpinner()),
        error: (Object error, StackTrace stack) => _error(context, ref),
        data: (UserRelays value) => ListView(
          padding: const EdgeInsets.all(PlaySpace.lg),
          children: <Widget>[
            Text(
              'Relays are the servers that carry your Nostr activity. Keep at '
              'least one in each list so you can be reached.',
              style: PlayType.body.copyWith(
                color: PlayColors.of(context).inkMuted,
              ),
            ),
            const SizedBox(height: PlaySpace.lg),
            RelaysForm(
              relays: RelaysController.withDefaults(value),
              submitLabel: 'Save relays',
              onSubmit: (UserRelays next) async {
                await ref.read(relaysControllerProvider.notifier).save(next);
                if (context.mounted) {
                  showPlayToast(context, 'Relays saved');
                  context.pop();
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _error(BuildContext context, WidgetRef ref) {
    final PlayColors colors = PlayColors.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(PlaySpace.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(PlayIcons.error, color: colors.ink),
            const SizedBox(height: PlaySpace.sm),
            Text(
              'Could not load your relays',
              style: PlayType.body.copyWith(color: colors.ink),
            ),
            const SizedBox(height: PlaySpace.md),
            PlayButton(
              label: 'Retry',
              variant: PlayButtonVariant.ghost,
              onPressed: () => ref.invalidate(relaysControllerProvider),
            ),
          ],
        ),
      ),
    );
  }
}
