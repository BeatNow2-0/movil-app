import 'package:BeatNow/Models/media_defaults.dart';

class Posts {
  final String id;
  final String title;
  final String username;
  final String userId;
  final String description;
  final int likes;
  final int saves;
  final int views;
  final bool liked;
  final bool saved;
  final String audioFormat;
  final String userPhotoProfile;
  final String coverImage;
  final String audioSourceUrl;
  final String genre;
  final List<String> tags;
  final List<String> moods;
  final List<String> instruments;
  final int? bpm;
  final DateTime? publicationDate;

  Posts({
    required this.id,
    required this.title,
    required this.username,
    required this.userId,
    required this.description,
    required this.likes,
    required this.saves,
    required this.views,
    required this.liked,
    required this.saved,
    required this.audioFormat,
    required this.userPhotoProfile,
    required this.coverImage,
    required this.audioSourceUrl,
    required this.genre,
    required this.tags,
    required this.moods,
    required this.instruments,
    required this.bpm,
    required this.publicationDate,
  });

  factory Posts.fromApi(Map<String, dynamic> json) {
    final creator =
        _firstMap(json, const ['creator', 'user', 'owner', 'author']);
    final producerData = <String, dynamic>{...json, ...creator};
    return Posts(
      id: MediaDefaults.firstString(json, ['_id', 'id', 'post_id', 'beat_id']),
      title: json['title']?.toString() ?? '',
      username: MediaDefaults.firstString(
        producerData,
        const ['creator_username', 'username', 'user_username'],
      ),
      description: json['description']?.toString() ?? '',
      likes: _asCount(json['likes']),
      saves: _asCount(json['saves']),
      views: _asInt(json['views']),
      liked: json['isLiked'] == true || json['liked'] == true,
      saved: json['isSaved'] == true || json['saved'] == true,
      userId: MediaDefaults.firstString(
        producerData,
        const ['user_id', 'creator_id', '_id', 'id'],
      ),
      audioFormat: json['audio_format']?.toString() ?? 'mp3',
      userPhotoProfile: MediaDefaults.profileUrl(producerData),
      coverImage: MediaDefaults.coverUrl(json),
      audioSourceUrl: MediaDefaults.apiUrl(json, 'audio_url'),
      genre: json['genre']?.toString() ?? '',
      tags: _asStringList(json['tags']),
      moods: _asStringList(json['moods']),
      instruments: _asStringList(json['instruments']),
      bpm: json['bpm'] == null ? null : _asInt(json['bpm']),
      publicationDate: json['publication_date'] == null
          ? null
          : DateTime.tryParse(json['publication_date'].toString()),
    );
  }

  Posts copyWith({
    String? id,
    String? title,
    String? username,
    String? userId,
    String? description,
    int? likes,
    int? saves,
    int? views,
    bool? liked,
    bool? saved,
    String? audioFormat,
    String? userPhotoProfile,
    String? coverImage,
    String? audioSourceUrl,
    String? genre,
    List<String>? tags,
    List<String>? moods,
    List<String>? instruments,
    int? bpm,
    DateTime? publicationDate,
  }) {
    return Posts(
      id: id ?? this.id,
      title: title ?? this.title,
      username: username ?? this.username,
      userId: userId ?? this.userId,
      description: description ?? this.description,
      likes: likes ?? this.likes,
      saves: saves ?? this.saves,
      views: views ?? this.views,
      liked: liked ?? this.liked,
      saved: saved ?? this.saved,
      audioFormat: audioFormat ?? this.audioFormat,
      userPhotoProfile: userPhotoProfile ?? this.userPhotoProfile,
      coverImage: coverImage ?? this.coverImage,
      audioSourceUrl: audioSourceUrl ?? this.audioSourceUrl,
      genre: genre ?? this.genre,
      tags: tags ?? this.tags,
      moods: moods ?? this.moods,
      instruments: instruments ?? this.instruments,
      bpm: bpm ?? this.bpm,
      publicationDate: publicationDate ?? this.publicationDate,
    );
  }

  String get coverImageUrl => coverImage;
  String get audioUrl => audioSourceUrl;

  static Map<String, dynamic> _firstMap(
    Map<String, dynamic> json,
    List<String> keys,
  ) {
    for (final key in keys) {
      final value = json[key];
      if (value is Map<String, dynamic>) return value;
    }
    return const <String, dynamic>{};
  }

  static int _asInt(dynamic value) {
    if (value is int) return value;
    if (value is double) return value.round();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  static int _asCount(dynamic value) => _asInt(value).clamp(0, 1 << 30).toInt();

  static List<String> _asStringList(dynamic value) {
    if (value is List) {
      return value
          .map((item) => item.toString())
          .where((item) => item.isNotEmpty)
          .toList();
    }
    if (value is String && value.isNotEmpty) {
      if (value.startsWith('[') && value.endsWith(']')) {
        final normalized = value
            .substring(1, value.length - 1)
            .split(',')
            .map((item) => item.replaceAll('"', '').trim())
            .where((item) => item.isNotEmpty)
            .toList();
        if (normalized.isNotEmpty) {
          return normalized;
        }
      }

      return value
          .split(',')
          .map((item) => item.trim())
          .where((item) => item.isNotEmpty)
          .toList();
    }
    return <String>[];
  }
}
