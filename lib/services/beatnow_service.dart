import 'package:BeatNow/Models/OtherUserSingleton.dart';
import 'package:BeatNow/Models/Posts.dart';
import 'package:BeatNow/Models/UserSingleton.dart';
import 'package:BeatNow/services/api_client.dart';

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
      ..isActive = json['is_active'] == true;
    return json;
  }

  Future<void> deleteAccount() async {
    await _apiClient.delete('/users/delete');
    await _apiClient.clearTokens();
  }

  Future<void> sendPasswordResetEmail(String email) async {
    await _apiClient.post(
      '/mail/send-password-reset/',
      requiresAuth: false,
      queryParameters: {'mail': email},
      headers: {'accept': 'application/json'},
      body: const {},
    );
  }

  Future<Posts> getRandomPost() async {
    final json = await _apiClient.get('/posts/random');
    return Posts.fromApi(json);
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
      'query': query,
      ...?filters,
    });
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

  void setOtherUserFromSearchResult(Map<String, dynamic> user) {
    OtherUserSingleton()
      ..id = user['id']?.toString() ?? user['_id']?.toString() ?? ''
      ..username = user['username']?.toString() ?? ''
      ..name = user['full_name']?.toString() ?? '';
  }
}
