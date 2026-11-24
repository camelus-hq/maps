import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../../../core/errors/app_exception.dart';
import '../../../domain/entities/user_profile.dart';
import '../../design/play.dart';
import 'profile_avatar_field.dart';

/// What a [ProfileForm] hands to its `onSubmit`: the edited profile plus an
/// optional freshly-picked picture (already rendered to a square PNG).
class ProfileSubmission {
  const ProfileSubmission({
    required this.profile,
    this.pictureBytes,
    this.pictureMimeType,
  });

  final UserProfile profile;
  final Uint8List? pictureBytes;
  final String? pictureMimeType;
}

/// The reusable profile editor: a picture field (pick / zoom / preview), a name
/// and a bio, the public-information notice, and a submit button.
///
/// It owns only the draft (text controllers, picture draft, busy/error state);
/// the parent decides what "save" means, so the same widget serves both the
/// sign-up flow and the "Edit profile" screen.
class ProfileForm extends StatefulWidget {
  const ProfileForm({
    super.key,
    required this.profile,
    required this.onSubmit,
    this.submitLabel = 'Save',
    this.showPublicNotice = true,
  });

  /// The profile loaded from the network (or empty for a new account).
  final UserProfile profile;

  /// Called with the draft on submit; the returned future is awaited and its
  /// errors shown inline.
  final Future<void> Function(ProfileSubmission submission) onSubmit;

  final String submitLabel;
  final bool showPublicNotice;

  @override
  State<ProfileForm> createState() => _ProfileFormState();
}

class _ProfileFormState extends State<ProfileForm> {
  late final TextEditingController _name = TextEditingController(
    text: widget.profile.name,
  );
  late final TextEditingController _about = TextEditingController(
    text: widget.profile.about,
  );
  AvatarDraft? _draft;
  bool _pictureRemoved = false;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _name.addListener(_onTextChanged);
    _about.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    _name.removeListener(_onTextChanged);
    _about.removeListener(_onTextChanged);
    _name.dispose();
    _about.dispose();
    super.dispose();
  }

  void _onTextChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  void _onPictureChanged(AvatarDraft? draft) {
    setState(() {
      _draft = draft;
      _pictureRemoved = draft == null;
    });
  }

  Future<void> _submit() async {
    if (_busy) {
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      Uint8List? bytes;
      String? mime;
      final AvatarDraft? draft = _draft;
      if (draft != null) {
        try {
          bytes = await renderProfileAvatar(
            draft.bytes,
            zoom: draft.zoom,
            offset: draft.offset,
          );
          mime = 'image/png';
        } catch (_) {
          if (mounted) {
            setState(() {
              _busy = false;
              _error = 'Could not read that image. Try another one.';
            });
          }
          return;
        }
      }
      UserProfile profile = UserProfile(
        name: _name.text,
        about: _about.text,
        pictureUrl: widget.profile.pictureUrl,
      );
      if (_pictureRemoved) {
        profile = profile.copyWith(clearPicture: true);
      }
      await widget.onSubmit(
        ProfileSubmission(
          profile: profile,
          pictureBytes: bytes,
          pictureMimeType: mime,
        ),
      );
    } on AppException catch (error) {
      if (mounted) {
        setState(() => _error = error.message);
      }
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Could not save your profile. Try again.');
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
    final String name = _name.text.trim();
    final Widget avatar = ProfileAvatarField(
      label: name.isEmpty ? widget.profile.name : name,
      imageUrl: _pictureRemoved ? null : widget.profile.pictureUrl,
      draft: _draft,
      busy: _busy,
      onChanged: _onPictureChanged,
    );
    final Widget fields = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        _label(context, 'Name'),
        const SizedBox(height: PlaySpace.xs),
        PlayTextField(
          controller: _name,
          hint: 'Your name',
          maxLength: UserProfile.maxNameLength,
          textCapitalization: TextCapitalization.words,
        ),
        const SizedBox(height: PlaySpace.md),
        _label(context, 'Bio'),
        const SizedBox(height: PlaySpace.xs),
        PlayTextField(
          controller: _about,
          hint: 'A few words about you',
          maxLines: 4,
          minLines: 3,
          maxLength: UserProfile.maxAboutLength,
        ),
        if (widget.showPublicNotice) ...<Widget>[
          const SizedBox(height: PlaySpace.md),
          _PublicNotice(),
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

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        // The picture is pinned (so dragging it never fights a scrollable) when
        // there is room; on a very short viewport (the keyboard open) the whole
        // form scrolls so nothing overflows.
        if (constraints.maxHeight >= 380) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  PlaySpace.lg,
                  PlaySpace.lg,
                  PlaySpace.lg,
                  0,
                ),
                child: avatar,
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(PlaySpace.lg),
                  child: fields,
                ),
              ),
            ],
          );
        }
        return ListView(
          padding: const EdgeInsets.all(PlaySpace.lg),
          children: <Widget>[
            avatar,
            const SizedBox(height: PlaySpace.lg),
            fields,
          ],
        );
      },
    );
  }

  Widget _label(BuildContext context, String text) => Text(
    text,
    style: PlayType.bodyStrong.copyWith(color: PlayColors.of(context).ink),
  );
}

/// The "this is public" notice shown above the publish button.
class _PublicNotice extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final PlayColors colors = PlayColors.of(context);
    return PlaySurface(
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
              'Your name, bio and picture are public. Anyone can see them, and '
              'other apps may copy them — so do not put anything private here.',
              style: PlayType.caption.copyWith(color: colors.inkMuted),
            ),
          ),
        ],
      ),
    );
  }
}
