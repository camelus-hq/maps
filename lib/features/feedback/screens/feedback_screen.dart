import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/config/app_config.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../domain/usecases/send_feedback.dart';
import '../../../state/config.dart';
import '../../../state/feedback.dart';
import '../../../state/screenshot.dart';
import '../../../state/social.dart';
import '../../common/navigation.dart';

/// The feedback screen (`/feedback`): shows the screenshot the banner captured
/// and a text field, then sends both as one private, end-to-end encrypted Nostr
/// message to the configured maintainer key. A signed-in user sends as their
/// own account; otherwise the report goes out from the app's persistent
/// anonymous identity, so signing in is optional.
class FeedbackScreen extends ConsumerStatefulWidget {
  const FeedbackScreen({this.screenshot, super.key});

  /// The screen captured when the feedback form was opened. `null` only when the
  /// route is reached without a capture (a deep link), in which case the screen
  /// captures itself so a report can still be sent.
  final Uint8List? screenshot;

  @override
  ConsumerState<FeedbackScreen> createState() => _FeedbackScreenState();
}

class _FeedbackScreenState extends ConsumerState<FeedbackScreen> {
  final TextEditingController _controller = TextEditingController();
  Uint8List? _screenshot;
  bool _capturing = false;

  @override
  void initState() {
    super.initState();
    _screenshot = widget.screenshot;
    if (_screenshot == null) {
      unawaited(_capture());
    }
    // Clear a previous send's result so reopening the screen starts fresh.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      ref.read(feedbackControllerProvider.notifier).reset();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _capture() async {
    setState(() => _capturing = true);
    try {
      final Uint8List bytes = await ref.read(screenshotCaptureProvider)();
      if (!mounted) {
        return;
      }
      setState(() {
        _screenshot = bytes;
        _capturing = false;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() => _capturing = false);
    }
  }

  void _send() {
    final Uint8List? screenshot = _screenshot;
    if (screenshot == null) {
      return;
    }
    unawaited(
      ref
          .read(feedbackControllerProvider.notifier)
          .send(message: _controller.text, screenshot: screenshot),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final AppConfig config = ref.watch(appConfigProvider);
    final bool configured = config.hasFeedbackPubkey;
    final bool signedIn = ref.watch(nostrPubkeyProvider).value != null;
    final FeedbackState state = ref.watch(feedbackControllerProvider);

    ref.listen<FeedbackState>(feedbackControllerProvider, (
      FeedbackState? previous,
      FeedbackState next,
    ) {
      if (next.isSent) {
        final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
        popOrHome(context);
        messenger.showSnackBar(
          const SnackBar(content: Text('Thanks! Your feedback was sent.')),
        );
      }
    });

    final bool canSend =
        configured &&
        _screenshot != null &&
        !state.isSending &&
        _controller.text.trim().isNotEmpty;

    return Scaffold(
      appBar: AppBar(title: const Text('Send feedback')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.md),
          children: <Widget>[
            Text.rich(
              TextSpan(
                style: theme.textTheme.bodyMedium,
                children: <TextSpan>[
                  const TextSpan(
                    text:
                        'Your report goes straight to the OpenMaps team end-to-end encrypted. '
                        'Please describe your issue and add a user story.\n\n',
                  ),
                  const TextSpan(text: 'Example user story: '),
                  const TextSpan(text: '“As a '),
                  const TextSpan(
                    text: 'user',
                    style: TextStyle(fontStyle: FontStyle.italic),
                  ),
                  const TextSpan(text: ', I want to be able to '),
                  const TextSpan(
                    text: 'see my location on the map',
                    style: TextStyle(fontStyle: FontStyle.italic),
                  ),
                  const TextSpan(text: ' so that I can '),
                  const TextSpan(
                    text: 'navigate easily',
                    style: TextStyle(fontStyle: FontStyle.italic),
                  ),
                  const TextSpan(text: '.”'),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            _ScreenshotPreview(screenshot: _screenshot, capturing: _capturing),
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: _controller,
              minLines: 4,
              maxLines: 8,
              maxLength: SendFeedback.maxMessageLength,
              textCapitalization: TextCapitalization.sentences,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                hintText: 'What happened?\nWhat did you expect?\nUser Story',
                border: OutlineInputBorder(),
                alignLabelWithHint: true,
              ),
            ),
            if (!configured) ...<Widget>[
              const SizedBox(height: AppSpacing.sm),
              _Notice(
                icon: Icons.info_outline,
                text:
                    'Feedback isn\'t set up in this build — no recipient key '
                    'was configured.',
              ),
            ] else if (!signedIn) ...<Widget>[
              const SizedBox(height: AppSpacing.sm),
              _Notice(
                icon: Icons.visibility_off_outlined,
                text:
                    'You are not signed in, so this report is sent from an '
                    'anonymous identity.',
                action: TextButton(
                  onPressed: () => context.push('/profile'),
                  child: const Text('Sign in'),
                ),
              ),
            ],
            if (state.error != null) ...<Widget>[
              const SizedBox(height: AppSpacing.sm),
              Text(
                state.error!,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.error,
                ),
              ),
            ],
            const SizedBox(height: AppSpacing.md),
            FilledButton.icon(
              onPressed: canSend ? _send : null,
              icon: state.isSending
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.send),
              label: Text(state.isSending ? 'Sending…' : 'Send'),
            ),
          ],
        ),
      ),
    );
  }
}

/// The attached screenshot, or a placeholder while it is being captured.
class _ScreenshotPreview extends StatelessWidget {
  const _ScreenshotPreview({required this.screenshot, required this.capturing});

  final Uint8List? screenshot;
  final bool capturing;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final Uint8List? bytes = screenshot;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text('Screenshot', style: theme.textTheme.labelLarge),
        const SizedBox(height: AppSpacing.xs),
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Container(
            height: 300,
            width: double.infinity,
            color: theme.colorScheme.surfaceContainerHighest,
            alignment: Alignment.center,
            child: bytes != null
                ? Image.memory(
                    bytes,
                    fit: BoxFit.contain,
                    alignment: Alignment.topCenter,
                    width: double.infinity,
                  )
                : capturing
                ? const CircularProgressIndicator()
                : Icon(
                    Icons.image_not_supported_outlined,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
          ),
        ),
      ],
    );
  }
}

/// An inline informational row (with an optional trailing action).
class _Notice extends StatelessWidget {
  const _Notice({required this.icon, required this.text, this.action});

  final IconData icon;
  final String text;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: <Widget>[
          Icon(icon, size: 20, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(width: AppSpacing.sm),
          Expanded(child: Text(text, style: theme.textTheme.bodyMedium)),
          if (action case final Widget trailing) trailing,
        ],
      ),
    );
  }
}
