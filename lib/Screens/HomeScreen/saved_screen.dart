import 'dart:async';

import 'package:BeatNow/Models/SavedPost.dart';
import 'package:BeatNow/Models/media_defaults.dart';
import 'package:BeatNow/services/api_client.dart';
import 'package:BeatNow/services/audio_playback_service.dart';
import 'package:BeatNow/services/beatnow_service.dart';
import 'package:BeatNow/theme/beatnow_theme.dart';
import 'package:BeatNow/widgets/cached_media_image.dart';
import 'package:flutter/material.dart';

class SavedScreen extends StatefulWidget {
  const SavedScreen({super.key});

  @override
  State<SavedScreen> createState() => _SavedScreenState();
}

class _SavedScreenState extends State<SavedScreen> {
  final BeatNowService _beatNowService = BeatNowService();
  late Future<List<SavedPost>> _savedPostsFuture;
  late final StreamSubscription<BeatInteractionChange> _interactionSubscription;
  Timer? _savedRefreshDebounce;
  final Set<String> _hiddenPostIds = <String>{};
  final Set<String> _pendingUnsaveIds = <String>{};

  @override
  void initState() {
    super.initState();
    _savedPostsFuture = _beatNowService.getSavedPosts();
    _interactionSubscription = _beatNowService.interactionChanges.listen(
      _handleInteractionChange,
    );
  }

  @override
  void dispose() {
    _savedRefreshDebounce?.cancel();
    unawaited(_interactionSubscription.cancel());
    super.dispose();
  }

  Future<void> _refresh() async {
    late final Future<List<SavedPost>> refreshFuture;
    setState(() {
      refreshFuture = _savedPostsFuture = _beatNowService.getSavedPosts();
    });
    try {
      await refreshFuture;
    } catch (_) {
      // FutureBuilder renders the refresh error state.
    }
  }

  void _handleInteractionChange(BeatInteractionChange change) {
    if (change.saved == null || !mounted) return;
    setState(() {
      if (change.saved!) {
        _hiddenPostIds.remove(change.postId);
        _savedRefreshDebounce?.cancel();
        _savedRefreshDebounce = Timer(const Duration(milliseconds: 600), () {
          if (!mounted) return;
          setState(() {
            _savedPostsFuture = _beatNowService.getSavedPosts();
          });
        });
      } else {
        _savedRefreshDebounce?.cancel();
        _hiddenPostIds.add(change.postId);
      }
    });
  }

