import 'package:flutter/widgets.dart';

import '../../../core/errors/app_exception.dart';
import '../../../domain/entities/user_relay_lists.dart';
import '../../design/play.dart';

/// A reusable editor for the two relay lists a Nostr account needs:
/// **NIP-65** (where the user reads and writes, each relay marked inbox,
/// outbox or both) and **NIP-17 DM relays** (where the user receives encrypted
/// direct messages).
///
/// The parent decides what "save" means, so the same widget serves the sign-up
/// flow and the "Edit relays" screen.
class RelaysForm extends StatefulWidget {
  const RelaysForm({
    super.key,
    required this.relays,
    required this.onSubmit,
    this.submitLabel = 'Save',
    this.showPublicNotice = true,
  });

  final UserRelays relays;
  final Future<void> Function(UserRelays relays) onSubmit;
  final String submitLabel;
  final bool showPublicNotice;

  @override
  State<RelaysForm> createState() => _RelaysFormState();
}

class _RelaysFormState extends State<RelaysForm> {
  late final List<RelayEntry> _nip65 = List<RelayEntry>.of(widget.relays.nip65);
  late final List<String> _dm = List<String>.of(widget.relays.dm);
  final TextEditingController _nip65Input = TextEditingController();
  final TextEditingController _dmInput = TextEditingController();
  String? _nip65Error;
  String? _dmError;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _nip65Input.dispose();
    _dmInput.dispose();
    super.dispose();
  }

  void _addNip65() {
    final String value = _nip65Input.text.trim();
    final String? error = _validateRelay(value);
    if (error != null) {
      setState(() => _nip65Error = error);
      return;
    }
    setState(() {
      _nip65Error = null;
      if (!_nip65.any((RelayEntry entry) => entry.url == value)) {
        _nip65.add(RelayEntry(url: value));
      }
      _nip65Input.clear();
    });
  }

  void _addDm() {
    final String value = _dmInput.text.trim();
    final String? error = _validateRelay(value);
    if (error != null) {
      setState(() => _dmError = error);
      return;
    }
    setState(() {
      _dmError = null;
      if (!_dm.contains(value)) {
        _dm.add(value);
      }
      _dmInput.clear();
    });
  }

  Future<void> _submit() async {
    if (_busy) {
      return;
    }
    if (_nip65.isEmpty) {
      setState(() => _nip65Error = 'Keep at least one relay.');
      return;
    }
    if (_dm.isEmpty) {
      setState(() => _dmError = 'Keep at least one relay.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.onSubmit(
        UserRelays(
          nip65: List<RelayEntry>.unmodifiable(_nip65),
          dm: List<String>.unmodifiable(_dm),
        ),
      );
    } on AppException catch (error) {
      if (mounted) {
        setState(() => _error = error.message);
      }
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Could not save your relays. Try again.');
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final PlayColors colors = PlayColors.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Text(
          'NIP-65 relays',
          style: PlayType.subtitle.copyWith(color: colors.ink),
        ),
        const SizedBox(height: PlaySpace.xs),
        Text(
          'Where you publish and read notes. Mark each one as your inbox '
          '(reading), your outbox (publishing) or both.',
          style: PlayType.caption.copyWith(color: colors.inkMuted),
        ),
        const SizedBox(height: PlaySpace.sm),
        for (int i = 0; i < _nip65.length; i++) ...<Widget>[
          _RelayRow(
            url: _nip65[i].url,
            disabled: _busy,
            onRemove: () => setState(() {
              _nip65Error = null;
              _nip65.removeAt(i);
            }),
            footer: Padding(
              padding: const EdgeInsets.only(
                top: PlaySpace.xs,
                left: PlaySpace.xs,
                right: PlaySpace.xs,
              ),
              child: PlaySegmented<RelayMarker>(
                selected: _nip65[i].marker,
                onChanged: _busy
                    ? (RelayMarker _) {}
                    : (RelayMarker marker) => setState(() {
                        _nip65[i] = _nip65[i].copyWith(marker: marker);
                      }),
                segments: const <PlaySegment<RelayMarker>>[
                  PlaySegment<RelayMarker>(
                    value: RelayMarker.both,
                    label: 'Both',
                  ),
                  PlaySegment<RelayMarker>(
                    value: RelayMarker.inbox,
                    label: 'Inbox',
                  ),
                  PlaySegment<RelayMarker>(
                    value: RelayMarker.outbox,
                    label: 'Outbox',
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: PlaySpace.sm),
        ],
        _AddRelayRow(
          controller: _nip65Input,
          error: _nip65Error,
          disabled: _busy,
          onAdd: _addNip65,
          onInput: () {
            if (_nip65Error != null) {
              setState(() => _nip65Error = null);
            }
          },
        ),
        const SizedBox(height: PlaySpace.lg),
        Text(
          'Direct message relays',
          style: PlayType.subtitle.copyWith(color: colors.ink),
        ),
        const SizedBox(height: PlaySpace.xs),
        Text(
          'Where friends send you encrypted (NIP-17) messages and live '
          'locations.',
          style: PlayType.caption.copyWith(color: colors.inkMuted),
        ),
        const SizedBox(height: PlaySpace.sm),
        for (int i = 0; i < _dm.length; i++) ...<Widget>[
          _RelayRow(
            url: _dm[i],
            disabled: _busy,
            onRemove: () => setState(() {
              _dmError = null;
              _dm.removeAt(i);
            }),
          ),
          const SizedBox(height: PlaySpace.xs),
        ],
        _AddRelayRow(
          controller: _dmInput,
          error: _dmError,
          disabled: _busy,
          onAdd: _addDm,
          onInput: () {
            if (_dmError != null) {
              setState(() => _dmError = null);
            }
          },
        ),
        if (widget.showPublicNotice) ...<Widget>[
          const SizedBox(height: PlaySpace.lg),
          PlaySurface(
            radius: PlayRadii.md,
            borderWidth: 1,
            shadow: PlayShadow.none,
            backgroundColor: colors.surfaceSunken,
            padding: const EdgeInsets.all(PlaySpace.md),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Icon(PlayIcons.globe, size: 20, color: colors.inkMuted),
                const SizedBox(width: PlaySpace.sm),
                Expanded(
                  child: Text(
                    'Your relay lists are public. Anyone can see which relays '
                    'you use — that is normal and how the network finds you.',
                    style: PlayType.caption.copyWith(color: colors.inkMuted),
                  ),
                ),
              ],
            ),
          ),
        ],
        if (_error != null) ...<Widget>[
          const SizedBox(height: PlaySpace.md),
          Text(
            _error!,
            textAlign: TextAlign.center,
            style: PlayType.caption.copyWith(color: colors.coral),
          ),
        ],
        const SizedBox(height: PlaySpace.lg),
        PlayButton(
          label: widget.submitLabel,
          icon: PlayIcons.check,
          size: PlayButtonSize.lg,
          expand: true,
          onPressed: _busy ? null : _submit,
        ),
      ],
    );
  }

  /// Validates a relay URL. Returns an error message, or `null` when valid.
  static String? _validateRelay(String value) {
    if (value.isEmpty) {
      return 'Enter a relay URL.';
    }
    if (!value.startsWith('wss://') && !value.startsWith('ws://')) {
      return 'A relay URL starts with wss:// or ws://';
    }
    final Uri? uri = Uri.tryParse(value);
    if (uri == null || uri.host.isEmpty) {
      return 'That does not look like a valid relay URL.';
    }
    return null;
  }
}

