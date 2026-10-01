import 'dart:async';

import 'package:BeatNow/Models/Posts.dart';
import 'package:BeatNow/Models/media_defaults.dart';
import 'package:BeatNow/services/api_client.dart';
import 'package:BeatNow/services/audio_playback_service.dart';
import 'package:BeatNow/services/beatnow_service.dart';
import 'package:BeatNow/theme/beatnow_theme.dart';
import 'package:BeatNow/widgets/cached_media_image.dart';
import 'package:flutter/material.dart';

class LyricEditorPage extends StatefulWidget {
  final String title;
  final String lyric;
  final int? index;
  final String lyricId;
  final bool isEditing;
  final String associatedPostId;
  final String associatedBeatTitle;

  const LyricEditorPage({
    super.key,
    required this.title,
    required this.lyric,
    this.index,
    this.isEditing = false,
    this.lyricId = '',
    this.associatedPostId = '',
    this.associatedBeatTitle = '',
  });

  @override
  State<LyricEditorPage> createState() => _LyricEditorPageState();
}

class _LyricEditorPageState extends State<LyricEditorPage> {
  final BeatNowService _beatNowService = BeatNowService();
  final AudioPlaybackService _audioPlayback = AudioPlaybackService.instance;
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _lyricController = TextEditingController();
  late final StreamSubscription<AudioPlaybackStatus> _audioSubscription;

  late String _initialTitle;
  late String _initialLyrics;
  late String _initialPostId;
  String _associatedPostId = '';
  String _associatedBeatTitle = '';
  String _associatedAudioUrl = '';
  String? _startedAudioUrl;
  AudioPlaybackStatus _audioStatus = AudioPlaybackStatus.idle;
  bool _isSaving = false;
  bool _isLoadingBeat = false;
  bool _discardDialogOpen = false;
  bool _allowPop = false;

  bool get _hasUnsavedChanges =>
      _titleController.text != _initialTitle ||
      _lyricController.text != _initialLyrics ||
      _associatedPostId != _initialPostId;

  @override
  void initState() {
    super.initState();
    _initialTitle = widget.title;
    _initialLyrics = widget.lyric;
    _initialPostId = widget.associatedPostId;
    _titleController.text = widget.title;
    _lyricController.text = widget.lyric;
    _associatedPostId = widget.associatedPostId;
    _associatedBeatTitle = widget.associatedBeatTitle;
    _audioStatus = _audioPlayback.status;
    _audioSubscription = _audioPlayback.statusChanges.listen((status) {
      if (mounted) setState(() => _audioStatus = status);
    });
    if (_associatedPostId.isNotEmpty) _loadAssociatedBeat();
  }

  Future<void> _loadAssociatedBeat() async {
    final requestedPostId = _associatedPostId;
    setState(() => _isLoadingBeat = true);
    try {
      final post = await _beatNowService.getPostById(requestedPostId);
      if (!mounted || _associatedPostId != requestedPostId) return;
      setState(() {
        _associatedBeatTitle = post.title;
        _associatedAudioUrl = post.audioUrl;
      });
    } catch (error) {
      debugPrint('Could not load associated beat: $error');
    } finally {
      if (mounted) setState(() => _isLoadingBeat = false);
    }
  }

