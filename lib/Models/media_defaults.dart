import 'package:BeatNow/config/api_config.dart';
import 'package:flutter/widgets.dart';
import 'package:cached_network_image/cached_network_image.dart';

class MediaDefaults {
  static const profileImage = 'assets/images/profile.jpg';
  static const coverImage = 'assets/images/image1.jpg';

  static String apiUrl(Map<String, dynamic> json, String key) {
    final value = json[key]?.toString().trim();
    return normalizeMediaUrl(value);
  }

  static String firstString(Map<String, dynamic> json, List<String> keys) {
    for (final key in keys) {
      final value = json[key]?.toString().trim();
      if (value != null && value.isNotEmpty) return value;
    }
    return '';
  }

  static String profileUrl(Map<String, dynamic> json) {
    final profile = firstString(json, const [
      'profile_image_url',
      'profileImageUrl',
      'profile_photo_url',
      'profilePhotoUrl',
      'photo_profile_url',
      'photoProfileUrl',
      'user_profile_image_url',
      'userProfileImageUrl',
      'user_photo_profile',
      'userPhotoProfile',
      'creator_profile_image_url',
      'creatorProfileImageUrl',
      'creator_photo_profile',
      'creatorPhotoProfile',
      'avatar_url',
      'avatarUrl',
      'profile_photo',
      'profile_picture',
      'profilePicture',
      'profile_pic',
      'photo_profile',
      'picture',
      'photo',
      'image',
    ]);
    final normalizedProfile = normalizeMediaUrl(profile);
    if (normalizedProfile.isNotEmpty) {
      return withCacheBust(
        normalizedProfile,
        firstString(json, const [
          'profile_image_updated_at',
          'updated_at',
          'updatedAt',
          '_profile_cache_bust',
        ]),
      );
    }

    for (final key in const ['user', 'creator', 'owner', 'author', 'profile']) {
      final nested = json[key];
      if (nested is Map<String, dynamic>) {
        final nestedProfile = profileUrl(nested);
        if (nestedProfile != profileImage) return nestedProfile;
      }
    }

    return profile.isNotEmpty ? profile : profileImage;
  }

  static String normalizeMediaUrl(String? value) {
    final source = value?.trim() ?? '';
    if (source.isEmpty) return '';
    final uri = Uri.tryParse(source);
    if (uri != null &&
        (uri.scheme == 'http' || uri.scheme == 'https') &&
        uri.host.isNotEmpty) {
      return source;
    }
    if (source.startsWith('assets/')) return source;
    if (source.startsWith('//')) return '${ApiConfig.scheme}:$source';

    final normalizedPath = source.startsWith('/') ? source : '/$source';
    return Uri(
      scheme: ApiConfig.scheme,
      host: ApiConfig.host,
      path: normalizedPath,
    ).toString();
  }

  static String withCacheBust(String value, String cacheBust) {
    if (cacheBust.trim().isEmpty) return value;
    final uri = Uri.tryParse(value);
    if (uri == null ||
        (uri.scheme != 'http' && uri.scheme != 'https') ||
        uri.host.isEmpty) {
      return value;
    }
    return uri.replace(fragment: 'v=${cacheBust.trim()}').toString();
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
