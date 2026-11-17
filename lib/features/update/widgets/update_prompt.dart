import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../domain/entities/app_update.dart';
import '../../../state/update.dart';
import '../../design/play.dart';

/// Shows the "new version available" prompt as a play sheet over the app on
/// startup.
///
/// Rendered above the router (in `MaterialApp.router`'s `builder`) so it covers
/// whatever screen is showing, and only appears once the check has found a
/// newer release the user has not already declined. The sheet lists the
/// release's changes (which can be long, so it scrolls) above the Later /
/// Update actions.
class UpdatePromptHost extends ConsumerStatefulWidget {
  const UpdatePromptHost({required this.child, super.key});

  final Widget child;

  @override
  ConsumerState<UpdatePromptHost> createState() => _UpdatePromptHostState();
}

class _UpdatePromptHostState extends ConsumerState<UpdatePromptHost> {
  @override
  void initState() {
    super.initState();
    // Check once, after the first frame, so the app is up before we hit the
    // network and the sheet can be shown if a release is found.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      unawaited(ref.read(updateControllerProvider.notifier).check());
    });
  }

  @override
  Widget build(BuildContext context) {
    final UpdateState update = ref.watch(updateControllerProvider);
    return Stack(
      fit: StackFit.expand,
      children: <Widget>[
        widget.child,
        if (update.shouldPrompt)
          Positioned.fill(
            child: Stack(
              children: <Widget>[
                // The dimmed backdrop. Tapping it dismisses the prompt, unless
                // the update is mandatory or already downloading.
                Positioned.fill(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: update.isMandatory || update.installing
                        ? null
                        : () => unawaited(
                            ref
                                .read(updateControllerProvider.notifier)
                                .dismissPrompt(),
                          ),
                    child: const ColoredBox(color: Color(0x8A000000)),
                  ),
                ),
                const Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: UpdatePromptSheet(),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// The prompt itself: the version, the (scrollable) list of changes, download
/// progress/errors and the Later / Update actions.
class UpdatePromptSheet extends ConsumerWidget {
  const UpdatePromptSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final UpdateState update = ref.watch(updateControllerProvider);
    final AppRelease? release = update.release;
    if (release == null) {
      return const SizedBox.shrink();
    }
    final PlayColors colors = PlayColors.of(context);
    final List<String> changes = release.changes;
    final String? error = update.error;
    final double maxHeight = MediaQuery.sizeOf(context).height * 0.8;

    // Absorb taps on the sheet so only the backdrop above it dismisses.
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {},
      child: PlaySheet(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: maxHeight),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                const PlaySheetHandle(width: 36),
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    PlaySpace.lg,
                    0,
                    PlaySpace.lg,
                    PlaySpace.sm,
                  ),
                  child: Row(
                    children: <Widget>[
                      Icon(PlayIcons.download, color: colors.primary),
                      const SizedBox(width: PlaySpace.sm),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              'Update available',
                              style: PlayType.subtitle.copyWith(
                                color: colors.ink,
                              ),
                            ),
                            Text(
                              'OpenMaps ${release.versionName} is ready to '
                              'install',
                              style: PlayType.caption.copyWith(
                                color: colors.inkMuted,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (release.mandatory)
                        PlaySurface(
                          tone: PlayTone.coral,
                          radius: PlayRadii.xs,
                          shadow: PlayShadow.none,
                          padding: const EdgeInsets.symmetric(
                            horizontal: PlaySpace.sm,
                            vertical: PlaySpace.xs,
                          ),
                          child: Text(
                            'Required',
                            style: PlayType.caption.copyWith(
                              color: colors.onCoral,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                if (changes.isNotEmpty)
                  Flexible(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(
                        PlaySpace.lg,
                        0,
                        PlaySpace.lg,
                        PlaySpace.sm,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            "What's new",
                            style: PlayType.bodyStrong.copyWith(
                              color: colors.primary,
                            ),
                          ),
                          const SizedBox(height: PlaySpace.sm),
                          for (final String change in changes)
                            _ChangeRow(text: change),
                        ],
                      ),
                    ),
                  )
                else
                  const SizedBox(height: PlaySpace.sm),
                if (update.installing)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                      PlaySpace.lg,
                      PlaySpace.sm,
                      PlaySpace.lg,
                      0,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: <Widget>[
                        PlayProgress(
                          value: update.progress > 0 && update.progress < 1
                              ? update.progress
                              : null,
                        ),
                        const SizedBox(height: PlaySpace.sm),
                        Text(
                          'Downloading the update…',
                          style: PlayType.body.copyWith(color: colors.ink),
                        ),
                      ],
                    ),
                  ),
                if (error != null)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                      PlaySpace.lg,
                      PlaySpace.sm,
                      PlaySpace.lg,
                      0,
                    ),
                    child: Text(
                      error,
                      style: PlayType.body.copyWith(color: colors.coral),
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    PlaySpace.lg,
                    PlaySpace.lg,
                    PlaySpace.lg,
                    PlaySpace.md,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: <Widget>[
                      if (!update.isMandatory)
                        PlayButton(
                          label: 'Later',
                          variant: PlayButtonVariant.ghost,
                          onPressed: update.installing
                              ? null
                              : () => unawaited(
                                  ref
                                      .read(updateControllerProvider.notifier)
                                      .dismissPrompt(),
                                ),
                        ),
                      const SizedBox(width: PlaySpace.sm),
                      PlayButton(
                        label: update.installing ? 'Installing…' : 'Update',
                        onPressed: update.installing
                            ? null
                            : () => unawaited(
                                ref
                                    .read(updateControllerProvider.notifier)
                                    .install(),
                              ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// One change in the release's list: a bullet and the commit subject.
class _ChangeRow extends StatelessWidget {
  const _ChangeRow({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final PlayColors colors = PlayColors.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: PlaySpace.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.only(top: 6, right: PlaySpace.sm),
            child: Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                color: colors.primary,
                shape: BoxShape.circle,
              ),
            ),
          ),
          Expanded(
            child: Text(text, style: PlayType.body.copyWith(color: colors.ink)),
          ),
        ],
      ),
    );
  }
}
