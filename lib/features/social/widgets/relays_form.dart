import 'package:flutter/widgets.dart';

import '../../../core/errors/app_exception.dart';
import '../../../domain/entities/user_relay_lists.dart';
import '../../design/play.dart';

/// A reusable editor for the two relay lists a Nostr account needs:
/// **NIP-65** (where the user reads and writes) and **NIP-17 DM relays** (where
/// the user receives encrypted direct messages).
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
  late final List<String> _nip65 = List<String>.of(widget.relays.nip65);
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

  void _add(
    List<String> target,
    TextEditingController controller,
    void Function(String?) setError,
  ) {
    final String value = controller.text.trim();
    final String? error = _validateRelay(value);
    if (error != null) {
      setState(() => setError(error));
      return;
    }
    setState(() {
      setError(null);
      if (!target.contains(value)) {
        target.add(value);
      }
      controller.clear();
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
          nip65: List<String>.unmodifiable(_nip65),
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
        _section(
          context,
          title: 'NIP-65 relays',
          subtitle:
              'Where you publish and read notes. Most clients use this list to '
              'find you.',
          relays: _nip65,
          controller: _nip65Input,
          error: _nip65Error,
          onAdd: () =>
              _add(_nip65, _nip65Input, (String? value) => _nip65Error = value),
          onInput: () {
            if (_nip65Error != null) {
              setState(() => _nip65Error = null);
            }
          },
          onRemove: (int index) => setState(() {
            _nip65Error = null;
            _nip65.removeAt(index);
          }),
        ),
        const SizedBox(height: PlaySpace.lg),
        _section(
          context,
          title: 'Direct message relays',
          subtitle:
              'Where friends send you encrypted (NIP-17) messages and live '
              'locations.',
          relays: _dm,
          controller: _dmInput,
          error: _dmError,
          onAdd: () => _add(_dm, _dmInput, (String? value) => _dmError = value),
          onInput: () {
            if (_dmError != null) {
              setState(() => _dmError = null);
            }
          },
          onRemove: (int index) => setState(() {
            _dmError = null;
            _dm.removeAt(index);
          }),
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

  Widget _section(
    BuildContext context, {
    required String title,
    required String subtitle,
    required List<String> relays,
    required TextEditingController controller,
    required String? error,
    required VoidCallback onAdd,
    required VoidCallback onInput,
    required ValueChanged<int> onRemove,
  }) {
    final PlayColors colors = PlayColors.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Text(title, style: PlayType.subtitle.copyWith(color: colors.ink)),
        const SizedBox(height: PlaySpace.xs),
        Text(
          subtitle,
          style: PlayType.caption.copyWith(color: colors.inkMuted),
        ),
        const SizedBox(height: PlaySpace.sm),
        for (int i = 0; i < relays.length; i++) ...<Widget>[
          _RelayRow(
            url: relays[i],
            disabled: _busy,
            onRemove: () => onRemove(i),
          ),
          const SizedBox(height: PlaySpace.xs),
        ],
        const SizedBox(height: PlaySpace.xs),
        Row(
          children: <Widget>[
            Expanded(
              child: PlayTextField(
                controller: controller,
                hint: 'wss://…',
                obscureText: false,
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
              onPressed: _busy ? null : onAdd,
            ),
          ],
        ),
        if (error != null) ...<Widget>[
          const SizedBox(height: PlaySpace.xs),
          Text(error, style: PlayType.caption.copyWith(color: colors.coral)),
        ],
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

class _RelayRow extends StatelessWidget {
  const _RelayRow({
    required this.url,
    required this.disabled,
    required this.onRemove,
  });

  final String url;
  final bool disabled;
  final VoidCallback onRemove;

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
        PlaySpace.xs,
      ),
      child: Row(
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
    );
  }
}

@PlayPreview(name: 'RelaysForm', size: Size(440, 560))
Widget relaysFormPreview() {
  return PlayPreviewFrame(
    child: SingleChildScrollView(
      child: RelaysForm(
        relays: const UserRelays(
          nip65: <String>['wss://relay.map.camelus.app'],
          dm: <String>['wss://relay.map.camelus.app'],
        ),
        onSubmit: (UserRelays _) async {},
      ),
    ),
  );
}
