class SavedPost {
  final String id;
  final String postId;
  final String userId;
  final String savedDate;
  final String? creatorId;
  final String? coverFormat;
  final String? coverImageUrl;

  SavedPost({
    required this.id,
    required this.postId,
    required this.userId,
    required this.savedDate,
    this.creatorId,
    this.coverFormat,
    this.coverImageUrl,
  });

  static SavedPost fromJson(Map<String, dynamic> json) {
    return SavedPost(
      id: json['_id'] as String,
      postId: json['post_id'] as String,
      userId: json['user_id'] as String,
      savedDate: json['saved_date'] as String,
      creatorId: json['creator_id']?.toString(),
      coverFormat: json['cover_format']?.toString(),
      coverImageUrl: json['cover_image_url']?.toString(),
    );
  }
}
