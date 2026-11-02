import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../../core/errors/app_exception.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../domain/entities/friend.dart';
import '../../../state/commands/commands_provider.dart';
import '../../../state/ports.dart';
import '../../../state/social.dart';
import '../widgets/friend_avatar.dart';
import '../widgets/qr_code_view.dart';

/// Add a friend (`/friends/add`), in two tabs:
///
/// * **My code** — the signed-in profile with a scannable QR of the user's npub.
/// * **Scan** — the camera, plus a paste field so it also works without one.
class AddFriendScreen extends StatelessWidget {
  const AddFriendScreen({super.key, this.cameraBuilder});

  /// Test seam: builds the camera preview and reports a scanned raw value.
  final Widget Function(BuildContext context, void Function(String raw))?
  cameraBuilder;

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Add friend'),
          bottom: const TabBar(
            tabs: <Widget>[
              Tab(text: 'My code'),
              Tab(text: 'Scan'),
            ],
          ),
        ),
        body: TabBarView(
          children: <Widget>[
            const _MyCodeTab(),
            _ScanTab(cameraBuilder: cameraBuilder),
          ],
        ),
      ),
    );
  }
}

/// The user's own identity as a QR code a friend can scan.
class _MyCodeTab extends ConsumerWidget {
  const _MyCodeTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ThemeData theme = Theme.of(context);
    final String? pubkey = ref.watch(nostrPubkeyProvider).value;
    final String? npub = pubkey == null
        ? null
        : ref.read(socialServiceProvider).encodeNpub(pubkey);

    if (pubkey == null || npub == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(Icons.qr_code_2, size: 56, color: theme.colorScheme.outline),
              const SizedBox(height: AppSpacing.md),
              Text(
                'Sign in to show your code',
                style: theme.textTheme.titleMedium,
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'Your friends add you by scanning your Nostr public key.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall,
              ),
              const SizedBox(height: AppSpacing.lg),
              FilledButton(
                onPressed: () => context.push('/profile'),
                child: const Text('Sign in with Nostr'),
              ),
            ],
          ),
        ),
      );
    }

    final Friend? profile = ref.watch(myProfileProvider).value;
    final String name = profile?.label ?? 'You';

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.md),
      children: <Widget>[
        Row(
          children: <Widget>[
            FriendAvatar(
              label: name,
              pictureUrl: profile?.pictureUrl,
              size: 56,
              borderColor: theme.colorScheme.primary,
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    name,
                    style: theme.textTheme.titleLarge,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    'Let a friend scan this to add you',
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),
        Center(
          child: Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(AppSpacing.sheetRadius),
              border: Border.all(color: theme.colorScheme.outlineVariant),
            ),
            child: QrCodeView(data: npub, size: 240),
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        Text(
          'YOUR PUBLIC KEY',
          style: theme.textTheme.labelSmall?.copyWith(
            letterSpacing: 0.8,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        SelectableText(
          npub,
          style: theme.textTheme.bodySmall?.copyWith(
            fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        OutlinedButton.icon(
          onPressed: () => unawaited(_copy(context, npub)),
          icon: const Icon(Icons.copy_all_outlined),
          label: const Text('Copy my public key'),
        ),
        const SizedBox(height: AppSpacing.md),
        Text(
          'This is your public key — it is safe to share. Your private key never '
          'leaves this device.',
          style: theme.textTheme.bodySmall,
        ),
      ],
    );
  }

  Future<void> _copy(BuildContext context, String npub) async {
    try {
      await Clipboard.setData(ClipboardData(text: npub));
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Public key copied')));
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
    final ThemeData theme = Theme.of(context);
    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          // The camera fills the free space; the input stays pinned below so it
          // is always reachable without scrolling.
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.md,
                AppSpacing.md,
                AppSpacing.md,
                AppSpacing.sm,
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(AppSpacing.sheetRadius),
                child:
                    widget.cameraBuilder?.call(context, _onScanned) ??
                    _camera(context),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              AppSpacing.xs,
              AppSpacing.md,
              AppSpacing.md,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Text(
                  'Point the camera at your friend\'s Nostr public key (npub) QR '
                  'code, or paste the key below.',
                  style: theme.textTheme.bodySmall,
                ),
                const SizedBox(height: AppSpacing.sm),
                TextField(
                  controller: _manual,
                  autocorrect: false,
                  decoration: const InputDecoration(
                    labelText: 'npub or hex public key',
                    border: OutlineInputBorder(),
                  ),
                  onSubmitted: (String value) => unawaited(_add(value)),
                ),
                if (_error != null) ...<Widget>[
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    _error!,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.error,
                    ),
                  ),
                ],
                const SizedBox(height: AppSpacing.sm),
                FilledButton.icon(
                  onPressed: _adding
                      ? null
                      : () => unawaited(_add(_manual.text)),
                  icon: _adding
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.person_add_alt),
                  label: const Text('Add this friend'),
                ),
              ],
            ),
          ),
        ],
      ),
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
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Friend added')));
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
    final ThemeData theme = Theme.of(context);
    return ColoredBox(
      color: theme.colorScheme.surfaceContainerHighest,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(
                Icons.no_photography_outlined,
                size: 40,
                color: theme.colorScheme.outline,
              ),
              const SizedBox(height: AppSpacing.sm),
              Text('Camera unavailable', style: theme.textTheme.titleSmall),
              const SizedBox(height: AppSpacing.xs),
              Text(
                message ??
                    'This device has no usable camera. Paste the npub below '
                        'instead.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
