import 'package:BeatNow/Controllers/auth_controller.dart';
import 'package:BeatNow/Models/OtherUserSingleton.dart';
import 'package:BeatNow/Models/Posts.dart';
import 'package:BeatNow/Models/UserSingleton.dart';
import 'package:BeatNow/Screens/HomeScreen/LyricEditorPage.dart';
import 'package:BeatNow/Screens/HomeScreen/LyricScreen.dart';
import 'package:BeatNow/Screens/HomeScreen/saved_screen.dart';
import 'package:BeatNow/services/api_client.dart';
import 'package:BeatNow/services/beatnow_service.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:share_plus/share_plus.dart';

class HomeScreenState extends StatefulWidget {
  const HomeScreenState({super.key});

  @override
  State<HomeScreenState> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreenState> with WidgetsBindingObserver {
  final AuthController _authController = Get.find<AuthController>();
  final BeatNowService _beatNowService = BeatNowService();
  final PageController _pageController = PageController();
  final List<Posts> _posts = <Posts>[];
  late final AudioPlayer _audioPlayer;

  int _selectedIndex = 1;
  int _currentIndex = 0;
  bool _isPlaying = false;
  bool _isInitialLoading = true;
  bool _isFetching = false;
  String? _currentAudioUrl;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _audioPlayer = AudioPlayer()..setReleaseMode(ReleaseMode.stop);
    _audioPlayer.onPlayerStateChanged.listen((state) {
      if (!mounted) return;
      setState(() => _isPlaying = state == PlayerState.playing);
    });

    _loadInitialPosts();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _audioPlayer.dispose();
    _pageController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused || state == AppLifecycleState.detached) {
      _audioPlayer.stop();
    }
  }

  Future<void> _loadInitialPosts() async {
    setState(() => _isInitialLoading = true);
    await _loadMorePosts(forceCount: 5);
    if (_posts.isNotEmpty) {
      await _activatePost(0);
    }
    if (mounted) {
      setState(() => _isInitialLoading = false);
    }
  }

  Future<void> _loadMorePosts({int forceCount = 4}) async {
    if (_isFetching) return;
    _isFetching = true;

    try {
      final newPosts = await _beatNowService.getRandomFeedPosts(
        count: forceCount,
        excludeIds: _posts.map((post) => post.id).toSet(),
      );
      if (!mounted || newPosts.isEmpty) return;
      setState(() => _posts.addAll(newPosts));
    } catch (error) {
      debugPrint('Feed load error: $error');
    } finally {
      _isFetching = false;
    }
  }

  Future<void> _activatePost(int index) async {
    if (index < 0 || index >= _posts.length) return;

    _currentIndex = index;
    UserSingleton().current = index;

    final post = _posts[index];
    await _playAudio(post.audioUrl);
    try {
      await _beatNowService.registerView(post.id);
    } catch (error) {
      debugPrint('View register error: $error');
    }

    if (index >= _posts.length - 2) {
      _loadMorePosts();
    }

    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _playAudio(String url) async {
    if (_currentAudioUrl == url && _isPlaying) {
      return;
    }

    _currentAudioUrl = url;
    try {
      await _audioPlayer.stop();
      await _audioPlayer.play(UrlSource(url));
    } catch (error) {
      debugPrint('Audio error: $error');
    }
  }

  Future<void> _togglePlayback(Posts post) async {
    if (_isPlaying && _currentAudioUrl == post.audioUrl) {
      await _audioPlayer.pause();
      return;
    }
    await _playAudio(post.audioUrl);
  }

  Future<void> _toggleLike(Posts post, int index) async {
    final updated = post.copyWith(
      liked: !post.liked,
      likes: post.liked ? post.likes - 1 : post.likes + 1,
    );

    setState(() => _posts[index] = updated);

    try {
      if (updated.liked) {
        await _beatNowService.likePost(updated.id);
      } else {
        await _beatNowService.unlikePost(updated.id);
      }
    } on ApiException catch (error) {
      setState(() => _posts[index] = post);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.message)),
      );
    }
  }

  Future<void> _toggleSave(Posts post, int index) async {
    final updated = post.copyWith(
      saved: !post.saved,
      saves: post.saved ? post.saves - 1 : post.saves + 1,
    );

    setState(() => _posts[index] = updated);

    try {
      if (updated.saved) {
        await _beatNowService.savePost(updated.id);
      } else {
        await _beatNowService.unsavePost(updated.id);
      }
    } on ApiException catch (error) {
      setState(() => _posts[index] = post);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.message)),
      );
    }
  }

  void _openBeatDetails(Posts post) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF111111),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  post.title,
                  style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: Colors.white),
                ),
                const SizedBox(height: 10),
                Text(
                  post.description.isEmpty ? 'No description added yet.' : post.description,
                  style: const TextStyle(color: Colors.white70, height: 1.5),
                ),
                const SizedBox(height: 18),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    if (post.genre.isNotEmpty) _metaChip(post.genre),
                    if (post.bpm != null) _metaChip('${post.bpm} BPM'),
                    ...post.tags.map((tag) => _metaChip(tag)),
                    ...post.moods.map((mood) => _metaChip(mood)),
                    ...post.instruments.map((instrument) => _metaChip(instrument)),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _openProfile(Posts post) {
    OtherUserSingleton()
      ..username = post.username
      ..id = post.userId
      ..profileImageUrl = post.userPhotoProfile;
    _authController.changeTab(AuthTabs.otherProfile);
  }

  void _openLyricEditorForBeat(Posts post) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => LyricEditorPage(
          title: post.title,
          lyric: '',
          associatedPostId: post.id,
          associatedBeatTitle: post.title,
          isEditing: false,
        ),
      ),
    );
  }

  Widget _metaChip(String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: Colors.white.withOpacity(0.08),
      ),
      child: Text(
        value,
        style: const TextStyle(color: Colors.white, fontSize: 12),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final showFeedAppBar = _selectedIndex == 1 && _posts.isNotEmpty;

    return Scaffold(
      backgroundColor: const Color(0xFF050505),
      appBar: showFeedAppBar
          ? AppBar(
              backgroundColor: const Color(0xFF050505),
              elevation: 0,
              leading: IconButton(
                onPressed: () => _authController.changeTab(AuthTabs.profile),
                icon: CircleAvatar(
                  backgroundImage: NetworkImage(UserSingleton().profileImageUrl),
                ),
              ),
              title: Text(
                '@${_posts[_currentIndex].username}',
                style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w700),
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
      bottomNavigationBar: _buildBottomBar(),
    );
  }

  Widget _buildFeed() {
    if (_isInitialLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_posts.isEmpty) {
      return const Center(
        child: Text(
          'No beats available right now.',
          style: TextStyle(color: Colors.white70),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () async {
        _posts.clear();
        _currentIndex = 0;
        await _loadInitialPosts();
      },
      child: PageView.builder(
        controller: _pageController,
        scrollDirection: Axis.vertical,
        itemCount: _posts.length,
        onPageChanged: _activatePost,
        itemBuilder: (_, index) {
          final post = _posts[index];
          return Stack(
            fit: StackFit.expand,
            children: [
              GestureDetector(
                onTap: () => _togglePlayback(post),
                child: Image.network(
                  post.coverImageUrl,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(color: Colors.black),
                ),
              ),
              Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.transparent,
                      Color.fromRGBO(0, 0, 0, 0.18),
                      Color.fromRGBO(0, 0, 0, 0.72),
                    ],
                  ),
                ),
              ),
              Positioned(
                left: 16,
                right: 96,
                bottom: 32,
                child: _buildPostInfo(post),
              ),
              Positioned(
                right: 12,
                bottom: 28,
                child: _buildActions(post, index),
              ),
              if (index == _posts.length - 1 && _isFetching)
                const Positioned(
                  top: 20,
                  right: 20,
                  child: SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildPostInfo(Posts post) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTap: () => _openProfile(post),
          child: Text(
            '@${post.username}',
            style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          post.title,
          style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w800, height: 1.05),
        ),
        if (post.description.isNotEmpty) ...[
          const SizedBox(height: 10),
          Text(
            post.description,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Colors.white70, height: 1.5),
          ),
        ],
        const SizedBox(height: 14),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            if (post.genre.isNotEmpty) _metaChip(post.genre),
            if (post.bpm != null) _metaChip('${post.bpm} BPM'),
            if (post.tags.isNotEmpty) _metaChip(post.tags.first),
          ],
        ),
      ],
    );
  }

  Widget _buildActions(Posts post, int index) {
    return Column(
      children: [
        GestureDetector(
          onTap: () => _openProfile(post),
          child: CircleAvatar(
            radius: 24,
            backgroundImage: NetworkImage(post.userPhotoProfile),
          ),
        ),
        const SizedBox(height: 18),
        _ActionButton(
          icon: Icons.favorite,
          color: post.liked ? const Color(0xFF8731E4) : Colors.white,
          label: '${post.likes}',
          onTap: () => _toggleLike(post, index),
        ),
        const SizedBox(height: 16),
        _ActionButton(
          icon: Icons.bookmark,
          color: post.saved ? Colors.amber : Colors.white,
          label: '${post.saves}',
          onTap: () => _toggleSave(post, index),
        ),
        const SizedBox(height: 16),
        _ActionButton(
          icon: Icons.notes_rounded,
          color: Colors.white,
          label: 'Write',
          onTap: () => _openLyricEditorForBeat(post),
        ),
        const SizedBox(height: 16),
        _ActionButton(
          icon: Icons.info_outline,
          color: Colors.white,
          label: 'Info',
          onTap: () => _openBeatDetails(post),
        ),
        const SizedBox(height: 16),
        _ActionButton(
          icon: Icons.ios_share,
          color: Colors.white,
          label: 'Share',
          onTap: () => Share.share('BeatNow\n${post.title}\n${post.description}\n${post.audioUrl}'),
        ),
      ],
    );
  }

  Widget _buildBottomBar() {
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
            Icons.bookmark_rounded,
            color: _selectedIndex == 0 ? const Color(0xFF8731E4) : Colors.white,
          ),
          label: '',
        ),
        BottomNavigationBarItem(
          icon: Icon(
            Icons.play_circle_fill_rounded,
            size: 34,
            color: _selectedIndex == 1 ? const Color(0xFF8731E4) : Colors.white,
          ),
          label: '',
        ),
        BottomNavigationBarItem(
          icon: Icon(
            Icons.edit_note_rounded,
            color: _selectedIndex == 2 ? const Color(0xFF8731E4) : Colors.white,
          ),
          label: '',
        ),
      ],
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    required this.color,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final Color color;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        GestureDetector(
          onTap: onTap,
          child: Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.black.withOpacity(0.28),
            ),
            child: Icon(icon, color: color, size: 28),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          label,
          style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
        ),
      ],
    );
  }
}
