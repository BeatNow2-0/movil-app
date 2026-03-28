import 'package:BeatNow/Models/OtherUserSingleton.dart';
import 'package:BeatNow/Models/Posts.dart';
import 'package:BeatNow/Models/SavedPost.dart';
import 'package:BeatNow/Models/UserSingleton.dart';
import 'package:BeatNow/services/api_client.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

class BeatNowService {
  BeatNowService({ApiClient? apiClient}) : _apiClient = apiClient ?? ApiClient();

  final ApiClient _apiClient;

  Future<Map<String, dynamic>> register({
    required String fullName,
    required String email,
    required String username,
    required String password,
  }) {
    return _apiClient.post(
      '/users/register',
      requiresAuth: false,
      body: {
        'full_name': fullName,
        'email': email,
        'username': username,
        'password': password,
      },
    );
  }

  Future<Map<String, dynamic>> getCurrentUser() async {
    final json = await _apiClient.get('/users/users/me');
    UserSingleton()
      ..id = json['id']?.toString() ?? ''
      ..name = json['full_name']?.toString() ?? ''
      ..username = json['username']?.toString() ?? ''
      ..email = json['email']?.toString() ?? ''
      ..profileImageUrl = json['profile_image_url']?.toString() ??
          'https://res.beatnow.app/beatnow/${json['id']?.toString() ?? ''}/photo_profile/photo_profile.png'
      ..isActive = json['is_active'] == true;
    return json;
  }

  Future<Map<String, dynamic>> getUserProfile(String userId) => _apiClient.get('/users/profile/$userId');

  Future<List<dynamic>> getUserPostsRaw(String username) => _apiClient.getList('/users/posts/$username');

  Future<List<Posts>> getUserPosts(String username) async {
    final response = await getUserPostsRaw(username);
    return response.whereType<Map<String, dynamic>>().map(Posts.fromApi).toList();
  }

  Future<List<Posts>> getRandomFeedPosts({int count = 6, Set<String>? excludeIds}) async {
    final posts = <Posts>[];
    final seenIds = <String>{...?excludeIds};
    var attempts = 0;
    final maxAttempts = count * 4;

    while (posts.length < count && attempts < maxAttempts) {
      attempts += 1;
      final post = await getRandomPost();
      if (seenIds.add(post.id)) {
        posts.add(post);
      }
    }

    return posts;
  }

  Future<void> deleteAccount() async {
    await _apiClient.delete('/users/delete');
    await _apiClient.clearTokens();
  }

  Future<void> sendPasswordResetEmail(String email) async {
    await _apiClient.post(
      '/mail/send-password-reset',
      requiresAuth: false,
      headers: {'accept': 'application/json'},
      body: {'email': email},
    );
  }

  Future<void> sendConfirmationEmail() async {
    await _apiClient.post(
      '/mail/send-confirmation',
      body: const {},
    );
  }

  Future<void> confirmEmailCode(String code) async {
    await _apiClient.post(
      '/mail/confirmation',
      body: {'code': code},
    );
  }

  Future<Posts> getRandomPost() async {
    final json = await _apiClient.get('/posts/random');
    return Posts.fromApi(json);
  }

  Future<List<SavedPost>> getSavedPosts() async {
    final json = await _apiClient.get('/users/saved-posts');
    final savedPosts = json['saved_posts'];
    if (savedPosts is List) {
      return savedPosts
          .whereType<Map<String, dynamic>>()
          .map(SavedPost.fromJson)
          .toList();
    }
    return <SavedPost>[];
  }

  Future<void> likePost(String postId) => _apiClient.post('/interactions/like/$postId');
  Future<void> unlikePost(String postId) => _apiClient.delete('/interactions/unlike/$postId');
  Future<void> savePost(String postId) => _apiClient.post('/interactions/save/$postId');
  Future<void> unsavePost(String postId) => _apiClient.delete('/interactions/unsave/$postId');
  Future<void> registerView(String postId) => _apiClient.post('/interactions/view/$postId');

  Future<List<Map<String, dynamic>>> searchUsers(String query) async {
    final results = await _apiClient.getList('/search/user/', queryParameters: {'username': query});
    return results.whereType<Map<String, dynamic>>().toList();
  }

  Future<List<Map<String, dynamic>>> searchPosts(String query, {Map<String, dynamic>? filters}) async {
    final response = await _apiClient.getList('/search/search_posts', queryParameters: {
      'search': query,
      ...?filters,
    });
    return response.whereType<Map<String, dynamic>>().toList();
  }

  Future<List<Map<String, dynamic>>> getUserLyrics() async {
    final response = await _apiClient.getList('/lyrics/user');
    return response.whereType<Map<String, dynamic>>().toList();
  }

  Future<Map<String, dynamic>> createLyric({
    required String title,
    required String lyrics,
    String? postId,
  }) {
    return _apiClient.post('/lyrics/', body: {
      'title': title,
      'lyrics': lyrics,
      if (postId != null && postId.isNotEmpty) 'post_id': postId,
    });
  }

  Future<Map<String, dynamic>> updateLyric({
    required String lyricId,
    required String title,
    required String lyrics,
    String? postId,
  }) {
    return _apiClient.put('/lyrics/$lyricId', body: {
      'title': title,
      'lyrics': lyrics,
      if (postId != null && postId.isNotEmpty) 'post_id': postId,
    });
  }

  Future<void> deleteLyric(String lyricId) => _apiClient.delete('/lyrics/$lyricId');
  Future<Map<String, dynamic>> getLyric(String lyricId) => _apiClient.get('/lyrics/$lyricId');

  Future<void> followUser(String userId) => _apiClient.post('/follows/follow/$userId');
  Future<void> unfollowUser(String userId) => _apiClient.delete('/follows/unfollow/$userId');

  Future<void> changeProfilePhoto(String filePath) async {
    final uri = Uri.https('api.beatnow.app', '/v1/api/users/change_photo_profile');
    final request = http.MultipartRequest('PUT', uri)
      ..headers['Authorization'] = 'Bearer ${UserSingleton().token}'
      ..files.add(await http.MultipartFile.fromPath(
        'file',
        filePath,
        contentType: MediaType('image', 'jpeg'),
      ));

    final response = await request.send();
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final body = await response.stream.bytesToString();
      throw ApiException('Failed to upload profile image', statusCode: response.statusCode, responseBody: body);
    }
  }

  Future<void> deleteProfilePhoto() => _apiClient.delete('/users/delete_photo_profile');

  void setOtherUserFromSearchResult(Map<String, dynamic> user) {
    OtherUserSingleton()
      ..id = user['id']?.toString() ?? user['_id']?.toString() ?? ''
      ..username = user['username']?.toString() ?? ''
      ..name = user['full_name']?.toString() ?? ''
      ..profileImageUrl = user['profile_image_url']?.toString() ??
          'https://res.beatnow.app/beatnow/${user['id']?.toString() ?? user['_id']?.toString() ?? ''}/photo_profile/photo_profile.png';
  }
}
