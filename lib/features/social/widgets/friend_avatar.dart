import 'package:material_ui/material_ui.dart';

/// A round friend avatar: the Nostr profile picture when there is one, else a
/// monogram on the theme's container colour.
///
/// Network images are best-effort — a broken or hostile URL falls back to the
/// monogram instead of throwing (AGENTS.md "Never crash").
class FriendAvatar extends StatelessWidget {
  const FriendAvatar({
    super.key,
    required this.label,
    this.pictureUrl,
    this.size = 40,
    this.borderColor,
  });

  final String label;
  final String? pictureUrl;
  final double size;

  /// Draws a ring around the avatar (used for the "live" state).
  final Color? borderColor;

  @override
  Widget build(BuildContext context) {
    final Widget monogram = _monogram(context);
    final String? url = pictureUrl;
    Widget avatar = monogram;
    if (url != null && url.isNotEmpty) {
      avatar = ClipOval(
        child: Image.network(
          url,
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (BuildContext _, Object _, StackTrace? _) => monogram,
        ),
      );
    }
    final Color? border = borderColor;
    if (border == null) {
      return SizedBox(width: size, height: size, child: avatar);
    }
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: border, width: 2),
      ),
      child: ClipOval(child: avatar),
    );
  }

  Widget _monogram(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final String initial = _initial();
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      color: scheme.primaryContainer,
      child: Text(
        initial,
        style: TextStyle(
          color: scheme.onPrimaryContainer,
          fontWeight: FontWeight.w600,
          fontSize: size * 0.42,
        ),
      ),
    );
  }

  String _initial() {
    final String trimmed = label.trim();
    if (trimmed.isEmpty) {
      return '?';
    }
    return String.fromCharCode(trimmed.runes.first).toUpperCase();
  }
}
