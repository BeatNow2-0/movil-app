import 'package:BeatNow/Controllers/auth_controller.dart';
import 'package:BeatNow/Models/OtherUserSingleton.dart';
import 'package:BeatNow/Models/Posts.dart';
import 'package:BeatNow/Models/UserSingleton.dart';
import 'package:BeatNow/Screens/HomeScreen/LyricScreen.dart';
import 'package:BeatNow/Screens/HomeScreen/saved_screen.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:share_plus/share_plus.dart';
import 'package:BeatNow/services/beatnow_service.dart';
import 'package:audioplayers/audioplayers.dart';

class HomeScreenState extends StatefulWidget {
  const HomeScreenState({super.key});

  @override
  State<HomeScreenState> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreenState>
    with WidgetsBindingObserver {
  final AuthController _authController = Get.find<AuthController>();
  late final AudioPlayer _audioPlayer;
  final BeatNowService _beatNowService = BeatNowService();

  final List<Posts> _posts = [];

  int _selectedIndex = 1;
  int _currentIndex = 0;
  bool _isPlaying = false;
  bool _isFetching = false;
  String? _currentAudioUrl;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _audioPlayer = AudioPlayer()..setReleaseMode(ReleaseMode.stop);

    _audioPlayer.onPlayerStateChanged.listen((state) {
      if (!mounted) return;
      final playing = state == PlayerState.playing;
      if (_isPlaying != playing) {
        setState(() => _isPlaying = playing);
      }
    });

    _loadInitialPosts();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _audioPlayer.stop();
    _audioPlayer.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      _audioPlayer.stop();
    }
  }

  /* ================= POSTS ================= */

  Future<void> _loadInitialPosts() async {
    await _loadMorePosts();
  }

  Future<void> _loadMorePosts() async {
    if (_isFetching) return;
    _isFetching = true;

    try {
      final results = await Future.wait([
        _beatNowService.getRandomPost(),
        _beatNowService.getRandomPost(),
      ]);

      if (!mounted) return;

      setState(() {
        _posts.addAll(results);
      });
    } catch (e) {
      debugPrint('Load posts error: $e');
    } finally {
      _isFetching = false;
    }
  }

  /* ================= AUDIO ================= */

  Future<void> _playAudio(String url) async {
    if (_currentAudioUrl == url) return;

    _currentAudioUrl = url;
    try {
      await _audioPlayer.stop();
      await _audioPlayer.play(UrlSource(url));
    } catch (e) {
      debugPrint('Audio error: $e');
    }
  }

  /* ================= UI ================= */

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF111111),
      appBar: _selectedIndex == 1 && _posts.isNotEmpty
          ? AppBar(
              backgroundColor: const Color(0xFF111111),
              elevation: 0,
              leading: IconButton(
                onPressed: () => _authController.changeTab(AuthTabs.profile),
                icon: CircleAvatar(
                  backgroundImage:
                      NetworkImage(UserSingleton().profileImageUrl),
                ),
              ),
              title: Text(
                '@${_posts[_currentIndex].username}',
                style: const TextStyle(color: Colors.white, fontSize: 20),
              ),
              centerTitle: true,
              actions: [
                IconButton(
                  icon: const Icon(Icons.search, color: Colors.white),
                  onPressed: () => _authController.changeTab(AuthTabs.search),
                ),
              ],
            )
          : null,
      body: _selectedIndex == 0
          ? const SavedScreen()
          : _selectedIndex == 1
              ? _buildFeed()
              : const LyricScreen(),
      bottomNavigationBar: _bottomBar(),
    );
  }

  Widget _buildFeed() {
    return PageView.builder(
      scrollDirection: Axis.vertical,
      itemCount: _posts.length,
      onPageChanged: (index) {
        if (index == _currentIndex) return;

        _currentIndex = index;
        UserSingleton().current = index;

        _playAudio(_posts[index].audioUrl);
        _beatNowService.registerView(_posts[index].id);

        if (index >= _posts.length - 2) {
          _loadMorePosts();
        }
      },
      itemBuilder: (_, index) {
        final post = _posts[index];
        return Stack(
          fit: StackFit.expand,
          children: [
            GestureDetector(
              onTap: () async {
                _isPlaying
                    ? await _audioPlayer.pause()
                    : await _playAudio(post.audioUrl);
              },
              child: Image.network(
                post.coverImageUrl,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(color: Colors.black),
              ),
            ),
            _buildActions(post, index),
          ],
        );
      },
    );
  }

  /* ================= ACTIONS ================= */

  Widget _buildActions(Posts post, int index) {
    return Positioned(
      right: 10,
      bottom: 40,
      child: Column(
        children: [
          GestureDetector(
            onTap: () {
              OtherUserSingleton().username = post.username;
              OtherUserSingleton().id = post.userId;
              OtherUserSingleton().profileImageUrl = post.userPhotoProfile;
              _authController.changeTab(AuthTabs.otherProfile);
            },
            child: CircleAvatar(
              radius: 22,
              backgroundImage: NetworkImage(post.userPhotoProfile),
            ),
          ),
          const SizedBox(height: 20),

          // LIKE
          IconButton(
            icon: Icon(
              Icons.favorite,
              color: post.liked ? Colors.purple : Colors.white,
              size: 36,
            ),
            onPressed: () {
              final updated = Posts(
                id: post.id,
                title: post.title,
                username: post.username,
                userId: post.userId,
                description: post.description,
                likes: post.liked ? post.likes - 1 : post.likes + 1,
                saves: post.saves,
                liked: !post.liked,
                saved: post.saved,
                audioFormat: post.audioFormat,
                userPhotoProfile: post.userPhotoProfile,
                coverImage: post.coverImageUrl,
                audioSourceUrl: post.audioUrl,
              );

              setState(() {
                _posts[index] = updated;
              });

              updated.liked ? likePost(updated.id) : unlikePost(updated.id);
            },
          ),
          Text('${post.likes}', style: const TextStyle(color: Colors.white)),

          const SizedBox(height: 20),

          // SAVE
          IconButton(
            icon: Icon(
              Icons.bookmark,
              color: post.saved ? Colors.amber : Colors.white,
              size: 36,
            ),
            onPressed: () {
              final updated = Posts(
                id: post.id,
                title: post.title,
                username: post.username,
                userId: post.userId,
                description: post.description,
                likes: post.likes,
                saves: post.saved ? post.saves - 1 : post.saves + 1,
                liked: post.liked,
                saved: !post.saved,
                audioFormat: post.audioFormat,
                userPhotoProfile: post.userPhotoProfile,
                coverImage: post.coverImageUrl,
                audioSourceUrl: post.audioUrl,
              );

              setState(() {
                _posts[index] = updated;
              });

              updated.saved ? savePost(updated.id) : unsavePost(updated.id);
            },
          ),

          const SizedBox(height: 20),

          // SHARE
          IconButton(
            icon: const Icon(Icons.ios_share, color: Colors.white, size: 32),
            onPressed: () {
              Share.share(
                'BeatNow 🎵\n${post.title}\n${post.description}',
              );
            },
          ),
        ],
      ),
    );
  }

  /* ================= NAV ================= */

  Widget _bottomBar() {
    return BottomNavigationBar(
      currentIndex: _selectedIndex,
      backgroundColor: const Color(0xFF0B0B0B),
      selectedFontSize: 0,
      unselectedFontSize: 0,
      onTap: (index) {
        setState(() {
          _selectedIndex = index;
          _audioPlayer.stop();
        });
      },
      items: [
        BottomNavigationBarItem(
          icon: Icon(
            Icons.bookmark,
            color: _selectedIndex == 0 ? const Color(0xFF8731E4) : Colors.white,
          ),
          label: '',
        ),
        BottomNavigationBarItem(
          icon: Image.asset(
            _selectedIndex == 1
                ? 'assets/images/icono_central.png'
                : 'assets/images/icono_central_blanco.png',
            width: 36,
            height: 36,
          ),
          label: '',
        ),
        BottomNavigationBarItem(
          icon: Icon(
            Icons.edit,
            color: _selectedIndex == 2 ? const Color(0xFF8731E4) : Colors.white,
          ),
          label: '',
        ),
      ],
    );
  }

  /* ================= API ================= */

  Future<void> likePost(String id) => _beatNowService.likePost(id);

  Future<void> unlikePost(String id) => _beatNowService.unlikePost(id);

  Future<void> savePost(String id) => _beatNowService.savePost(id);

  Future<void> unsavePost(String id) => _beatNowService.unsavePost(id);
}
