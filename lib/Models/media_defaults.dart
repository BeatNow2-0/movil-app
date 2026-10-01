import 'package:flutter/widgets.dart';
import 'package:cached_network_image/cached_network_image.dart';

class MediaDefaults {
  static const profileImage = 'assets/images/profile.jpg';
  static const coverImage = 'assets/images/image1.jpg';

  static String apiUrl(Map<String, dynamic> json, String key) {
    final value = json[key]?.toString().trim();
    return value == null || value.isEmpty ? '' : value;
  }

  static String firstString(Map<String, dynamic> json, List<String> keys) {
    for (final key in keys) {
      final value = json[key]?.toString().trim();
      if (value != null && value.isNotEmpty) return value;
    }
    return '';
  }

  static String profileUrl(Map<String, dynamic> json) {
    final profile = firstString(json, ['profile_image_url']);
    return profile.isNotEmpty ? profile : profileImage;
  }

  static String coverUrl(Map<String, dynamic> json) {
    final cover = apiUrl(json, 'cover_image_url');
    if (cover.isNotEmpty) return cover;
    final temporaryLegacyCover = apiUrl(json, 'caratula');
    return temporaryLegacyCover.isNotEmpty ? temporaryLegacyCover : coverImage;
  }

  static ImageProvider imageProvider(String? value,
      {required String fallback}) {
    final source = value?.trim() ?? '';
    if (source.isEmpty) return AssetImage(fallback);
    final uri = Uri.tryParse(source);
    if (uri != null && (uri.scheme == 'http' || uri.scheme == 'https')) {
      return CachedNetworkImageProvider(source);
    }
    return AssetImage(source);
  }

  static ImageProvider coverImageProvider(String? value) =>
      imageProvider(value, fallback: coverImage);

  static ImageProvider profileImageProvider(String? value) =>
      imageProvider(value, fallback: profileImage);
}
