import 'dart:async';

import 'package:BeatNow/Controllers/auth_controller.dart';
import 'package:BeatNow/Models/OtherUserSingleton.dart';
import 'package:BeatNow/Models/Posts.dart';
import 'package:BeatNow/Models/media_defaults.dart';
import 'package:BeatNow/Models/UserSingleton.dart';
import 'package:BeatNow/Screens/HomeScreen/LyricEditorPage.dart';
import 'package:BeatNow/Screens/ProfileScreen/profileother_screen.dart';
import 'package:BeatNow/services/api_client.dart';
import 'package:BeatNow/services/audio_playback_service.dart';
import 'package:BeatNow/services/beatnow_service.dart';
import 'package:BeatNow/theme/beatnow_theme.dart';
import 'package:BeatNow/widgets/beatnow_logo.dart';
import 'package:BeatNow/widgets/cached_media_image.dart';
import 'package:BeatNow/widgets/profile_avatar.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:share_plus/share_plus.dart';

class HomeScreenState extends StatefulWidget {
  const HomeScreenState({super.key});

  @override
  State<HomeScreenState> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreenState> {
  final AuthController _authController = Get.find<AuthController>();
  final BeatNowService _beatNowService = BeatNowService();
  final List<Posts> _posts = <Posts>[];
  final Set<String> _viewedPostIds = <String>{};
  final PageController _pageController = PageController();
  final AudioPlaybackService _audioPlayback = AudioPlaybackService.instance;
  late final StreamSubscription<BeatInteractionChange> _interactionSubscription;
  late final Worker _tabWorker;
  final Set<String> _pendingLikeIds = <String>{};
  final Set<String> _pendingSaveIds = <String>{};
  Timer? _likeFeedbackTimer;

  int _currentIndex = 0;
  bool _isInitialLoading = true;
  bool _isFetching = false;
  bool _hasFeedError = false;
  String? _likeFeedbackPostId;
  String? _currentAudioUrl;

  @override
  void initState() {
    super.initState();
    _tabWorker = ever<int>(_authController.selectedIndex, (index) {
      if (index != AuthTabs.home) unawaited(_audioPlayback.stop());
    });
    _interactionSubscription = _beatNowService.interactionChanges.listen(
      _applyInteractionChange,
    );

    _loadInitialPosts();
  }

  @override
  void dispose() {
    _tabWorker.dispose();
    unawaited(_interactionSubscription.cancel());
    _likeFeedbackTimer?.cancel();
    _pageController.dispose();
    unawaited(_audioPlayback.stop());
    super.dispose();
  }

  Future<void> _loadInitialPosts() async {
    if (mounted) setState(() => _isInitialLoading = true);
    await _loadMorePosts(forceCount: 5);
    if (_posts.isNotEmpty) {
      _currentIndex = 0;
      unawaited(_activatePost(0));
    }
    if (mounted) {
      setState(() => _isInitialLoading = false);
    }
  }

  Future<void> _loadMorePosts({int forceCount = 4}) async {
    if (_isFetching) return;
    _isFetching = true;
    if (mounted) setState(() => _hasFeedError = false);

    try {
      final newPosts = await _beatNowService.getRandomFeedPosts(
        count: forceCount,
        excludeIds: _posts.map((post) => post.id).toSet(),
      );
      if (!mounted) return;
      final existingIds = _posts.map((post) => post.id).toSet();
      final uniquePosts = newPosts
          .where((post) => post.id.isNotEmpty && existingIds.add(post.id))
          .toList();
      setState(() {
        _posts.addAll(uniquePosts);
        _hasFeedError = false;
      });
    } catch (error) {
      debugPrint('Feed load error: $error');
      if (mounted) setState(() => _hasFeedError = true);
    } finally {
      _isFetching = false;
    }
  }

  Future<void> _activatePost(int index) async {
    if (index < 0 || index >= _posts.length) return;

    _currentIndex = index;
    UserSingleton().current = index;

    final post = _posts[index];
    final nextAudioUrl =
        index + 1 < _posts.length ? _posts[index + 1].audioUrl : null;
    unawaited(_playAudio(post.audioUrl, nextUrl: nextAudioUrl));
    if (_viewedPostIds.add(post.id)) {
      unawaited(_registerPostView(post.id));
    }

    if (index >= _posts.length - 3) {
      unawaited(_loadMorePosts());
    }

    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _registerPostView(String postId) async {
    try {
      await _beatNowService.registerView(postId);
    } catch (error) {
      debugPrint('View register error: $error');
    }
  }

  Future<void> _playAudio(String url, {String? nextUrl}) async {
    _currentAudioUrl = url;
    await _audioPlayback.play(url, nextUrl: nextUrl);
  }

  Future<void> _pauseAudio() async {
    await _audioPlayback.pause();
  }

  Future<void> _retryFeed() async {
    if (_posts.isEmpty) {
      await _loadInitialPosts();
    } else {
      await _loadMorePosts();
    }
  }

  void _applyInteractionChange(BeatInteractionChange change) {
    final index = _posts.indexWhere((post) => post.id == change.postId);
    if (index < 0) return;
    final current = _posts[index];
    var updated = current;
    if (change.liked != null && change.liked != current.liked) {
      updated = updated.copyWith(
        liked: change.liked,
        likes: _adjustCount(current.likes, change.liked!),
      );
    }
    if (change.saved != null && change.saved != current.saved) {
      updated = updated.copyWith(
        saved: change.saved,
        saves: _adjustCount(current.saves, change.saved!),
      );
    }
    if (identical(updated, current)) return;
    if (mounted) setState(() => _posts[index] = updated);
  }

  int _adjustCount(int count, bool enabled) {
    final nonNegativeCount = count < 0 ? 0 : count;
    return enabled
        ? nonNegativeCount + 1
        : (nonNegativeCount > 0 ? nonNegativeCount - 1 : 0);
  }

  Future<void> _toggleLike(Posts post) async {
    if (!_pendingLikeIds.add(post.id)) return;
    final postIndex = _posts.indexWhere((item) => item.id == post.id);
    if (postIndex < 0) {
      _pendingLikeIds.remove(post.id);
      return;
    }
    final originalLiked = _posts[postIndex].liked;
    final targetLiked = !originalLiked;
    _applyInteractionChange(
      BeatInteractionChange(postId: post.id, liked: targetLiked),
    );
    _beatNowService.publishInteractionChange(post.id, liked: targetLiked);
    try {
      if (targetLiked) {
        await _beatNowService.likePost(post.id);
      } else {
        await _beatNowService.unlikePost(post.id);
      }
    } catch (error) {
      _applyInteractionChange(
        BeatInteractionChange(postId: post.id, liked: originalLiked),
      );
      _beatNowService.publishInteractionChange(post.id, liked: originalLiked);
      if (mounted) _showInteractionError(error, 'Could not update like.');
    } finally {
      _pendingLikeIds.remove(post.id);
    }
  }

  Future<void> _toggleSave(Posts post) async {
    if (!_pendingSaveIds.add(post.id)) return;
    final postIndex = _posts.indexWhere((item) => item.id == post.id);
    if (postIndex < 0) {
      _pendingSaveIds.remove(post.id);
      return;
    }
    final originalSaved = _posts[postIndex].saved;
    final targetSaved = !originalSaved;
    _applyInteractionChange(
      BeatInteractionChange(postId: post.id, saved: targetSaved),
    );
    _beatNowService.publishInteractionChange(post.id, saved: targetSaved);
    try {
      if (targetSaved) {
        await _beatNowService.savePost(post.id);
      } else {
        await _beatNowService.unsavePost(post.id);
      }
    } catch (error) {
      _applyInteractionChange(
        BeatInteractionChange(postId: post.id, saved: originalSaved),
      );
      _beatNowService.publishInteractionChange(post.id, saved: originalSaved);
      if (mounted) _showInteractionError(error, 'Could not update saved beat.');
    } finally {
      _pendingSaveIds.remove(post.id);
    }
  }

  void _showInteractionError(Object error, String fallback) {
    final message = error is ApiException ? error.userMessage : fallback;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  void _likeWithFeedback(Posts post) {
    _toggleLike(post);
    _likeFeedbackTimer?.cancel();
    setState(() => _likeFeedbackPostId = post.id);
    _likeFeedbackTimer = Timer(const Duration(milliseconds: 520), () {
      if (mounted) setState(() => _likeFeedbackPostId = null);
    });
  }

  void _openBeatDetails(Posts post) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: BeatNowTokens.surface0,
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
                  style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      color: Colors.white),
                ),
                const SizedBox(height: 10),
                Text(
                  post.description.isEmpty
                      ? 'No description added yet.'
                      : post.description,
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
    unawaited(_audioPlayback.stop());
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ProfileOtherScreen()),
    );
  }

  void _openLyricEditorForBeat(Posts post) {
    unawaited(_audioPlayback.stop());
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
        borderRadius: BorderRadius.circular(BeatNowTokens.radiusPill),
        color: Colors.white.withValues(alpha: 0.1),
      ),
      child: Text(
        value,
        style: const TextStyle(
            color: Colors.white, fontSize: 12, fontWeight: FontWeight.w500),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: BeatNowTokens.background,
      body: _buildFeed(),
    );
  }

  Widget _buildFeed() {
    if (_isInitialLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_posts.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('No beats available right now.',
                style: TextStyle(color: Colors.white70)),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: _isFetching ? null : _retryFeed,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    return Stack(
      children: [
        PageView.builder(
          controller: _pageController,
          scrollDirection: Axis.vertical,
          itemCount: _posts.length,
          onPageChanged: (index) => unawaited(_activatePost(index)),
          itemBuilder: (_, index) {
            final post = _posts[index];
            return _buildFeedCard(post, index);
          },
        ),
        _buildTopChrome(),
        if (_hasFeedError && !_isFetching)
          Positioned(
            right: 16,
            bottom: 104,
            child: FilledButton.tonalIcon(
              onPressed: _retryFeed,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Retry loading'),
            ),
          ),
      ],
    );
  }

  void _openSearch() {
    _authController.changeTab(AuthTabs.search);
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
                  child: ProfileAvatar(
                    imageUrl: UserSingleton().profileImageUrl,
                    initial: UserSingleton().username,
                    size: 42,
                    borderWidth: 1,
                    borderColor: Colors.white.withValues(alpha: 0.16),
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 11),
                  decoration: BoxDecoration(
                    borderRadius:
                        BorderRadius.circular(BeatNowTokens.radiusPill),
                    color: Colors.black.withValues(alpha: 0.28),
                    border:
                        Border.all(color: Colors.white.withValues(alpha: 0.08)),
                  ),
                  child: const SizedBox(
                    height: 42,
                    child: Center(
                      child: BeatNowLogo(size: 24, subtitle: null),
                    ),
                  ),
                ),
                const Spacer(),
                GestureDetector(
                  onTap: _openSearch,
                  child: Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.3),
                      shape: BoxShape.circle,
                      border: Border.all(
                          color: Colors.white.withValues(alpha: 0.08)),
                    ),
                    child: const Icon(Icons.search_rounded,
                        color: Colors.white, size: 20),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeedCard(Posts post, int index) {
    final isCurrent = index == _currentIndex;
    return GestureDetector(
      onTap: () async {
        if (index != _currentIndex) {
          await _activatePost(index);
        } else if (_audioPlayback.isPlaying &&
            _currentAudioUrl == post.audioUrl) {
          await _pauseAudio();
        } else {
          await _playAudio(post.audioUrl);
        }
      },
      onDoubleTap: () => _likeWithFeedback(post),
      child: Stack(
        fit: StackFit.expand,
        children: [
          CachedMediaImage(
            url: post.coverImageUrl,
            fallbackAsset: MediaDefaults.coverImage,
            cacheWidth: (MediaQuery.sizeOf(context).width *
                    MediaQuery.devicePixelRatioOf(context))
                .round(),
          ),
          IgnorePointer(
            child: Center(
              child: AnimatedScale(
                scale: _likeFeedbackPostId == post.id ? 1 : 0.72,
                duration: const Duration(milliseconds: 170),
                curve: Curves.easeOutBack,
                child: AnimatedOpacity(
                  opacity: _likeFeedbackPostId == post.id ? 1 : 0,
                  duration: const Duration(milliseconds: 180),
                  child: const Icon(
                    Icons.favorite_rounded,
                    color: BeatNowTokens.rose,
                    size: 82,
                    shadows: [Shadow(color: Colors.black38, blurRadius: 14)],
                  ),
                ),
              ),
            ),
          ),
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withValues(alpha: 0.04),
                  Colors.transparent,
                  Colors.black.withValues(alpha: 0.62),
                ],
              ),
            ),
          ),
          Positioned(
            left: 16,
            right: 16,
            bottom: BeatNowTokens.space4,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(child: _buildPostInfo(post, isCurrent)),
                const SizedBox(width: 14),
                _buildActions(post),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPostInfo(Posts post, bool isCurrent) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTap: () => _openProfile(post),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              ProfileAvatar(
                imageUrl: post.userPhotoProfile,
                initial: post.username,
                size: 34,
                borderWidth: 1,
                borderColor: Colors.white.withValues(alpha: 0.22),
              ),
              const SizedBox(width: 10),
              Flexible(
                child: Text(
                  '@${post.username}',
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: BeatNowTokens.space2),
        Text(
          post.title,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 24,
            fontWeight: FontWeight.w800,
            height: 1.08,
            shadows: [
              Shadow(
                  color: Colors.black54, blurRadius: 12, offset: Offset(0, 1)),
            ],
          ),
        ),
        const SizedBox(height: BeatNowTokens.space2),
        Wrap(
          spacing: BeatNowTokens.space2,
          runSpacing: BeatNowTokens.space1,
          children: [
            if (post.genre.isNotEmpty) _buildInlineBadge(post.genre),
            if (post.bpm != null) _buildInlineBadge('${post.bpm} BPM'),
          ],
        ),
        if (isCurrent && _currentAudioUrl == post.audioUrl) ...[
          const SizedBox(height: BeatNowTokens.space2),
          _buildPlaybackIndicator(),
        ],
      ],
    );
  }

  Widget _buildPlaybackIndicator() {
    return StreamBuilder<AudioPlaybackStatus>(
      stream: _audioPlayback.statusChanges,
      initialData: _audioPlayback.status,
      builder: (context, snapshot) {
        final status = snapshot.data ?? AudioPlaybackStatus.idle;
        final isBuffering = status == AudioPlaybackStatus.buffering;
        final hasError = status == AudioPlaybackStatus.error;
        final isPlaying = status == AudioPlaybackStatus.playing;
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.34),
            borderRadius: BorderRadius.circular(BeatNowTokens.radiusSmall),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isBuffering)
                const SizedBox(
                  width: 12,
                  height: 12,
                  child: CircularProgressIndicator(strokeWidth: 1.5),
                )
              else
                Icon(
                  hasError
                      ? Icons.error_outline_rounded
                      : isPlaying
                          ? Icons.graphic_eq_rounded
                          : Icons.play_arrow_rounded,
                  color: hasError ? BeatNowTokens.danger : Colors.white,
                  size: 14,
                ),
              const SizedBox(width: 4),
              Text(
                isBuffering
                    ? 'Loading'
                    : hasError
                        ? 'Unavailable'
                        : isPlaying
                            ? 'Playing'
                            : 'Paused',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildActions(Posts post) {
    return Column(
      children: [
        _ActionButton(
          icon: Icons.favorite,
          color: post.liked ? BeatNowTokens.rose : Colors.white,
          label: '${post.likes}',
          tooltip: 'Like',
          isActive: post.liked,
          onTap: _pendingLikeIds.contains(post.id)
              ? null
              : () => _toggleLike(post),
        ),
        const SizedBox(height: BeatNowTokens.space2),
        _ActionButton(
          icon: Icons.bookmark,
          color: post.saved ? BeatNowTokens.accentSoft : Colors.white,
          label: '${post.saves}',
          tooltip: 'Save',
          isActive: post.saved,
          onTap: _pendingSaveIds.contains(post.id)
              ? null
              : () => _toggleSave(post),
        ),
        const SizedBox(height: BeatNowTokens.space2),
        _ActionButton(
          icon: Icons.notes_rounded,
          color: Colors.white,
          label: 'Write',
          tooltip: 'Write lyrics',
          onTap: () => _openLyricEditorForBeat(post),
        ),
        const SizedBox(height: BeatNowTokens.space2),
        _ActionButton(
          icon: Icons.info_outline_rounded,
          color: Colors.white,
          label: 'Info',
          tooltip: 'Beat details',
          onTap: () => _openBeatDetails(post),
        ),
        const SizedBox(height: BeatNowTokens.space2),
        _ActionButton(
          icon: Icons.ios_share_rounded,
          color: Colors.white,
          label: 'Share',
          tooltip: 'Share beat',
          onTap: () => SharePlus.instance.share(
            ShareParams(
                text:
                    'BeatNow\n${post.title}\n${post.description}\n${post.audioUrl}'),
          ),
        ),
      ],
    );
  }

  Widget _buildInlineBadge(String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(BeatNowTokens.radiusPill),
        color: Colors.black.withValues(alpha: 0.26),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Text(
        value,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
            color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    required this.color,
    required this.label,
    required this.tooltip,
    this.isActive = false,
    required this.onTap,
  });

  final IconData icon;
  final Color color;
  final String label;
  final String tooltip;
  final bool isActive;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        IconButton(
          tooltip: tooltip,
          onPressed: onTap,
          style: IconButton.styleFrom(
            minimumSize: const Size(48, 48),
            fixedSize: const Size(48, 48),
            padding: EdgeInsets.zero,
            backgroundColor: Colors.black.withValues(alpha: 0.34),
            foregroundColor: color,
            side: BorderSide(color: Colors.white.withValues(alpha: 0.12)),
          ),
          icon: TweenAnimationBuilder<double>(
            key: ValueKey(isActive),
            tween: Tween(begin: 1.2, end: 1),
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOutBack,
            builder: (context, scale, child) =>
                Transform.scale(scale: scale, child: child),
            child: Icon(icon, size: 21),
          ),
        ),
        const SizedBox(height: BeatNowTokens.space1),
        Text(
          label,
          style: const TextStyle(
              color: Colors.white, fontSize: 10, fontWeight: FontWeight.w600),
        ),
      ],
    );
  }
}
