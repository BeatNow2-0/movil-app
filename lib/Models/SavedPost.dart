import 'package:BeatNow/Models/media_defaults.dart';

class SavedPost {
  final String id;
  final String postId;
  final String userId;
  final String savedDate;
  final String? creatorId;
  final String? coverFormat;
  final String coverImageUrl;
  final String audioUrl;
  final String title;
  final String description;
  final String creatorUsername;
  final String genre;
  final int? bpm;
  final List<String> tags;
  final List<String> moods;
  final List<String> instruments;

  SavedPost({
    required this.id,
    required this.postId,
    required this.userId,
    required this.savedDate,
    this.creatorId,
    this.coverFormat,
    required this.coverImageUrl,
    required this.audioUrl,
    required this.title,
    required this.description,
    required this.creatorUsername,
    required this.genre,
    required this.bpm,
    required this.tags,
    required this.moods,
    required this.instruments,
  });

  static SavedPost fromJson(Map<String, dynamic> json) {
    final nestedPost = json['post'];
    final post =
        nestedPost is Map<String, dynamic> ? nestedPost : <String, dynamic>{};
    final media = {...post, ...json}..removeWhere(
        (_, value) => value == null || value.toString().trim().isEmpty);
    final postId = MediaDefaults.firstString(json, ['post_id', 'beat_id']);
    final nestedPostId =
        MediaDefaults.firstString(post, ['_id', 'id', 'post_id', 'beat_id']);
    return SavedPost(
      id: MediaDefaults.firstString(json, ['_id', 'id']),
      postId: postId.isNotEmpty
          ? postId
          : nestedPostId.isNotEmpty
              ? nestedPostId
              : MediaDefaults.firstString(json, ['id', '_id']),
      userId: MediaDefaults.firstString(json, ['user_id', 'creator_id']),
      savedDate: json['saved_date']?.toString() ?? '',
      creatorId: MediaDefaults.firstString(json, ['creator_id', 'user_id']),
      coverFormat: json['cover_format']?.toString(),
      coverImageUrl: MediaDefaults.coverUrl(media),
      audioUrl: MediaDefaults.apiUrl(media, 'audio_url'),
      title: MediaDefaults.firstString(media, ['title']).isNotEmpty
          ? MediaDefaults.firstString(media, ['title'])
          : 'Untitled beat',
      description: MediaDefaults.firstString(media, ['description']),
      creatorUsername:
          MediaDefaults.firstString(media, ['creator_username', 'username']),
      genre: MediaDefaults.firstString(media, ['genre']),
      bpm: _asInt(media['bpm']),
      tags: _asStringList(media['tags']),
      moods: _asStringList(media['moods']),
      instruments: _asStringList(media['instruments']),
    );
  }

  static int? _asInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is double) return value.round();
    return int.tryParse(value.toString());
  }

  static List<String> _asStringList(dynamic value) {
    if (value is List) {
      return value
          .map((item) => item.toString())
          .where((item) => item.isNotEmpty)
          .toList();
    }
    if (value is String && value.isNotEmpty) {
      return value
          .split(',')
          .map((item) => item.trim())
          .where((item) => item.isNotEmpty)
          .toList();
    }
    return <String>[];
  }
}
