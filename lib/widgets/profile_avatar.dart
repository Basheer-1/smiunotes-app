import 'dart:typed_data';
import 'package:material_ui/material_ui.dart';

/// Website-style photo avatar with a deterministic two-initial fallback.
class ProfileAvatar extends StatefulWidget {
  const ProfileAvatar({
    super.key, this.name, this.imageLoader, this.size = 38,
  });
  final String? name;
  final Future<Uint8List?> Function()? imageLoader;
  final double size;

  static String initials(String? name) {
    final words = (name ?? '').trim().split(RegExp(r'\s+'))
        .where((word) => word.isNotEmpty).take(2).toList();
    if (words.isEmpty) return '?';
    return words.map((word) => word.substring(0, 1)).join().toUpperCase();
  }

  @override
  State<ProfileAvatar> createState() => _ProfileAvatarState();
}

class _ProfileAvatarState extends State<ProfileAvatar> {
  Future<Uint8List?>? _photo;
  @override
  void initState() { super.initState(); _reload(); }
  @override
  void didUpdateWidget(covariant ProfileAvatar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.imageLoader != widget.imageLoader ||
        oldWidget.name != widget.name) { _reload(); }
  }
  void _reload() {
    final load = widget.imageLoader;
    _photo = load == null ? null : Future<Uint8List?>.sync(load);
  }

  @override
  Widget build(BuildContext context) => Semantics(
    label: widget.name == null ? 'Profile' : 'Profile: ${widget.name}',
    child: Container(
      width: widget.size, height: widget.size,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Theme.of(context).colorScheme.primaryContainer,
        border: Border.all(
          color: Theme.of(context).colorScheme.primary.withValues(alpha: .24),
        ),
      ),
      child: _photo == null ? _fallback(context) : FutureBuilder<Uint8List?>(
        future: _photo,
        builder: (context, snapshot) {
          if (snapshot.hasData && snapshot.data!.isNotEmpty) {
            return Image.memory(snapshot.data!, fit: BoxFit.cover,
              gaplessPlayback: true,
              errorBuilder: (_, _, _) => _fallback(context));
          }
          return _fallback(context);
        },
      ),
    ),
  );

  Widget _fallback(BuildContext context) => Center(
    child: Text(ProfileAvatar.initials(widget.name),
      style: TextStyle(
        fontSize: widget.size * .34,
        color: Theme.of(context).colorScheme.primary,
        fontWeight: FontWeight.w800,
      )),
  );
}