  Future<void> _chooseBeat() async {
    final postsFuture = _beatNowService.getRandomFeedPosts(count: 30);
    final selected = await showModalBottomSheet<Posts>(
      context: context,
      isScrollControlled: true,
      backgroundColor: BeatNowTokens.surface0,
      builder: (context) => SafeArea(
        child: SizedBox(
          height: MediaQuery.sizeOf(context).height * 0.72,
          child: FutureBuilder<List<Posts>>(
            future: postsFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                final error = snapshot.error;
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      error is ApiException
                          ? error.userMessage
                          : 'Could not load beats.',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.white70),
                    ),
                  ),
                );
              }
              final posts = snapshot.data ?? const <Posts>[];
              if (posts.isEmpty) {
                return const Center(
                  child: Text('No beats available.',
                      style: TextStyle(color: Colors.white70)),
                );
              }
              return ListView(
                children: [
                  const Padding(
                    padding: EdgeInsets.fromLTRB(20, 20, 20, 12),
                    child: Text('Choose a beat',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w700)),
                  ),
                  for (final post in posts)
                    ListTile(
                      leading: ClipRRect(
                        borderRadius:
                            BorderRadius.circular(BeatNowTokens.radiusSmall),
                        child: CachedMediaImage(
                          url: post.coverImageUrl,
                          fallbackAsset: MediaDefaults.coverImage,
                          width: 48,
                          height: 48,
                        ),
                      ),
                      title: Text(
                        post.title.isEmpty ? 'Untitled beat' : post.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Colors.white),
                      ),
                      subtitle: Text('@${post.username}',
                          style: const TextStyle(color: Colors.white60)),
                      onTap: post.id.isEmpty
                          ? null
                          : () => Navigator.pop(context, post),
                    ),
                ],
              );
            },
          ),
        ),
      ),
    );
    if (selected == null || !mounted) return;
    if (_startedAudioUrl != null) {
      _startedAudioUrl = null;
      await _audioPlayback.stop();
    }
    setState(() {
      _associatedPostId = selected.id;
      _associatedBeatTitle = selected.title;
      _associatedAudioUrl = selected.audioUrl;
    });
  }

  Future<void> _togglePlayback() async {
    if (_associatedAudioUrl.isEmpty) return;
    if (_startedAudioUrl == _associatedAudioUrl &&
        _audioStatus == AudioPlaybackStatus.playing) {
      await _audioPlayback.pause();
      return;
    }
    if (_startedAudioUrl == _associatedAudioUrl &&
        _audioStatus == AudioPlaybackStatus.paused) {
      await _audioPlayback.resume();
    } else {
      _startedAudioUrl = _associatedAudioUrl;
      await _audioPlayback.play(_associatedAudioUrl);
    }
    if (_audioPlayback.status == AudioPlaybackStatus.error && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not play this beat.')),
      );
    }
  }

  Future<void> _confirmDiscard() async {
    if (_discardDialogOpen || !mounted) return;
    _discardDialogOpen = true;
    final discard = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Discard changes?'),
        content: const Text('Your unsaved lyric changes will be lost.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Keep editing')),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Discard')),
        ],
      ),
    );
    _discardDialogOpen = false;
    if (discard == true && mounted) {
      _allowPop = true;
      Navigator.pop(context);
    }
  }

  Future<void> _save() async {
    final title = _titleController.text.trim();
    final lyrics = _lyricController.text;
    if (title.isEmpty || lyrics.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add a title and some lyrics to save.')),
      );
      return;
    }

    setState(() => _isSaving = true);
    try {
      if (widget.isEditing) {
        await _beatNowService.updateLyric(
          lyricId: widget.lyricId,
          title: title,
          lyrics: lyrics,
          postId: _associatedPostId,
        );
      } else {
        await _beatNowService.createLyric(
          title: title,
          lyrics: lyrics,
          postId: _associatedPostId,
        );
      }

      if (!mounted) return;
      _initialTitle = title;
      _initialLyrics = lyrics;
      _initialPostId = _associatedPostId;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content:
                Text(widget.isEditing ? 'Lyric updated.' : 'Lyric saved.')),
      );
      Navigator.pop(context);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error is ApiException
              ? error.userMessage
              : 'Could not save lyric. Please try again.'),
        ),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  void dispose() {
    unawaited(_audioSubscription.cancel());
    if (_startedAudioUrl != null) unawaited(_audioPlayback.stop());
    _titleController.dispose();
    _lyricController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isPlaying = _startedAudioUrl == _associatedAudioUrl &&
        _audioStatus == AudioPlaybackStatus.playing;
    return PopScope<Object?>(
      canPop: !_hasUnsavedChanges || _allowPop,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && !_allowPop) _confirmDiscard();
      },
      child: Scaffold(
        backgroundColor: BeatNowTokens.background,
        appBar: AppBar(
          backgroundColor: BeatNowTokens.background,
          title: Text(widget.isEditing ? 'Edit lyric' : 'New lyric'),
          actions: [
            if (_associatedAudioUrl.isNotEmpty)
              IconButton(
                tooltip: isPlaying ? 'Pause beat' : 'Play beat',
                icon: Icon(
                    isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded),
                onPressed: _togglePlayback,
              ),
            IconButton(
              tooltip: 'Save lyric',
              icon: _isSaving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.save_outlined),
              onPressed: _isSaving ? null : _save,
            ),
          ],
        ),
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildBeatAssociation(),
              const SizedBox(height: 16),
              TextField(
                controller: _titleController,
                onChanged: (_) => setState(() {}),
                style: const TextStyle(
                    fontSize: 22,
                    color: Colors.white,
                    fontWeight: FontWeight.bold),
                decoration: const InputDecoration(
                  hintText: 'Title',
                  border: InputBorder.none,
                  hintStyle: TextStyle(
                      fontSize: 22,
                      color: Colors.white54,
                      fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: TextField(
                  controller: _lyricController,
                  onChanged: (_) => setState(() {}),
                  decoration: const InputDecoration(
                    hintText: 'Write your lyrics...',
                    border: InputBorder.none,
                    hintStyle: TextStyle(color: Colors.white54),
                    alignLabelWithHint: true,
                  ),
                  style: const TextStyle(color: Colors.white, height: 1.6),
                  keyboardType: TextInputType.multiline,
                  textCapitalization: TextCapitalization.sentences,
                  maxLines: null,
                  expands: true,
                  textAlignVertical: TextAlignVertical.top,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBeatAssociation() {
    if (_associatedPostId.isEmpty) {
      return OutlinedButton.icon(
        onPressed: _chooseBeat,
        icon: const Icon(Icons.link_rounded),
        label: const Text('Link a beat'),
      );
    }
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(BeatNowTokens.radiusMedium),
      ),
      child: Row(
        children: [
          const Icon(Icons.music_note_rounded, color: Colors.white70),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Linked beat',
                    style: TextStyle(color: Colors.white60, fontSize: 12)),
                Text(
                  _isLoadingBeat
                      ? 'Loading beat...'
                      : _associatedBeatTitle.isEmpty
                          ? 'Beat unavailable'
                          : _associatedBeatTitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Change linked beat',
            onPressed: _chooseBeat,
            icon: const Icon(Icons.edit_outlined),
          ),
          IconButton(
            tooltip: 'Unlink beat',
            onPressed: () {
              if (_startedAudioUrl != null) {
                _startedAudioUrl = null;
                unawaited(_audioPlayback.stop());
              }
              setState(() {
                _associatedPostId = '';
                _associatedBeatTitle = '';
                _associatedAudioUrl = '';
              });
            },
            icon: const Icon(Icons.link_off_rounded),
          ),
        ],
      ),
    );
  }
}
