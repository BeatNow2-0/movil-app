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
  bool _showPlayHint = false;
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

    if (index >= _posts.length - 3) {
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
    } else {
      await _playAudio(post.audioUrl);
    }

    if (!mounted) return;
    setState(() => _showPlayHint = true);
    Future<void>.delayed(const Duration(milliseconds: 450), () {
      if (mounted) {
        setState(() => _showPlayHint = false);
      }
    });
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
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.message)));
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
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.message)));
    }
  }

  void _openBeatDetails(Posts post) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF0E0E12),
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
                  style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: Colors.white),
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
                    ...post.tags.map(_metaChip),
                    ...post.moods.map(_metaChip),
                    ...post.instruments.map(_metaChip),
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
        color: Colors.white.withValues(alpha: 0.1),
      ),
      child: Text(
        value,
        style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w500),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF050505),
      extendBody: true,
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

    return Stack(
      children: [
        PageView.builder(
          controller: _pageController,
          scrollDirection: Axis.vertical,
          physics: const PageScrollPhysics(),
          padEnds: false,
          itemCount: _posts.length,
          onPageChanged: _activatePost,
          itemBuilder: (_, index) {
            final post = _posts[index];
            return Stack(
              fit: StackFit.expand,
              children: [
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => _togglePlayback(post),
                  onDoubleTap: () => _toggleLike(post, index),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Image.network(
                        post.coverImageUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(color: Colors.black),
                      ),
                      Container(
                        color: Colors.black.withValues(alpha: 0.14),
                      ),
                    ],
                  ),
                ),
                Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Color.fromRGBO(0, 0, 0, 0.24),
                        Colors.transparent,
                        Color.fromRGBO(0, 0, 0, 0.28),
                        Color.fromRGBO(0, 0, 0, 0.9),
                      ],
                    ),
                  ),
                ),
                Positioned(
                  left: 16,
                  right: 16,
                  bottom: 104,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(child: _buildPostInfo(post)),
                      const SizedBox(width: 16),
                      _buildActions(post, index),
                    ],
                  ),
                ),
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 88,
                  child: Center(
                    child: Container(
                      width: 38,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
        _buildTopChrome(),
        if (_showPlayHint)
          const Center(
            child: Icon(
              Icons.play_arrow_rounded,
              size: 92,
              color: Colors.white70,
            ),
          ),
        if (_isFetching)
          const Positioned(
            top: 90,
            right: 20,
            child: SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
      ],
    );
  }

  void _openChat() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Chat will be available soon.')),
    );
  }

  Widget _buildTopChrome() {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                GestureDetector(
                  onTap: () => _authController.changeTab(AuthTabs.profile),
                  child: Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white.withValues(alpha: 0.16)),
                    ),
                    child: CircleAvatar(
                      radius: 20,
                      backgroundColor: const Color(0xFF16161D),
                      backgroundImage: NetworkImage(UserSingleton().profileImageUrl),
                    ),
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(999),
                    color: Colors.black.withValues(alpha: 0.3),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 9,
                        height: 9,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            colors: [Color(0xFFFF4D9D), Color(0xFF8731E4)],
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'BeatNow',
                        style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                GestureDetector(
                  onTap: _openChat,
                  child: Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.3),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                    ),
                    child: const Icon(Icons.chat_bubble_outline_rounded, color: Colors.white, size: 20),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildFeedTab(label: 'Siguiendo', isActive: false),
                const SizedBox(width: 20),
                _buildFeedTab(label: 'Para ti', isActive: true),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeedTab({required String label, required bool isActive}) {
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 180),
      opacity: isActive ? 1 : 0.55,
      child: Column(
        children: [
          Text(
            label,
            style: TextStyle(
              color: Colors.white,
              fontSize: isActive ? 17 : 15,
              fontWeight: isActive ? FontWeight.w800 : FontWeight.w600,
            ),
          ),
          const SizedBox(height: 7),
          Container(
            width: isActive ? 24 : 0,
            height: 3,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(999),
              gradient: const LinearGradient(colors: [Color(0xFFFF4D9D), Color(0xFF8731E4)]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPostInfo(Posts post) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(26),
        color: Colors.black.withValues(alpha: 0.28),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          GestureDetector(
            onTap: () => _openProfile(post),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white.withValues(alpha: 0.22)),
                    image: DecorationImage(image: NetworkImage(post.userPhotoProfile), fit: BoxFit.cover),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '@${post.username}',
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        'Beat ${_currentIndex + 1}',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.62),
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Text(
            post.title,
            style: const TextStyle(color: Colors.white, fontSize: 30, fontWeight: FontWeight.w900, height: 0.98),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              if (post.genre.isNotEmpty) _buildInlineBadge(post.genre),
              if (post.bpm != null) ...[
                const SizedBox(width: 8),
                _buildInlineBadge('${post.bpm} BPM'),
              ],
            ],
          ),
          if (post.description.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              post.description,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.78),
                height: 1.45,
                fontSize: 14,
              ),
            ),
          ],
          if (post.tags.isNotEmpty || post.moods.isNotEmpty) ...[
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ...post.tags.take(2).map((tag) => _metaChip('#$tag')),
                ...post.moods.take(1).map(_metaChip),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildActions(Posts post, int index) {
    return Column(
      children: [
        _ActionButton(
          icon: Icons.account_circle_outlined,
          color: Colors.white,
          label: 'Perfil',
          onTap: () => _openProfile(post),
        ),
        const SizedBox(height: 18),
        _ActionButton(
          icon: Icons.favorite,
          color: post.liked ? const Color(0xFF8731E4) : Colors.white,
          label: '${post.likes}',
          onTap: () => _toggleLike(post, index),
        ),
        const SizedBox(height: 18),
        _ActionButton(
          icon: Icons.bookmark,
          color: post.saved ? Colors.amber : Colors.white,
          label: '${post.saves}',
          onTap: () => _toggleSave(post, index),
        ),
        const SizedBox(height: 18),
        _ActionButton(
          icon: Icons.notes_rounded,
          color: Colors.white,
          label: 'Letras',
          onTap: () => _openLyricEditorForBeat(post),
        ),
        const SizedBox(height: 18),
        _ActionButton(
          icon: Icons.info_outline_rounded,
          color: Colors.white,
          label: 'Info',
          onTap: () => _openBeatDetails(post),
        ),
        const SizedBox(height: 18),
        _ActionButton(
          icon: Icons.ios_share_rounded,
          color: Colors.white,
          label: 'Share',
          onTap: () => SharePlus.instance.share(
            ShareParams(text: 'BeatNow\n${post.title}\n${post.description}\n${post.audioUrl}'),
          ),
        ),
      ],
    );
  }

  Widget _buildInlineBadge(String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: const Color(0xFF111118),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Text(
        value,
        style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700),
      ),
    );
  }

  Widget _buildBottomBar() {
    return SafeArea(
      minimum: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.32),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        ),
        child: BottomNavigationBar(
          currentIndex: _selectedIndex,
          backgroundColor: Colors.transparent,
          elevation: 0,
          type: BottomNavigationBarType.fixed,
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
              icon: Image.asset(
                'assets/images/icono_central_blanco.png',
                width: 28,
                height: 28,
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
        ),
      ),
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
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.black.withValues(alpha: 0.3),
              border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
            ),
            child: Icon(icon, color: color, size: 29),
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
