import 'package:BeatNow/Screens/HomeScreen/LyricEditorPage.dart';
import 'package:BeatNow/Models/Posts.dart';
import 'package:BeatNow/services/api_client.dart';
import 'package:BeatNow/services/beatnow_service.dart';
import 'package:BeatNow/theme/beatnow_theme.dart';
import 'package:flutter/material.dart';

class LyricScreen extends StatefulWidget {
  const LyricScreen({super.key});

  @override
  State<LyricScreen> createState() => _LyricScreenState();
}

class _LyricScreenState extends State<LyricScreen> {
  final BeatNowService _beatNowService = BeatNowService();
  late Future<List<Map<String, dynamic>>> _lyricsFuture;
  final Set<String> _deletingLyricIds = <String>{};
  final Map<String, Future<Posts?>> _associatedBeatFutures = {};

  @override
  void initState() {
    super.initState();
    _lyricsFuture = _beatNowService.getUserLyrics();
  }

  Future<void> _refreshLyrics() async {
    final future = _beatNowService.getUserLyrics();
    setState(() {
      _lyricsFuture = future;
    });
    try {
      await future;
    } catch (_) {
      // FutureBuilder presents the request error and retry action.
    }
  }

  Future<void> _deleteLyric(String lyricId) async {
    if (lyricId.isEmpty || _deletingLyricIds.contains(lyricId)) return;
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete lyric?'),
        content: const Text('This lyric will be permanently deleted.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (shouldDelete != true || !mounted) return;
    setState(() => _deletingLyricIds.add(lyricId));
    try {
      await _beatNowService.deleteLyric(lyricId);
      await _refreshLyrics();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error is ApiException
              ? error.userMessage
              : 'Could not delete lyric. Please try again.'),
        ),
      );
    } finally {
      if (mounted) setState(() => _deletingLyricIds.remove(lyricId));
    }
  }

  Future<Posts?> _associatedBeat(String postId) =>
      _associatedBeatFutures.putIfAbsent(postId, () async {
        try {
          return await _beatNowService.getPostById(postId);
        } catch (_) {
          return null;
        }
      });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: BeatNowTokens.background,
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _lyricsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            final message = snapshot.error is ApiException
                ? (snapshot.error as ApiException).userMessage
                : 'Could not load lyrics.';
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(message,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.white70)),
                  ),
                  TextButton.icon(
                    onPressed: _refreshLyrics,
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('Retry'),
                  ),
                ],
              ),
            );
          }

          final lyrics = snapshot.data ?? const <Map<String, dynamic>>[];
          if (lyrics.isEmpty) {
            return Padding(
              padding: const EdgeInsets.fromLTRB(20, 72, 20, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeader(),
                  const SizedBox(height: 26),
                  Expanded(
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.04),
                            borderRadius: BorderRadius.circular(
                                BeatNowTokens.radiusMedium),
                            border: Border.all(
                                color: Colors.white.withValues(alpha: 0.08)),
                          ),
                          child: const Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.edit_note_rounded,
                                  color: Colors.white70, size: 42),
                              SizedBox(height: 16),
                              Text(
                                'No lyrics created yet.',
                                style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 18,
                                    fontWeight: FontWeight.w700),
                                textAlign: TextAlign.center,
                              ),
                              SizedBox(height: 8),
                              Text(
                                'Start from a beat preview or create a blank page here.',
                                style: TextStyle(
                                    color: Colors.white70, height: 1.5),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: _refreshLyrics,
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 72, 16, 24),
              itemCount: lyrics.length + 1,
              separatorBuilder: (_, index) => index == 0
                  ? const SizedBox(height: 20)
                  : const SizedBox(height: 14),
              itemBuilder: (context, index) {
                if (index == 0) {
                  return _buildHeader();
                }

                final lyric = lyrics[index - 1];
                final lines = (lyric['lyrics']?.toString() ?? '').split('\n');
                final preview = lines.take(3).join('\n').trim();
                final postIdValue = lyric['post_id']?.toString() ?? '';
                final postId = postIdValue.isEmpty ? null : postIdValue;
                final beatTitle = lyric['associated_beat_title']?.toString() ??
                    lyric['beat_title']?.toString() ??
                    '';
                final lyricId =
                    lyric['_id']?.toString() ?? lyric['id']?.toString() ?? '';

                return Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.05),
                    borderRadius:
                        BorderRadius.circular(BeatNowTokens.radiusMedium),
                    border:
                        Border.all(color: Colors.white.withValues(alpha: 0.08)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        lyric['title']?.toString() ?? 'Untitled',
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        preview.isEmpty ? 'No lyrics content yet.' : preview,
                        style:
                            const TextStyle(color: Colors.white70, height: 1.5),
                      ),
                      if (postId != null) ...[
                        const SizedBox(height: 12),
                        _buildBeatLabel(postId, beatTitle),
                      ],
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          TextButton(
                            onPressed: () async {
                              var resolvedBeatTitle = beatTitle;
                              if (postId != null && resolvedBeatTitle.isEmpty) {
                                resolvedBeatTitle =
                                    (await _associatedBeat(postId))?.title ??
                                        '';
                              }
                              if (!context.mounted) return;
                              await Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => LyricEditorPage(
                                    title: lyric['title']?.toString() ?? '',
                                    lyric: lyric['lyrics']?.toString() ?? '',
                                    isEditing: true,
                                    lyricId: lyricId,
                                    associatedPostId: postId ?? '',
                                    associatedBeatTitle: resolvedBeatTitle,
                                  ),
                                ),
                              );
                              await _refreshLyrics();
                            },
                            child: const Text('Edit'),
                          ),
                          TextButton(
                            onPressed: lyricId.isEmpty ||
                                    _deletingLyricIds.contains(lyricId)
                                ? null
                                : () => _deleteLyric(lyricId),
                            child: _deletingLyricIds.contains(lyricId)
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2),
                                  )
                                : const Text('Delete'),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
          );
        },
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 4, right: 4),
        child: FloatingActionButton(
          onPressed: () async {
            await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const LyricEditorPage(
                  title: '',
                  lyric: '',
                  isEditing: false,
                ),
              ),
            );
            await _refreshLyrics();
          },
          backgroundColor: BeatNowTokens.surface2,
          foregroundColor: BeatNowTokens.accentSoft,
          child: const Icon(Icons.add),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Lyrics',
          style: TextStyle(
              color: Colors.white, fontSize: 30, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 8),
        Text(
          'Keep your drafts linked to beats and continue editing from one place.',
          style: TextStyle(
              color: Colors.white.withValues(alpha: 0.68), height: 1.45),
        ),
      ],
    );
  }

  Widget _buildBeatLabel(String postId, String title) {
    if (title.isNotEmpty) return _beatChip(title);
    return FutureBuilder<Posts?>(
      future: _associatedBeat(postId),
      builder: (context, snapshot) {
        final resolvedTitle = snapshot.data?.title;
        return _beatChip(resolvedTitle == null || resolvedTitle.isEmpty
            ? 'Linked beat'
            : resolvedTitle);
      },
    );
  }

  Widget _beatChip(String title) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(BeatNowTokens.radiusMedium),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.music_note_rounded,
                size: 16, color: Colors.white70),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                'Beat: $title',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Colors.white, fontSize: 12),
              ),
            ),
          ],
        ),
      );
}
