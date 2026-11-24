import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../domain/entities/user_profile.dart';
import '../../../state/social.dart';
import '../../design/play.dart';
import '../widgets/profile_form.dart';

/// Edit the signed-in user's public profile (`/profile/edit`).
class EditProfileScreen extends ConsumerStatefulWidget {
  const EditProfileScreen({super.key});

  @override
  ConsumerState<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends ConsumerState<EditProfileScreen> {
  @override
  void initState() {
    super.initState();
    // Load the latest published values so the form is prefilled even when an
    // earlier screen already built this provider with stale (empty) data.
    WidgetsBinding.instance.addPostFrameCallback((Duration _) {
      if (mounted) {
        ref.read(profileControllerProvider.notifier).refresh();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final AsyncValue<UserProfile> profile = ref.watch(
      profileControllerProvider,
    );
    return PlayScaffold(
      appBar: PlayAppBar(
        title: 'Edit profile',
        onBackFallback: () => context.go('/'),
      ),
      child: profile.when(
        loading: () => const Center(child: PlaySpinner()),
        error: (Object error, StackTrace stack) => _error(context, ref),
        data: (UserProfile value) => ProfileForm(
          // Rebuild the form (and its text controllers) when the loaded
          // profile changes, so the fields are prefilled.
          key: ValueKey<UserProfile>(value),
          profile: value,
          submitLabel: 'Save profile',
          onSubmit: (ProfileSubmission submission) async {
            await ref
                .read(profileControllerProvider.notifier)
                .save(
                  profile: submission.profile,
                  pictureBytes: submission.pictureBytes,
                  pictureMimeType: submission.pictureMimeType,
                );
            if (context.mounted) {
              showPlayToast(context, 'Profile saved');
              context.pop();
            }
          },
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
              'Could not load your profile',
              style: PlayType.body.copyWith(color: colors.ink),
            ),
            const SizedBox(height: PlaySpace.md),
            PlayButton(
              label: 'Retry',
              variant: PlayButtonVariant.ghost,
              onPressed: () =>
                  ref.read(profileControllerProvider.notifier).refresh(),
            ),
          ],
        ),
      ),
    );
  }
}
