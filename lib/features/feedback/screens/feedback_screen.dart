import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/config/app_config.dart';
import '../../../domain/usecases/send_feedback.dart';
import '../../../state/config.dart';
import '../../../state/feedback.dart';
import '../../../state/screenshot.dart';
import '../../../state/social.dart';
import '../../common/navigation.dart';
import '../../design/play.dart';

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
    final PlayColors colors = PlayColors.of(context);
    final AppConfig config = ref.watch(appConfigProvider);
    final bool configured = config.hasFeedbackPubkey;
    final bool signedIn = ref.watch(nostrPubkeyProvider).value != null;
    final FeedbackState state = ref.watch(feedbackControllerProvider);

    ref.listen<FeedbackState>(feedbackControllerProvider, (
      FeedbackState? previous,
      FeedbackState next,
    ) {
      if (next.isSent) {
        showPlayToast(context, 'Thanks! Your feedback was sent.');
        popOrHome(context);
      }
    });

    final bool canSend =
        configured &&
        _screenshot != null &&
        !state.isSending &&
        _controller.text.trim().isNotEmpty;
    final String? error = state.error;

    return PlayScaffold(
      appBar: const PlayAppBar(title: 'Send feedback'),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(
          PlaySpace.lg,
          PlaySpace.sm,
          PlaySpace.lg,
          PlaySpace.xxl,
        ),
        children: <Widget>[
          Text.rich(
            TextSpan(
              style: PlayType.body.copyWith(color: colors.ink),
              children: const <TextSpan>[
                TextSpan(
                  text:
                      'Your report goes straight to the OpenMaps team end-to-end encrypted. '
                      'Please describe your issue and add a user story.\n\n',
                ),
                TextSpan(text: 'Example user story: '),
                TextSpan(text: '“As a '),
                TextSpan(
                  text: 'user',
                  style: TextStyle(fontStyle: FontStyle.italic),
                ),
                TextSpan(text: ', I want to be able to '),
                TextSpan(
                  text: 'see my location on the map',
                  style: TextStyle(fontStyle: FontStyle.italic),
                ),
                TextSpan(text: ' so that I can '),
                TextSpan(
                  text: 'navigate easily',
                  style: TextStyle(fontStyle: FontStyle.italic),
                ),
                TextSpan(text: '.”'),
              ],
            ),
          ),
          const SizedBox(height: PlaySpace.lg),
          _ScreenshotPreview(screenshot: _screenshot, capturing: _capturing),
          const SizedBox(height: PlaySpace.lg),
          PlayTextField(
            controller: _controller,
            minLines: 4,
            maxLines: 8,
            maxLength: SendFeedback.maxMessageLength,
            textCapitalization: TextCapitalization.sentences,
            hint: 'What happened?\nWhat did you expect?\nUser Story',
            onChanged: (_) => setState(() {}),
          ),
          if (!configured) ...<Widget>[
            const SizedBox(height: PlaySpace.sm),
            const _Notice(
              icon: PlayIcons.info,
              text:
                  'Feedback isn\'t set up in this build — no recipient key '
                  'was configured.',
            ),
          ] else if (!signedIn) ...<Widget>[
            const SizedBox(height: PlaySpace.sm),
            _Notice(
              icon: PlayIcons.private,
              text:
                  'You are not signed in, so this report is sent from an '
                  'anonymous identity.',
              action: PlayButton(
                label: 'Sign in',
                variant: PlayButtonVariant.ghost,
                size: PlayButtonSize.sm,
                onPressed: () => context.push('/profile'),
              ),
            ),
          ],
          if (error != null) ...<Widget>[
            const SizedBox(height: PlaySpace.sm),
            Text(error, style: PlayType.body.copyWith(color: colors.coral)),
          ],
          const SizedBox(height: PlaySpace.lg),
          PlayButton(
            label: state.isSending ? 'Sending…' : 'Send',
            icon: PlayIcons.send,
            iconWidget: state.isSending
                ? const PlaySpinner(size: 18, strokeWidth: 2)
                : null,
            expand: true,
            onPressed: canSend ? _send : null,
          ),
        ],
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
    final PlayColors colors = PlayColors.of(context);
    final Uint8List? bytes = screenshot;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          'Screenshot',
          style: PlayType.bodyStrong.copyWith(color: colors.ink),
        ),
        const SizedBox(height: PlaySpace.xs),
        PlaySurface(
          tone: PlayTone.sunken,
          radius: PlayRadii.md,
          shadow: PlayShadow.none,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(PlayRadii.md),
            child: SizedBox(
              height: 300,
              width: double.infinity,
              child: bytes != null
                  ? Image.memory(
                      bytes,
                      fit: BoxFit.contain,
                      alignment: Alignment.topCenter,
                      width: double.infinity,
                    )
                  : Center(
                      child: capturing
                          ? const PlaySpinner()
                          : Icon(PlayIcons.brokenImage, color: colors.inkMuted),
                    ),
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
    final PlayColors colors = PlayColors.of(context);
    final Widget? trailing = action;
    return PlaySurface(
      tone: PlayTone.sunken,
      radius: PlayRadii.md,
      shadow: PlayShadow.none,
      padding: const EdgeInsets.symmetric(
        horizontal: PlaySpace.md,
        vertical: PlaySpace.sm,
      ),
      child: Row(
        children: <Widget>[
          Icon(icon, size: 20, color: colors.inkMuted),
          const SizedBox(width: PlaySpace.sm),
          Expanded(
            child: Text(text, style: PlayType.body.copyWith(color: colors.ink)),
          ),
          ?trailing,
        ],
      ),
    );
  }
}
