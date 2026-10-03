import 'package:BeatNow/Models/media_defaults.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

class CachedMediaImage extends StatelessWidget {
  const CachedMediaImage({
    super.key,
    required this.url,
    required this.fallbackAsset,
    this.width,
    this.height,
    this.cacheWidth,
    this.fit = BoxFit.cover,
    this.fallbackBuilder,
  });

  final String? url;
  final String fallbackAsset;
  final double? width;
  final double? height;
  final int? cacheWidth;
  final BoxFit fit;
  final WidgetBuilder? fallbackBuilder;

  @override
  Widget build(BuildContext context) {
    final source = MediaDefaults.normalizeMediaUrl(url);
    final uri = Uri.tryParse(source);
    final isRemote = uri != null &&
        (uri.scheme == 'http' || uri.scheme == 'https') &&
        uri.host.isNotEmpty;

    if (!isRemote) {
      if (source.isEmpty && fallbackBuilder != null) {
        return fallbackBuilder!(context);
      }
      return Image.asset(
        source.isEmpty ? fallbackAsset : source,
        width: width,
        height: height,
        fit: fit,
        errorBuilder: (_, __, ___) =>
            fallbackBuilder?.call(context) ??
            Image.asset(
              fallbackAsset,
              width: width,
              height: height,
              fit: fit,
            ),
      );
    }

    return CachedNetworkImage(
      imageUrl: uri.removeFragment().toString(),
      cacheKey: source,
      width: width,
      height: height,
      fit: fit,
      memCacheWidth: cacheWidth,
      fadeInDuration: const Duration(milliseconds: 180),
      fadeOutDuration: const Duration(milliseconds: 80),
      placeholder: (_, __) =>
          fallbackBuilder?.call(context) ??
          Image.asset(
            fallbackAsset,
            width: width,
            height: height,
            fit: fit,
          ),
      errorWidget: (_, __, ___) =>
          fallbackBuilder?.call(context) ??
          Image.asset(
            fallbackAsset,
            width: width,
            height: height,
            fit: fit,
          ),
    );
  }
}
