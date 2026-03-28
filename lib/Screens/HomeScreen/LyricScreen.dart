import 'package:BeatNow/Screens/HomeScreen/LyricEditorPage.dart';
import 'package:BeatNow/services/api_client.dart';
import 'package:BeatNow/services/beatnow_service.dart';
import 'package:flutter/material.dart';

class LyricScreen extends StatefulWidget {
  const LyricScreen({super.key});

  @override
  State<LyricScreen> createState() => _LyricScreenState();
}

class _LyricScreenState extends State<LyricScreen> {
  final BeatNowService _beatNowService = BeatNowService();
  late Future<List<Map<String, dynamic>>> _lyricsFuture;

  @override
  void initState() {
    super.initState();
    _lyricsFuture = _beatNowService.getUserLyrics();
  }

  Future<void> _refreshLyrics() async {
    setState(() {
      _lyricsFuture = _beatNowService.getUserLyrics();
    });
    await _lyricsFuture;
  }

  Future<void> _deleteLyric(String lyricId) async {
    try {
      await _beatNowService.deleteLyric(lyricId);
      await _refreshLyrics();
    } on ApiException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.message)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF050505),
      appBar: AppBar(
        title: const Text(
          'Your Lyrics',
          style: TextStyle(fontWeight: FontWeight.w700, color: Colors.white),
        ),
        centerTitle: true,
        backgroundColor: const Color(0xFF050505),
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _lyricsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            final message = snapshot.error is ApiException
                ? (snapshot.error as ApiException).message
                : 'Could not load lyrics.';
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(message, style: const TextStyle(color: Colors.white70)),
              ),
            );
          }

          final lyrics = snapshot.data ?? const <Map<String, dynamic>>[];
          if (lyrics.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'No lyrics created yet. Start one from a beat or create a blank page here.',
                  style: TextStyle(color: Colors.white70),
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: _refreshLyrics,
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
              itemCount: lyrics.length,
              separatorBuilder: (_, __) => const SizedBox(height: 14),
              itemBuilder: (context, index) {
                final lyric = lyrics[index];
                final lines = (lyric['lyrics']?.toString() ?? '').split('\n');
                final preview = lines.take(2).join('\n');
                final postId = lyric['post_id']?.toString();

                return Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        lyric['title']?.toString() ?? 'Untitled',
                        style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        preview,
                        style: const TextStyle(color: Colors.white70, height: 1.5),
                      ),
                      if (postId != null && postId.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.05),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            'Associated to beat: $postId',
                            style: const TextStyle(color: Colors.white, fontSize: 12),
                          ),
                        ),
                      ],
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          TextButton(
                            onPressed: () async {
                              await Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => LyricEditorPage(
                                    title: lyric['title']?.toString() ?? '',
                                    lyric: lyric['lyrics']?.toString() ?? '',
                                    isEditing: true,
                                    lyricId: lyric['_id']?.toString() ?? '',
                                    associatedPostId: postId ?? '',
                                  ),
                                ),
                              );
                              await _refreshLyrics();
                            },
                            child: const Text('Edit'),
                          ),
                          TextButton(
                            onPressed: () => _deleteLyric(lyric['_id'].toString()),
                            child: const Text('Delete'),
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
        padding: const EdgeInsets.only(bottom: 92, right: 4),
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
          backgroundColor: const Color(0xFF111111),
          child: const Icon(Icons.add, color: Color(0xFF8731E4)),
        ),
      ),
    );
  }
}
