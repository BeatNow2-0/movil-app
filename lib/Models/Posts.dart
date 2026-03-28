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
    final userId = json['user_id']?.toString() ?? '';
    final postId = json['_id']?.toString() ?? '';

    return Posts(
      id: postId,
      title: json['title']?.toString() ?? '',
      username: json['creator_username']?.toString() ?? json['username']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      likes: _asInt(json['likes']),
      saves: _asInt(json['saves']),
      views: _asInt(json['views']),
      liked: json['isLiked'] == true || json['liked'] == true,
      saved: json['isSaved'] == true || json['saved'] == true,
      userId: userId,
      audioFormat: json['audio_format']?.toString() ?? 'mp3',
      userPhotoProfile: json['profile_image_url']?.toString() ??
          'https://res.beatnow.app/beatnow/$userId/photo_profile/photo_profile.png',
      coverImage: json['cover_image_url']?.toString() ??
          'https://res.beatnow.app/beatnow/$userId/posts/$postId/caratula.${json['cover_format'] ?? 'jpg'}',
      audioSourceUrl: json['audio_url']?.toString() ??
          'https://res.beatnow.app/beatnow/$userId/posts/$postId/audio.${json['audio_format'] ?? 'mp3'}',
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

  static int _asInt(dynamic value) {
    if (value is int) return value;
    if (value is double) return value.round();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  static List<String> _asStringList(dynamic value) {
    if (value is List) {
      return value.map((item) => item.toString()).where((item) => item.isNotEmpty).toList();
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