/// The URL field + Add button for one relay list.
class _AddRelayRow extends StatelessWidget {
  const _AddRelayRow({
    required this.controller,
    required this.error,
    required this.disabled,
    required this.onAdd,
    required this.onInput,
  });

  final TextEditingController controller;
  final String? error;
  final bool disabled;
  final VoidCallback onAdd;
  final VoidCallback onInput;

  @override
  Widget build(BuildContext context) {
    final PlayColors colors = PlayColors.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(
              child: PlayTextField(
                controller: controller,
                hint: 'wss://…',
                clearable: false,
                onSubmitted: (String _) => onAdd(),
                onChanged: (String _) => onInput(),
              ),
            ),
            const SizedBox(width: PlaySpace.sm),
            PlayButton(
              label: 'Add',
              icon: PlayIcons.add,
              variant: PlayButtonVariant.ghost,
              size: PlayButtonSize.sm,
              onPressed: disabled ? null : onAdd,
            ),
          ],
        ),
        if (error != null) ...<Widget>[
          const SizedBox(height: PlaySpace.xs),
          Text(error!, style: PlayType.caption.copyWith(color: colors.coral)),
        ],
      ],
    );
  }
}

class _RelayRow extends StatelessWidget {
  const _RelayRow({
    required this.url,
    required this.disabled,
    required this.onRemove,
    this.footer,
  });

  final String url;
  final bool disabled;
  final VoidCallback onRemove;
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    final PlayColors colors = PlayColors.of(context);
    return PlaySurface(
      radius: PlayRadii.md,
      borderWidth: 1,
      shadow: PlayShadow.none,
      padding: const EdgeInsets.fromLTRB(
        PlaySpace.md,
        PlaySpace.xs,
        PlaySpace.xs,
        PlaySpace.sm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(PlayIcons.globe, size: 18, color: colors.inkMuted),
              const SizedBox(width: PlaySpace.sm),
              Expanded(
                child: Text(
                  url,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: PlayType.body.copyWith(color: colors.ink),
                ),
              ),
              PlayIconButton(
                icon: PlayIcons.close,
                variant: PlayIconButtonVariant.plain,
                size: 36,
                iconSize: 16,
                semanticLabel: 'Remove relay',
                onPressed: disabled ? null : onRemove,
              ),
            ],
          ),
          ?footer,
        ],
      ),
    );
  }
}

@PlayPreview(name: 'RelaysForm', size: Size(440, 620))
Widget relaysFormPreview() {
  return PlayPreviewFrame(
    child: SingleChildScrollView(
      child: RelaysForm(
        relays: const UserRelays(
          nip65: <RelayEntry>[
            RelayEntry(
              url: 'wss://relay.map.camelus.app',
              marker: RelayMarker.both,
            ),
            RelayEntry(url: 'wss://nos.lol', marker: RelayMarker.inbox),
            RelayEntry(
              url: 'wss://relay.primal.net',
              marker: RelayMarker.outbox,
            ),
          ],
          dm: <String>['wss://relay.map.camelus.app'],
        ),
        onSubmit: (UserRelays _) async {},
      ),
    ),
  );
}
