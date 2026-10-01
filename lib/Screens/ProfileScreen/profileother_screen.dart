import 'dart:async';

import 'package:BeatNow/Models/OtherUserSingleton.dart';
import 'package:BeatNow/Models/Posts.dart';
import 'package:BeatNow/Models/media_defaults.dart';
import 'package:BeatNow/services/api_client.dart';
import 'package:BeatNow/services/audio_playback_service.dart';
import 'package:BeatNow/services/beatnow_service.dart';
import 'package:BeatNow/theme/beatnow_theme.dart';
import 'package:BeatNow/widgets/cached_media_image.dart';
import 'package:flutter/material.dart';

class ProfileOtherScreen extends StatefulWidget {
  const ProfileOtherScreen({super.key});

  @override
  State<ProfileOtherScreen> createState() => _ProfileOtherScreenState();
}

class _ProfileOtherScreenState extends State<ProfileOtherScreen> {
  final BeatNowService _beatNowService = BeatNowService();
  final AudioPlaybackService _audioPlayback = AudioPlaybackService.instance;
  final OtherUserSingleton _user = OtherUserSingleton();

  List<Posts>? _posts;
  String _fullName = '';
  int _followers = 0;
  int _following = 0;
  int? _publishedBeatCount;
  bool _isFollowingUser = false;
  bool _isUpdatingFollow = false;

  @override
  void initState() {
    super.initState();
    _initializeProfileData();
  }

  Future<void> _initializeProfileData() async {
    final userId = _user.id;
    final requestedUsername = _user.username;
    unawaited(_fetchUserPosts(requestedUsername));

    if (userId.isEmpty) return;
    try {
      final profile = await _beatNowService.getUserProfile(userId);
      final username = profile['username']?.toString().trim();
      final fullName = profile['full_name']?.toString().trim() ?? '';
      _user.name = fullName;
      if (username != null && username.isNotEmpty) _user.username = username;
      _user.profileImageUrl = MediaDefaults.profileUrl(profile);
      if (!mounted) return;
      setState(() {
        _fullName = fullName;
        _followers = _asInt(profile['followers']);
        _following = _asInt(profile['following']);
        _publishedBeatCount = _asInt(profile['post_num']);
        _isFollowingUser = profile['is_following'] == true;
      });
      if (username != null &&
          username.isNotEmpty &&
          username != requestedUsername) {
        unawaited(_fetchUserPosts(username));
      }
    } catch (error) {
      debugPrint('Error fetching producer profile: $error');
    }
  }

  Future<void> _fetchUserPosts(String username) async {
    if (username.isEmpty) {
      if (mounted) setState(() => _posts = <Posts>[]);
      return;
    }
    try {
      final posts = await _beatNowService.getUserPosts(username);
      if (mounted) setState(() => _posts = posts);
    } catch (error) {
      debugPrint('Error fetching producer beats: $error');
      if (mounted) setState(() => _posts = <Posts>[]);
    }
  }

