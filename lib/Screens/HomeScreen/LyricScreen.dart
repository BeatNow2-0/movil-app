import 'package:BeatNow/services/api_client.dart';
import 'package:BeatNow/services/beatnow_service.dart';
import 'package:BeatNow/Screens/HomeScreen/LyricEditorPage.dart';
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
    _lyricsFuture = _loadLyrics();
  }

  Future<List<Map<String, dynamic>>> _loadLyrics() async {
    return <Map<String, dynamic>>[];
  }

  Future<void> _refreshLyrics() async {
    setState(() {
      _lyricsFuture = _loadLyrics();
    });
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 50),
          child: Text(
            'Your Lyrics',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
        ),
        Expanded(
          child: FutureBuilder<List<Map<String, dynamic>>>(
            future: _lyricsFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const Center(child: CircularProgressIndicator());
              }

              if (snapshot.hasError) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      'Lyrics list is not available from the documented API yet.',
                      textAlign: TextAlign.center,
                    ),
                  ),
                );
              }

              final lyrics = snapshot.data ?? const <Map<String, dynamic>>[];
              if (lyrics.isEmpty) {
                return const Center(child: Text('No lyrics created yet.'));
              }

              return ListView.builder(
                itemCount: lyrics.length,
                itemBuilder: (context, index) {
                  final lyric = lyrics[index];
                  final lines = (lyric['lyrics']?.toString() ?? '').split('\n');
                  final preview = lines.length > 1
                      ? lines.sublist(0, 2).join('\n')
                      : lines.firstOrNull ?? '';

                  return ListTile(
                    title: Text(lyric['title']?.toString() ?? 'Untitled'),
                    subtitle: Text(preview),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete),
                      onPressed: () => _deleteLyric(lyric['_id'].toString()),
                    ),
                    onTap: () async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => LyricEditorPage(
                            title: lyric['title']?.toString() ?? '',
                            lyric: lyric['lyrics']?.toString() ?? '',
                            isEditing: true,
                            lyricId: lyric['_id']?.toString() ?? '',
                          ),
                        ),
                      );
                      await _refreshLyrics();
                    },
                  );
                },
              );
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 155),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(100),
            child: SizedBox(
              width: 100,
              height: 60,
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
                backgroundColor: Colors.black,
                child: const Icon(
                  Icons.add,
                  color: Color(0xFF8731E4),
                  size: 30,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

extension on List<String> {
  String? get firstOrNull => isEmpty ? null : first;
}
