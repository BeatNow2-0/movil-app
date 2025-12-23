class Posts {
  final String id;
  final String title;
  final String username;
  final String userId;
  final String description;
  final int likes;
  final int saves;
  final bool liked;
  final bool saved;
  final String audioFormat;
  final String userPhotoProfile;

  Posts({
    required this.id,
    required this.title,
    required this.username,
    required this.userId,
    required this.description,
    required this.likes,
    required this.saves,
    required this.liked,
    required this.saved,
    required this.audioFormat,
    required this.userPhotoProfile,
  });

  factory Posts.fromApi(Map<String, dynamic> json) {
    final userId = json['user_id'].toString();
    final postId = json['_id'].toString();

    return Posts(
      id: postId,
      title: json['title'] ?? '',
      username: json['creator_username'] ?? '',
      description: json['description'] ?? '',
      likes: json['likes'] ?? 0,
      saves: json['saves'] ?? 0,
      liked: json['isLiked'] ?? false,
      saved: json['isSaved'] ?? false,
      userId: userId,
      audioFormat: json['audio_format'] ?? 'mp3',
      userPhotoProfile:
          'https://res.beatnow.app/beatnow/$userId/photo_profile/photo_profile.png',
    );
  }

  String get coverImageUrl =>
      'https://res.beatnow.app/beatnow/$userId/posts/$id/caratula.jpg';

  String get audioUrl =>
      'https://res.beatnow.app/beatnow/$userId/posts/$id/audio.$audioFormat';
}
