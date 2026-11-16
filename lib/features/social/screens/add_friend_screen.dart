import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:phosphor_icons/phosphor_icons.dart';

import '../../../core/errors/app_exception.dart';
import '../../../domain/entities/friend.dart';
import '../../../state/commands/commands_provider.dart';
import '../../../state/ports.dart';
import '../../../state/social.dart';
import '../../design/play.dart';
import '../widgets/friend_avatar.dart';
import '../widgets/qr_code_view.dart';

/// Add a friend (`/friends/add`), in two tabs:
///
/// * **My code** — the signed-in profile with a scannable QR of the user's npub.
/// * **Scan** — the camera, plus a paste field so it also works without one.
class AddFriendScreen extends StatefulWidget {
  const AddFriendScreen({super.key, this.cameraBuilder});

  /// Test seam: builds the camera preview and reports a scanned raw value.
  final Widget Function(BuildContext context, void Function(String raw))?
  cameraBuilder;

  @override
  State<AddFriendScreen> createState() => _AddFriendScreenState();
}

class _AddFriendScreenState extends State<AddFriendScreen> {
  final PageController _pages = PageController();
  int _tab = 0;

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  void _select(int index) {
    setState(() => _tab = index);
    _pages.animateToPage(
      index,
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    return PlayScaffold(
      appBar: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          const PlayAppBar(title: 'Add friend'),
          PlayTabs(
            tabs: const <String>['My code', 'Scan'],
            selectedIndex: _tab,
            onSelected: _select,
          ),
        ],
      ),
      child: PageView(
        controller: _pages,
        onPageChanged: (int index) => setState(() => _tab = index),
        children: <Widget>[
          const _MyCodeTab(),
          _ScanTab(cameraBuilder: widget.cameraBuilder),
        ],
      ),
    );
  }
}

/// The user's own identity as a QR code a friend can scan.
class _MyCodeTab extends ConsumerWidget {
  const _MyCodeTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final PlayColors colors = PlayColors.of(context);
    final String? pubkey = ref.watch(nostrPubkeyProvider).value;
    final String? npub = pubkey == null
        ? null
        : ref.read(socialServiceProvider).encodeNpub(pubkey);

