import 'package:BeatNow/Models/media_defaults.dart';
import 'package:BeatNow/theme/beatnow_theme.dart';
import 'package:BeatNow/widgets/cached_media_image.dart';
import 'package:flutter/material.dart';

class ProfileAvatar extends StatelessWidget {
  const ProfileAvatar({
    super.key,
    required this.imageUrl,
    this.size = 40,
    this.initial,
    this.icon = Icons.person_rounded,
    this.borderColor,
    this.borderWidth = 0,
  });

  final String? imageUrl;
  final double size;
  final String? initial;
  final IconData icon;
  final Color? borderColor;
  final double borderWidth;

  @override
  Widget build(BuildContext context) {
    final fallback = _fallback();
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: borderWidth > 0
            ? Border.all(
                color: borderColor ?? Colors.white.withValues(alpha: 0.16),
                width: borderWidth,
              )
            : null,
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        fit: StackFit.expand,
        children: [
          CachedMediaImage(
            url: imageUrl,
            fallbackAsset: MediaDefaults.profileImage,
            width: size,
            height: size,
            fallbackBuilder: (_) => fallback,
          ),
        ],
      ),
    );
  }

  Widget _fallback() {
    final value = initial?.trim();
    return Container(
      color: BeatNowTokens.surface2,
      alignment: Alignment.center,
      child: value != null && value.isNotEmpty
          ? Text(
              value.substring(0, 1).toUpperCase(),
              style: TextStyle(
                color: Colors.white,
                fontSize: size * 0.42,
                fontWeight: FontWeight.w800,
              ),
            )
          : Icon(icon, color: Colors.white54, size: size * 0.52),
    );
  }
}
