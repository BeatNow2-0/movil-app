import 'package:BeatNow/Models/SavedPost.dart';
import 'package:BeatNow/services/api_client.dart';
import 'package:BeatNow/services/beatnow_service.dart';
import 'package:flutter/material.dart';

class SavedScreen extends StatefulWidget {
  const SavedScreen({super.key});

  @override
  State<SavedScreen> createState() => _SavedScreenState();
}

class _SavedScreenState extends State<SavedScreen> {
  final BeatNowService _beatNowService = BeatNowService();
  late Future<List<SavedPost>> _savedPostsFuture;

  @override
  void initState() {
    super.initState();
    _savedPostsFuture = _beatNowService.getSavedPosts();
  }

  Future<void> _refresh() async {
    setState(() {
      _savedPostsFuture = _beatNowService.getSavedPosts();
    });
    await _savedPostsFuture;
  }

  String _formatDate(String rawDate) {
    final date = DateTime.tryParse(rawDate);
    if (date == null) return rawDate;
    final month = <String>[
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ][date.month - 1];
    return '${date.day} $month ${date.year}';
  }

  String _coverUrl(SavedPost post) {
    return post.coverImageUrl ??
        'https://res.beatnow.app/beatnow/'
            '${post.creatorId ?? post.userId}/posts/${post.postId}/caratula.'
            '${post.coverFormat ?? 'jpg'}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF111216),
      appBar: AppBar(
        title: const Text(
          'Saved',
          style: TextStyle(fontWeight: FontWeight.w800, color: Colors.white),
        ),
        centerTitle: false,
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: const Color(0xFF111216),
      ),
      body: FutureBuilder<List<SavedPost>>(
        future: _savedPostsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            final message = snapshot.error is ApiException
                ? (snapshot.error as ApiException).message
                : 'Could not load saved beats.';
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(message, style: const TextStyle(color: Colors.white70)),
              ),
            );
          }

          final savedPosts = snapshot.data ?? const <SavedPost>[];
          if (savedPosts.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: const Color(0xFF181A20),
                    borderRadius: BorderRadius.circular(28),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
                  ),
                  child: const Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.bookmark_border_rounded, color: Colors.white70, size: 42),
                      SizedBox(height: 16),
                      Text(
                        'You have not saved any beats yet.',
                        style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700),
                        textAlign: TextAlign.center,
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Save the beats you want to revisit and they will appear here.',
                        style: TextStyle(color: Colors.white70, height: 1.5),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: _refresh,
            color: const Color(0xFF8731E4),
            backgroundColor: const Color(0xFF181A20),
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
              itemCount: savedPosts.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final post = savedPosts[index];
                return Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFF1A1C22),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Row(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(18),
                          child: Image.network(
                            _coverUrl(post),
                            width: 88,
                            height: 88,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Container(
                              width: 88,
                              height: 88,
                              color: const Color(0xFF242730),
                              child: const Icon(Icons.music_note_rounded, color: Colors.white54),
                            ),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF232733),
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: const Text(
                                  'Saved beat',
                                  style: TextStyle(
                                    color: Colors.white70,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 0.3,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                post.postId,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 16,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'Saved on ${_formatDate(post.savedDate)}',
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.64),
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: const Color(0xFF232733),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: const Icon(Icons.chevron_right_rounded, color: Colors.white70),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}
