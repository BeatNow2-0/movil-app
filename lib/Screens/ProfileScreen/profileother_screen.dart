import 'package:BeatNow/Models/OtherUserSingleton.dart';
import 'package:BeatNow/Models/Posts.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:BeatNow/services/api_client.dart';
import 'package:BeatNow/services/beatnow_service.dart';
import '../../Controllers/auth_controller.dart'; // Ajusta la importación según la estructura de tu proyecto

class ProfileOtherScreen extends StatefulWidget {
  const ProfileOtherScreen({super.key});

  @override
  _ProfileOtherScreenState createState() => _ProfileOtherScreenState();
}

class _ProfileOtherScreenState extends State<ProfileOtherScreen> {
  final AuthController _authController = Get.find<AuthController>();
  final BeatNowService _beatNowService = BeatNowService();
  bool _isFollowingUser = false;
  List<Posts>? _posts;
  Map<String, int>? _followersFollowing;

  @override
  void initState() {
    super.initState();
    _initializeProfileData();
  }

  Future<void> _initializeProfileData() async {
    await _fetchUserPosts(OtherUserSingleton().username);
    _followersFollowing = await _fetchFollowersFollowing(OtherUserSingleton().id);
    _isFollowingUser = await _isFollowing(OtherUserSingleton().id);
    setState(() {});
  }

  Future<void> _fetchUserPosts(String username) async {
    try {
      final posts = await _beatNowService.getUserPosts(username);
      if (!mounted) return;
      setState(() {
        _posts = posts;
      });
    } catch (error) {
      debugPrint('Error fetching user posts: $error');
      if (!mounted) return;
      setState(() {
        _posts = <Posts>[];
      });
    }
  }

  Future<Map<String, int>> _fetchFollowersFollowing(String userId) async {
    try {
      final jsonResponse = await _beatNowService.getUserProfile(userId);
      return {
        'followers': _asInt(jsonResponse['followers']),
        'following': _asInt(jsonResponse['following']),
      };
    } catch (error) {
      debugPrint('Error fetching followers and following: $error');
      return {
        'followers': 0,
        'following': 0
      }; // En caso de error, retorna valores predeterminados
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () {
            _authController.changeTab(AuthTabs.home);
            Get.back(); // or Navigator.pop(context) if not using GetX
          },
        ),
        title: Text(
          "@${OtherUserSingleton().username}",
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 20,
            color: Colors.white,
          ),
        ),
        centerTitle: true,
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF121212), // darker shade
              Color(0xFF0D0D0D), // even darker shade
            ],
            stops: [0.5, 1.0], // where to start and end each color
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: <Widget>[
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                GestureDetector(
                  child: CircleAvatar(
                    radius: 50,
                    backgroundImage: NetworkImage(
                      OtherUserSingleton().profileImageUrl,
                    ),
                  ),
                ),
                const SizedBox(width: 20),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        _buildStatColumn('Posts', '${_posts?.length ?? 0}'),
                        const SizedBox(width: 20),
                        _buildStatColumn('Following',
                            '${_followersFollowing?['following']}'),
                        const SizedBox(width: 20),
                        _buildStatColumn('Followers',
                            '${_followersFollowing?['followers']}'),
                      ],
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.only(left: 30.0),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  OtherUserSingleton().username,
                  style: const TextStyle(fontSize: 18, color: Colors.white),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        // Acción cuando se presiona el botón "Message"
                      },
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Colors.white),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(5.0),
                        ),
                      ),
                      child: const Text(
                        'Message',
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10), // Espacio entre los botones
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () async {
                        try {
                          if (_isFollowingUser) {
                            await _beatNowService.unfollowUser(OtherUserSingleton().id);
                          } else {
                            await _beatNowService.followUser(OtherUserSingleton().id);
                          }
                          if (!mounted) return;
                          setState(() {
                            _isFollowingUser = !_isFollowingUser;
                            final delta = _isFollowingUser ? 1 : -1;
                            _followersFollowing = {
                              ...?_followersFollowing,
                              'followers': (_followersFollowing?['followers'] ?? 0) + delta,
                            };
                          });
                        } on ApiException catch (error) {
                          if (!mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(error.message)),
                          );
                        }
                      },
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Colors.white),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(5.0),
                        ),
                      ),
                      child: Text(
                        _isFollowingUser ? 'Following' : 'Follow',
                        style: const TextStyle(color: Colors.white),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 30),
            Expanded(
              child: _posts == null
                  ? const Center(child: CircularProgressIndicator())
                  : GridView.builder(
                      padding: const EdgeInsets.all(10.0),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3,
                        mainAxisSpacing: 10.0,
                        crossAxisSpacing: 10.0,
                        childAspectRatio: 9 / 16, // Proporción 16:9 vertical
                      ),
                      itemCount: _posts!.length,
                      itemBuilder: (context, index) {
                        final post = _posts![index];
                        return ClipRRect(
                          borderRadius: BorderRadius.circular(14),
                          child: Image.network(
                            post.coverImageUrl,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Container(
                              color: Colors.white.withValues(alpha: 0.08),
                              alignment: Alignment.center,
                              child: const Icon(Icons.music_note_rounded, color: Colors.white54),
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatColumn(String label, String count) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: <Widget>[
        Text(
          count,
          style: const TextStyle(
            fontSize: 22.0,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        Text(
          label,
          style: const TextStyle(
            fontSize: 16.0,
            fontWeight: FontWeight.w400,
            color: Colors.white,
          ),
        ),
      ],
    );
  }

  Future<bool> _isFollowing(String userId) async {
    try {
      final jsonResponse = await _beatNowService.getUserProfile(userId);
      return jsonResponse['is_following'] == true;
    } catch (error) {
      debugPrint('Error fetching followers and following: $error');
      return false; // En caso de error, retorna valores predeterminados
    }
  }

  int _asInt(dynamic value) {
    if (value is int) return value;
    if (value is double) return value.round();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }
}