  Future<void> _toggleFollow() async {
    final userId = _user.id;
    if (_isUpdatingFollow || userId.isEmpty) return;

    final wasFollowing = _isFollowingUser;
    final previousFollowers = _followers;
    setState(() {
      _isUpdatingFollow = true;
      _isFollowingUser = !wasFollowing;
      _followers =
          (previousFollowers + (wasFollowing ? -1 : 1)).clamp(0, 1 << 30);
    });

    try {
      if (wasFollowing) {
        await _beatNowService.unfollowUser(userId);
      } else {
        await _beatNowService.followUser(userId);
      }
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _isFollowingUser = wasFollowing;
        _followers = previousFollowers;
      });
      final message = error is ApiException
          ? error.userMessage
          : 'Could not update follow status. Please try again.';
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));
    } finally {
      if (mounted) setState(() => _isUpdatingFollow = false);
    }
  }

  Future<void> _openBeatViewer(int index) async {
    if (_posts == null || index < 0 || index >= _posts!.length) return;
    await _audioPlayback.stop();
    if (!mounted) return;
    await Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) => ProfileBeatViewer(
          posts: _posts!,
          initialIndex: index,
          producerName: _user.username,
        ),
      ),
    );
  }

  @override
  void dispose() {
    unawaited(_audioPlayback.stop());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final username = _user.username;
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          '@$username',
          style: const TextStyle(
              fontWeight: FontWeight.bold, fontSize: 20, color: Colors.white),
        ),
        centerTitle: true,
      ),
      body: Container(
        color: BeatNowTokens.background,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ClipOval(
                  child: CachedMediaImage(
                    url: _user.profileImageUrl,
                    fallbackAsset: MediaDefaults.profileImage,
                    width: 84,
                    height: 84,
                  ),
                ),
                const SizedBox(width: 12),
                Row(
                  children: [
                    _buildStatColumn('Beats',
                        '${_publishedBeatCount ?? _posts?.length ?? 0}'),
                    const SizedBox(width: 12),
                    _buildStatColumn('Following', '$_following'),
                    const SizedBox(width: 12),
                    _buildStatColumn('Followers', '$_followers'),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 30),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_fullName.isNotEmpty)
                      Text(
                        _fullName,
                        style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.white),
                      ),
                    Text('@$username',
                        style: const TextStyle(
                            fontSize: 14, color: Colors.white70)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: _isUpdatingFollow ? null : _toggleFollow,
                  child: Text(
                    _isFollowingUser ? 'Following' : 'Follow',
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 18),
            Expanded(
              child: _posts == null
                  ? const Center(child: CircularProgressIndicator())
                  : _posts!.isEmpty
                      ? const Center(
                          child: Text('No beats yet',
                              style: TextStyle(color: Colors.white70)),
                        )
                      : GridView.builder(
                          padding: const EdgeInsets.all(10),
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 3,
                            mainAxisSpacing: 10,
                            crossAxisSpacing: 10,
                            childAspectRatio: 9 / 16,
                          ),
                          itemCount: _posts!.length,
                          itemBuilder: (context, index) =>
                              _buildBeatTile(index),
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBeatTile(int index) {
    final post = _posts![index];
    final hasAudio = post.audioUrl.isNotEmpty;
    return ClipRRect(
      borderRadius: BorderRadius.circular(BeatNowTokens.radiusMedium),
      child: Material(
        color: Colors.white.withValues(alpha: 0.08),
        child: InkWell(
          onTap: () => _openBeatViewer(index),
          child: Stack(
            fit: StackFit.expand,
            children: [
              CachedMediaImage(
                url: post.coverImageUrl,
                fallbackAsset: MediaDefaults.coverImage,
              ),
              Align(
                alignment: Alignment.bottomCenter,
                child: Container(
                  width: double.infinity,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
                  color: Colors.black54,
                  child: Text(
                    post.title.isEmpty ? 'Untitled beat' : post.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                  ),
                ),
              ),
              if (hasAudio)
                Center(
                  child: Icon(
                    Icons.play_circle_fill,
                    size: 38,
                    color: Colors.white,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatColumn(String label, String count) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(count, style: Theme.of(context).textTheme.titleMedium),
        Text(label, style: Theme.of(context).textTheme.labelSmall),
      ],
    );
  }

  int _asInt(dynamic value) {
    if (value is int) return value.clamp(0, 1 << 30);
    if (value is double) return value.round().clamp(0, 1 << 30);
    return (int.tryParse(value?.toString() ?? '') ?? 0).clamp(0, 1 << 30);
  }
}

class ProfileBeatViewer extends StatefulWidget {
  const ProfileBeatViewer({
    super.key,
    required this.posts,
    required this.initialIndex,
    required this.producerName,
  });

  final List<Posts> posts;
  final int initialIndex;
  final String producerName;

  @override
  State<ProfileBeatViewer> createState() => _ProfileBeatViewerState();
}

class _ProfileBeatViewerState extends State<ProfileBeatViewer> {
  final AudioPlaybackService _audioPlayback = AudioPlaybackService.instance;
  final BeatNowService _beatNowService = BeatNowService();
  late final PageController _pageController;
  late final StreamSubscription<AudioPlaybackStatus> _audioSubscription;
  late final StreamSubscription<BeatInteractionChange> _interactionSubscription;
  late List<Posts> _posts;
  late int _currentIndex;
  AudioPlaybackStatus _audioStatus = AudioPlaybackStatus.idle;
  final Set<String> _pendingLikeIds = <String>{};
  final Set<String> _pendingSaveIds = <String>{};

  @override
  void initState() {
    super.initState();
    _posts = List<Posts>.of(widget.posts);
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
    _audioStatus = _audioPlayback.status;
    _audioSubscription = _audioPlayback.statusChanges.listen((status) {
      if (mounted) setState(() => _audioStatus = status);
    });
    _interactionSubscription =
        _beatNowService.interactionChanges.listen(_applyInteractionChange);
    unawaited(_activateBeat(_currentIndex));
  }

  @override
  void dispose() {
    unawaited(_audioSubscription.cancel());
    unawaited(_interactionSubscription.cancel());
    _pageController.dispose();
    unawaited(_audioPlayback.stop());
    super.dispose();
  }

  void _applyInteractionChange(BeatInteractionChange change) {
    final index = _posts.indexWhere((post) => post.id == change.postId);
    if (index < 0) return;
    final post = _posts[index];
    final updated = post.copyWith(
      liked: change.liked,
      likes: change.liked == null || change.liked == post.liked
          ? post.likes
          : _adjustCount(post.likes, change.liked!),
      saved: change.saved,
      saves: change.saved == null || change.saved == post.saved
          ? post.saves
          : _adjustCount(post.saves, change.saved!),
    );
    if (mounted) setState(() => _posts[index] = updated);
  }

  int _adjustCount(int count, bool enabled) {
    final current = count.clamp(0, 1 << 30).toInt();
    return enabled ? current + 1 : (current > 0 ? current - 1 : 0);
  }

  Future<void> _activateBeat(int index) async {
    if (index < 0 || index >= _posts.length) return;
    _currentIndex = index;
    final post = _posts[index];
    final nextUrl =
        index + 1 < _posts.length ? _posts[index + 1].audioUrl : null;
    if (mounted) setState(() {});
    if (post.audioUrl.isNotEmpty) {
      await _audioPlayback.play(post.audioUrl, nextUrl: nextUrl);
    } else {
      await _audioPlayback.stop();
    }
  }

  Future<void> _togglePlayback() async {
    final post = _posts[_currentIndex];
    if (post.audioUrl.isEmpty) return;
    if (_audioStatus == AudioPlaybackStatus.playing ||
        _audioStatus == AudioPlaybackStatus.buffering) {
      await _audioPlayback.pause();
    } else if (_audioStatus == AudioPlaybackStatus.paused) {
      await _audioPlayback.resume();
    } else {
      await _audioPlayback.play(post.audioUrl);
    }
  }

  Future<void> _toggleLike(Posts post) async {
    if (post.id.isEmpty) return;
    if (!_pendingLikeIds.add(post.id)) return;
    final index = _posts.indexWhere((item) => item.id == post.id);
    if (index < 0) {
      _pendingLikeIds.remove(post.id);
      return;
    }
    final target = !_posts[index].liked;
    _updatePost(post.id, liked: target);
    _beatNowService.publishInteractionChange(post.id, liked: target);
    try {
      if (target) {
        await _beatNowService.likePost(post.id);
      } else {
        await _beatNowService.unlikePost(post.id);
      }
    } catch (error) {
      _updatePost(post.id, liked: !target);
      _beatNowService.publishInteractionChange(post.id, liked: !target);
      _showActionError(error, 'Could not update like.');
    } finally {
      _pendingLikeIds.remove(post.id);
    }
  }

  Future<void> _toggleSave(Posts post) async {
    if (post.id.isEmpty) return;
    if (!_pendingSaveIds.add(post.id)) return;
    final index = _posts.indexWhere((item) => item.id == post.id);
    if (index < 0) {
      _pendingSaveIds.remove(post.id);
      return;
    }
    final target = !_posts[index].saved;
    _updatePost(post.id, saved: target);
    _beatNowService.publishInteractionChange(post.id, saved: target);
    try {
      if (target) {
        await _beatNowService.savePost(post.id);
      } else {
        await _beatNowService.unsavePost(post.id);
      }
    } catch (error) {
      _updatePost(post.id, saved: !target);
      _beatNowService.publishInteractionChange(post.id, saved: !target);
      _showActionError(error, 'Could not update saved beat.');
    } finally {
      _pendingSaveIds.remove(post.id);
    }
  }

  void _updatePost(String postId, {bool? liked, bool? saved}) {
    final index = _posts.indexWhere((post) => post.id == postId);
    if (index < 0 || !mounted) return;
    final post = _posts[index];
    setState(() {
      _posts[index] = post.copyWith(
        liked: liked,
        likes: liked == null || liked == post.liked
            ? post.likes
            : _adjustCount(post.likes, liked),
        saved: saved,
        saves: saved == null || saved == post.saved
            ? post.saves
            : _adjustCount(post.saves, saved),
      );
    });
  }

  void _showActionError(Object error, String fallback) {
    if (!mounted) return;
    final message = error is ApiException ? error.userMessage : fallback;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          PageView.builder(
            controller: _pageController,
            scrollDirection: Axis.vertical,
            itemCount: _posts.length,
            onPageChanged: (index) => unawaited(_activateBeat(index)),
            itemBuilder: (context, index) => _buildBeatPage(_posts[index]),
          ),
          SafeArea(
            child: Align(
              alignment: Alignment.topLeft,
              child: IconButton(
                tooltip: 'Back to producer',
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
              ),
            ),
          ),
          if (_audioStatus == AudioPlaybackStatus.buffering)
            const Center(
              child: SizedBox(
                width: 34,
                height: 34,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildBeatPage(Posts post) {
    return GestureDetector(
      onDoubleTap: () => _toggleLike(post),
      child: Stack(
        fit: StackFit.expand,
        children: [
          CachedMediaImage(
            url: post.coverImageUrl,
            fallbackAsset: MediaDefaults.coverImage,
          ),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.transparent, Colors.black87],
                stops: [0.45, 1],
              ),
            ),
          ),
          Positioned(
            right: 12,
            bottom: 112,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _BeatAction(
                  icon: post.liked
                      ? Icons.favorite_rounded
                      : Icons.favorite_border_rounded,
                  label: '${post.likes}',
                  semanticLabel: 'Like beat, ${post.likes} likes',
                  color: post.liked ? BeatNowTokens.rose : Colors.white,
                  onTap: _pendingLikeIds.contains(post.id)
                      ? null
                      : () => _toggleLike(post),
                ),
                const SizedBox(height: 22),
                _BeatAction(
                  icon: post.saved
                      ? Icons.bookmark_rounded
                      : Icons.bookmark_border_rounded,
                  label: '${post.saves}',
                  semanticLabel: 'Save beat, ${post.saves} saves',
                  color: post.saved ? BeatNowTokens.accentSoft : Colors.white,
                  onTap: _pendingSaveIds.contains(post.id)
                      ? null
                      : () => _toggleSave(post),
                ),
                const SizedBox(height: 22),
                IconButton.filledTonal(
                  tooltip: _audioStatus == AudioPlaybackStatus.playing
                      ? 'Pause beat'
                      : 'Play beat',
                  onPressed: _togglePlayback,
                  icon: Icon(
                    _audioStatus == AudioPlaybackStatus.playing
                        ? Icons.pause_rounded
                        : Icons.play_arrow_rounded,
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            left: 20,
            right: 88,
            bottom: 38,
            child: SafeArea(
              top: false,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '@${post.username.isNotEmpty ? post.username : widget.producerName}',
                    style: const TextStyle(
                      color: Colors.white70,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    post.title.isEmpty ? 'Untitled beat' : post.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 23,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  if (post.genre.isNotEmpty || post.bpm != null) ...[
                    const SizedBox(height: 7),
                    Text(
                      [
                        if (post.genre.isNotEmpty) post.genre,
                        if (post.bpm != null) '${post.bpm} BPM',
                      ].join('  ·  '),
                      style: const TextStyle(color: Colors.white70),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BeatAction extends StatelessWidget {
  const _BeatAction({
    required this.icon,
    required this.label,
    required this.semanticLabel,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String semanticLabel;
  final Color color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: semanticLabel,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(28),
        child: SizedBox(
          width: 52,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: color, size: 30),
              const SizedBox(height: 3),
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
