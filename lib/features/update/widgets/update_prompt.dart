import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../domain/entities/app_update.dart';
import '../../../state/update.dart';

/// Shows the "new version available" prompt as a bottom sheet over the app on
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
                    child: const ColoredBox(color: Colors.black54),
                  ),
                ),
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: const UpdatePromptSheet(),
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
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    final List<String> changes = release.changes;
    final String? error = update.error;
    final double maxHeight = MediaQuery.sizeOf(context).height * 0.8;

    // Absorb taps on the sheet so only the backdrop above it dismisses.
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {},
      child: Material(
        color: scheme.surface,
        clipBehavior: Clip.antiAlias,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: maxHeight),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                const SizedBox(height: AppSpacing.sm),
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: scheme.onSurfaceVariant.withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.lg,
                    AppSpacing.sm,
                    AppSpacing.lg,
                    AppSpacing.sm,
                  ),
                  child: Row(
                    children: <Widget>[
                      Icon(Icons.system_update_alt, color: scheme.primary),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              'Update available',
                              style: theme.textTheme.titleMedium,
                            ),
                            Text(
                              'OpenMaps ${release.versionName} is ready to '
                              'install',
                              style: theme.textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                      if (release.mandatory)
                        Chip(
                          label: const Text('Required'),
                          visualDensity: VisualDensity.compact,
                          side: BorderSide(color: scheme.outlineVariant),
                        ),
                    ],
                  ),
                ),
                if (changes.isNotEmpty)
                  Flexible(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(
                        AppSpacing.lg,
                        0,
                        AppSpacing.lg,
                        AppSpacing.sm,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            "What's new",
                            style: theme.textTheme.titleSmall?.copyWith(
                              color: scheme.primary,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          for (final String change in changes)
                            _ChangeRow(text: change),
                        ],
                      ),
                    ),
                  )
                else
                  const SizedBox(height: AppSpacing.sm),
                if (update.installing)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.lg,
                      AppSpacing.sm,
                      AppSpacing.lg,
                      0,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: <Widget>[
                        LinearProgressIndicator(
                          value: update.progress > 0 && update.progress < 1
                              ? update.progress
                              : null,
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        const Text('Downloading the update…'),
                      ],
                    ),
                  ),
                if (error != null)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.lg,
                      AppSpacing.sm,
                      AppSpacing.lg,
                      0,
                    ),
                    child: Text(error, style: TextStyle(color: scheme.error)),
                  ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.lg,
                    AppSpacing.sm,
                    AppSpacing.lg,
                    AppSpacing.md,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: <Widget>[
                      if (!update.isMandatory)
                        TextButton(
                          onPressed: update.installing
                              ? null
                              : () => unawaited(
                                  ref
                                      .read(updateControllerProvider.notifier)
                                      .dismissPrompt(),
                                ),
                          child: const Text('Later'),
                        ),
                      const SizedBox(width: AppSpacing.sm),
                      FilledButton(
                        onPressed: update.installing
                            ? null
                            : () => unawaited(
                                ref
                                    .read(updateControllerProvider.notifier)
                                    .install(),
                              ),
                        child: Text(
                          update.installing ? 'Installing…' : 'Update',
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
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.only(top: 6, right: AppSpacing.sm),
            child: Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                color: scheme.primary,
                shape: BoxShape.circle,
              ),
            ),
          ),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }
}
