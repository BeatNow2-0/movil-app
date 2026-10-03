import 'package:BeatNow/theme/beatnow_theme.dart';
import 'package:flutter/material.dart';

class BeatNowLogo extends StatelessWidget {
  const BeatNowLogo({
    super.key,
    this.size = 44,
    this.showWordmark = true,
    this.subtitle,
  });

  final double size;
  final bool showWordmark;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final image = Image.asset(
      'assets/images/icono_central.png',
      width: size,
      height: size,
      fit: BoxFit.contain,
    );

    if (!showWordmark) return image;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        image,
        const SizedBox(width: BeatNowTokens.space3),
        Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'BEATNOW',
              style: TextStyle(
                color: BeatNowTokens.text,
                fontSize: 15,
                fontWeight: FontWeight.w900,
                letterSpacing: 0,
              ),
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 2),
              Text(
                subtitle!,
                style: const TextStyle(
                  color: BeatNowTokens.textMuted,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }
}