    if (pubkey == null || npub == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(PlaySpace.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(
                PhosphorIconsRegular.qrCode,
                size: 56,
                color: colors.inkFaint,
              ),
              const SizedBox(height: PlaySpace.md),
              Text(
                'Sign in to show your code',
                style: PlayType.subtitle.copyWith(color: colors.ink),
              ),
              const SizedBox(height: PlaySpace.xs),
              Text(
                'Your friends add you by scanning your Nostr public key.',
                textAlign: TextAlign.center,
                style: PlayType.caption.copyWith(color: colors.inkMuted),
              ),
              const SizedBox(height: PlaySpace.lg),
              PlayButton(
                label: 'Sign in with Nostr',
                onPressed: () => context.push('/profile'),
              ),
            ],
          ),
        ),
      );
    }

    final Friend? profile = ref.watch(myProfileProvider).value;
    final String name = profile?.label ?? 'You';

    return ListView(
      padding: const EdgeInsets.all(PlaySpace.lg),
      children: <Widget>[
        Row(
          children: <Widget>[
            FriendAvatar(
              label: name,
              pictureUrl: profile?.pictureUrl,
              size: 56,
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
                  Text(
                    'Let a friend scan this to add you',
                    style: PlayType.caption.copyWith(color: colors.inkMuted),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: PlaySpace.lg),
        Center(
          child: PlaySurface(
            radius: PlayRadii.md,
            borderWidth: 1,
            shadow: PlayShadow.none,
            padding: const EdgeInsets.all(PlaySpace.md),
            child: QrCodeView(data: npub, size: 240),
          ),
        ),
        const SizedBox(height: PlaySpace.lg),
        Text(
          'YOUR PUBLIC KEY',
          style: PlayType.overline.copyWith(color: colors.inkMuted),
        ),
        const SizedBox(height: PlaySpace.xs),
        SelectableRegion(
          selectionControls: emptyTextSelectionControls,
          child: Text(
            npub,
            style: PlayType.caption.copyWith(
              color: colors.inkMuted,
              fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
            ),
          ),
        ),
        const SizedBox(height: PlaySpace.sm),
        PlayButton(
          label: 'Copy my public key',
          icon: PlayIcons.copy,
          variant: PlayButtonVariant.ghost,
          onPressed: () => unawaited(_copy(context, npub)),
        ),
        const SizedBox(height: PlaySpace.md),
        Text(
          'This is your public key — it is safe to share. Your private key never '
          'leaves this device.',
          style: PlayType.caption.copyWith(color: colors.inkMuted),
        ),
      ],
    );
  }

  Future<void> _copy(BuildContext context, String npub) async {
    try {
      await Clipboard.setData(ClipboardData(text: npub));
      if (context.mounted) {
        showPlayToast(context, 'Public key copied');
      }
    } catch (_) {
      // Clipboard is best-effort (unavailable in some test environments).
    }
  }
}

/// Camera + paste entry for adding someone else.
class _ScanTab extends ConsumerStatefulWidget {
  const _ScanTab({this.cameraBuilder});

  final Widget Function(BuildContext context, void Function(String raw))?
  cameraBuilder;

  @override
  ConsumerState<_ScanTab> createState() => _ScanTabState();
}

class _ScanTabState extends ConsumerState<_ScanTab>
    with AutomaticKeepAliveClientMixin {
  final TextEditingController _manual = TextEditingController();
  final MobileScannerController _controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
  );
  bool _handled = false;
  bool _adding = false;
  String? _error;

  /// True when a test stub replaced the real camera (so we never touch the
  /// platform controller).
  bool get _cameraBuilderIsStub => widget.cameraBuilder != null;

  @override
  bool get wantKeepAlive => true;

  @override
  void dispose() {
    // A test stub never touched the platform controller, so there is nothing to
    // release (and no channel to fail on teardown).
    if (!_cameraBuilderIsStub) {
      unawaited(_controller.dispose());
    }
    _manual.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final PlayColors colors = PlayColors.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        // The camera fills the free space; the input stays pinned below so it
        // is always reachable without scrolling.
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              PlaySpace.lg,
              PlaySpace.lg,
              PlaySpace.lg,
              PlaySpace.sm,
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(PlayRadii.lg),
              child:
                  widget.cameraBuilder?.call(context, _onScanned) ??
                  _camera(context),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(
            PlaySpace.lg,
            PlaySpace.xs,
            PlaySpace.lg,
            PlaySpace.lg,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Text(
                'Point the camera at your friend\'s Nostr public key (npub) QR '
                'code, or paste the key below.',
                style: PlayType.caption.copyWith(color: colors.inkMuted),
              ),
              const SizedBox(height: PlaySpace.sm),
              PlayTextField(
                controller: _manual,
                hint: 'npub or hex public key',
                onSubmitted: (String value) => unawaited(_add(value)),
              ),
              if (_error != null) ...<Widget>[
                const SizedBox(height: PlaySpace.xs),
                Text(
                  _error!,
                  style: PlayType.caption.copyWith(color: colors.coral),
                ),
              ],
              const SizedBox(height: PlaySpace.sm),
              PlayButton(
                label: 'Add this friend',
                icon: PhosphorIconsRegular.userPlus,
                expand: true,
                onPressed: _adding ? null : () => unawaited(_add(_manual.text)),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _camera(BuildContext context) {
    return MobileScanner(
      controller: _controller,
      errorBuilder: (BuildContext context, MobileScannerException error) {
        return _CameraUnavailable(message: error.errorDetails?.message);
      },
      onDetect: (BarcodeCapture capture) {
        for (final Barcode barcode in capture.barcodes) {
          final String? raw = barcode.rawValue;
          if (raw != null && raw.isNotEmpty) {
            _onScanned(raw);
            return;
          }
        }
      },
    );
  }

  /// Handles a scanned (or pasted) value exactly once.
  void _onScanned(String raw) {
    if (_handled || _adding) {
      return;
    }
    setState(() => _manual.text = raw);
    unawaited(_add(raw));
  }

  Future<void> _add(String input) async {
    if (_adding) {
      return;
    }
    final String? pubkey = ref
        .read(socialServiceProvider)
        .normalizePubkey(input);
    if (pubkey == null) {
      setState(() {
        _handled = false;
        _error = input.trim().isEmpty
            ? 'Scan or paste a Nostr public key.'
            : 'That is not a Nostr public key (npub… or 64 hex characters).';
      });
      return;
    }
    setState(() {
      _adding = true;
      _error = null;
    });
    if (!_cameraBuilderIsStub) {
      unawaited(_controller.stop());
    }
    try {
      await ref.read(commandRegistryProvider).dispatch(
        'social.friend.add',
        <String, Object?>{'pubkey': pubkey},
      );
      _handled = true;
      if (mounted) {
        // Stop the button spinner before the screen leaves (and so a screen
        // that stays mounted settles instead of animating forever).
        setState(() => _adding = false);
        showPlayToast(context, 'Friend added');
        if (Navigator.of(context).canPop()) {
          Navigator.of(context).pop(true);
        }
      }
    } on AppException catch (error) {
      if (mounted) {
        setState(() {
          _adding = false;
          _handled = false;
          _error = error.message;
        });
      }
    }
  }
}

class _CameraUnavailable extends StatelessWidget {
  const _CameraUnavailable({this.message});

  final String? message;

  @override
  Widget build(BuildContext context) {
    final PlayColors colors = PlayColors.of(context);
    return ColoredBox(
      color: colors.surfaceSunken,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(PlaySpace.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(
                PhosphorIconsRegular.cameraSlash,
                size: 40,
                color: colors.inkFaint,
              ),
              const SizedBox(height: PlaySpace.sm),
              Text(
                'Camera unavailable',
                style: PlayType.bodyStrong.copyWith(color: colors.ink),
              ),
              const SizedBox(height: PlaySpace.xs),
              Text(
                message ??
                    'This device has no usable camera. Paste the npub below '
                        'instead.',
                textAlign: TextAlign.center,
                style: PlayType.caption.copyWith(color: colors.inkMuted),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