  Future<void> _unsave(SavedPost post) async {
    final postId = post.postId;
    if (postId.isEmpty || !_pendingUnsaveIds.add(postId)) return;
    setState(() => _hiddenPostIds.add(postId));
    _beatNowService.publishInteractionChange(postId, saved: false);
    try {
      await _beatNowService.unsavePost(postId);
    } catch (error) {
      _beatNowService.publishInteractionChange(postId, saved: true);
      if (mounted) {
        setState(() => _hiddenPostIds.remove(postId));
        final message = error is ApiException
            ? error.userMessage
            : 'Could not remove saved beat.';
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(message)));
      }
    } finally {
      _pendingUnsaveIds.remove(postId);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: BeatNowTokens.background,
      body: FutureBuilder<List<SavedPost>>(
        future: _savedPostsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done &&
              !snapshot.hasData) {
            return const _SavedLoadingState();
          }

          if (snapshot.hasError) {
            final message = snapshot.error is ApiException
                ? (snapshot.error as ApiException).userMessage
                : 'Could not load saved beats.';
            return RefreshIndicator(
              onRefresh: _refresh,
              color: BeatNowTokens.accentSoft,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  SizedBox(height: MediaQuery.sizeOf(context).height * 0.28),
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Text(message,
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.white70)),
                    ),
                  ),
                  Center(
                    child: TextButton.icon(
                      onPressed: _refresh,
                      icon: const Icon(Icons.refresh_rounded),
                      label: const Text('Try again'),
                    ),
                  ),
                ],
              ),
            );
          }

          final savedPosts = (snapshot.data ?? const <SavedPost>[])
              .where((post) => !_hiddenPostIds.contains(post.postId))
              .toList();
          if (savedPosts.isEmpty) {
            return RefreshIndicator(
              onRefresh: _refresh,
              color: BeatNowTokens.accentSoft,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  SizedBox(height: MediaQuery.sizeOf(context).height * 0.2),
                  Padding(
                    padding: const EdgeInsets.all(24),
                    child: Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: BeatNowTokens.surface1,
                        borderRadius:
                            BorderRadius.circular(BeatNowTokens.radiusMedium),
                        border: Border.all(
                            color: Colors.white.withValues(alpha: 0.06)),
                      ),
                      child: const Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.bookmark_border_rounded,
                              color: Colors.white70, size: 42),
                          SizedBox(height: 16),
                          Text(
                            'You have not saved any beats yet.',
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w700),
                            textAlign: TextAlign.center,
                          ),
                          SizedBox(height: 8),
                          Text(
                            'Save beats from the feed and they will appear here as a visual collection.',
                            style:
                                TextStyle(color: Colors.white70, height: 1.5),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: _refresh,
            color: BeatNowTokens.accentSoft,
            backgroundColor: BeatNowTokens.surface1,
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 24, 16, 12),
                  sliver: SliverToBoxAdapter(
                    child: _SavedHeader(count: savedPosts.length),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 120),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final post = savedPosts[index];
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: Material(
                            color: BeatNowTokens.surface1,
                            borderRadius: BorderRadius.circular(
                                BeatNowTokens.radiusMedium),
                            clipBehavior: Clip.antiAlias,
                            child: InkWell(
                              onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) =>
                                      SavedBeatDetailScreen(post: post),
                                ),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(10),
                                child: Row(
                                  children: [
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(
                                          BeatNowTokens.radiusSmall),
                                      child: Stack(
                                        alignment: Alignment.center,
                                        children: [
                                          CachedMediaImage(
                                            url: post.coverImageUrl,
                                            fallbackAsset:
                                                MediaDefaults.coverImage,
                                            width: 76,
                                            height: 76,
                                          ),
                                          const Icon(
                                            Icons.play_circle_fill_rounded,
                                            color: Colors.white,
                                            size: 30,
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            post.title,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: Theme.of(context)
                                                .textTheme
                                                .titleSmall,
                                          ),
                                          if (post
                                              .creatorUsername.isNotEmpty) ...[
                                            const SizedBox(height: 3),
                                            Text(
                                              '@${post.creatorUsername}',
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: Theme.of(context)
                                                  .textTheme
                                                  .bodySmall,
                                            ),
                                          ],
                                          if (post.genre.isNotEmpty ||
                                              post.bpm != null) ...[
                                            const SizedBox(height: 5),
                                            Text(
                                              [
                                                if (post.genre.isNotEmpty)
                                                  post.genre,
                                                if (post.bpm != null)
                                                  '${post.bpm} BPM',
                                              ].join(' · '),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: Theme.of(context)
                                                  .textTheme
                                                  .labelSmall,
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                    IconButton(
                                      tooltip: 'Remove saved beat',
                                      onPressed: _pendingUnsaveIds
                                              .contains(post.postId)
                                          ? null
                                          : () => _unsave(post),
                                      icon: const Icon(
                                          Icons.bookmark_remove_rounded),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                      childCount: savedPosts.length,
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _SavedLoadingState extends StatelessWidget {
  const _SavedLoadingState();

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 16),
      itemCount: 5,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, index) => Container(
        height: 96,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: BeatNowTokens.surface1,
          borderRadius: BorderRadius.circular(BeatNowTokens.radiusMedium),
        ),
        child: Row(
          children: [
            Container(
              width: 76,
              height: 76,
              decoration: BoxDecoration(
                color: BeatNowTokens.surface3,
                borderRadius: BorderRadius.circular(BeatNowTokens.radiusSmall),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: double.infinity,
                    height: 12,
                    decoration: BoxDecoration(
                      color: BeatNowTokens.surface3,
                      borderRadius:
                          BorderRadius.circular(BeatNowTokens.radiusSmall),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Container(
                    width: 110,
                    height: 10,
                    decoration: BoxDecoration(
                      color: BeatNowTokens.surface3,
                      borderRadius:
                          BorderRadius.circular(BeatNowTokens.radiusSmall),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SavedHeader extends StatelessWidget {
  const _SavedHeader({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('YOUR LIBRARY',
                  style: Theme.of(context).textTheme.labelSmall),
              const SizedBox(height: 4),
              Text('Saved', style: Theme.of(context).textTheme.headlineMedium),
            ],
          ),
        ),
        Text('$count beats', style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}

class SavedBeatDetailScreen extends StatefulWidget {
  const SavedBeatDetailScreen({super.key, required this.post});

  final SavedPost post;

  @override
  State<SavedBeatDetailScreen> createState() => _SavedBeatDetailScreenState();
}

class _SavedBeatDetailScreenState extends State<SavedBeatDetailScreen> {
  final AudioPlaybackService _audioPlayback = AudioPlaybackService.instance;
  late final StreamSubscription<AudioPlaybackStatus> _audioStatusSubscription;
  bool _isPlaying = false;
  AudioPlaybackStatus _audioStatus = AudioPlaybackStatus.idle;

  @override
  void initState() {
    super.initState();
    _audioStatus = _audioPlayback.status;
    _audioStatusSubscription = _audioPlayback.statusChanges.listen((status) {
      if (!mounted) return;
      setState(() {
        _audioStatus = status;
        _isPlaying = status == AudioPlaybackStatus.playing;
      });
    });
  }

  @override
  void dispose() {
    unawaited(_audioStatusSubscription.cancel());
    unawaited(_audioPlayback.stop());
    super.dispose();
  }

  Future<void> _togglePlay() async {
    final audioUrl = widget.post.audioUrl;
    if (audioUrl.isEmpty) {
      return;
    }

    if (_isPlaying) {
      await _audioPlayback.pause();
    } else {
      await _audioPlayback.play(audioUrl);
    }
  }

  @override
  Widget build(BuildContext context) {
    final post = widget.post;
    final chips = <String>[
      if (post.genre.isNotEmpty) post.genre,
      if (post.bpm != null) '${post.bpm} BPM',
      ...post.tags.take(2).map((tag) => '#$tag'),
    ];

    return Scaffold(
      backgroundColor: BeatNowTokens.background,
      body: Stack(
        fit: StackFit.expand,
        children: [
          CachedMediaImage(
            url: post.coverImageUrl,
            fallbackAsset: MediaDefaults.coverImage,
          ),
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withValues(alpha: 0.22),
                  Colors.black.withValues(alpha: 0.18),
                  Colors.black.withValues(alpha: 0.92),
                ],
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                  ),
                  const Spacer(),
                  if (post.creatorUsername.isNotEmpty)
                    Text(
                      '@${post.creatorUsername}',
                      style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.76),
                          fontWeight: FontWeight.w700),
                    ),
                  const SizedBox(height: 8),
                  Text(
                    post.title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 32,
                      fontWeight: FontWeight.w900,
                      height: 0.98,
                    ),
                  ),
                  if (chips.isNotEmpty) ...[
                    const SizedBox(height: 14),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: chips
                          .map((chip) => _DetailChip(label: chip))
                          .toList(),
                    ),
                  ],
                  if (post.description.isNotEmpty) ...[
                    const SizedBox(height: 14),
                    Text(
                      post.description,
                      style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.74),
                          height: 1.5),
                    ),
                  ],
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: _togglePlay,
                      icon: Icon(_isPlaying
                          ? Icons.pause_rounded
                          : Icons.play_arrow_rounded),
                      label: Text(
                        _audioStatus == AudioPlaybackStatus.buffering
                            ? 'Loading preview'
                            : _audioStatus == AudioPlaybackStatus.error
                                ? 'Preview unavailable'
                                : _isPlaying
                                    ? 'Pause preview'
                                    : 'Play preview',
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailChip extends StatelessWidget {
  const _DetailChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(BeatNowTokens.radiusPill),
        color: Colors.white.withValues(alpha: 0.08),
      ),
      child: Text(
        label,
        style: const TextStyle(
            color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700),
      ),
    );
  }
}
