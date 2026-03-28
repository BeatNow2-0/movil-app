import 'package:BeatNow/services/api_client.dart';
import 'package:BeatNow/services/beatnow_service.dart';
import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

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
  final stt.SpeechToText _speech = stt.SpeechToText();

  late TextEditingController _titleController;
  late TextEditingController _lyricController;
  bool _isListening = false;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.title);
    _lyricController = TextEditingController(text: widget.lyric);
    _speech.initialize();
  }

  Future<void> _toggleListening() async {
    if (_isListening) {
      await _speech.stop();
      setState(() => _isListening = false);
      return;
    }

    final available = await _speech.initialize();
    if (!available) {
      return;
    }

    await _speech.listen(
      onResult: (result) {
        setState(() {
          _lyricController.text = result.recognizedWords;
        });
      },
    );

    setState(() => _isListening = true);
  }

  Future<void> _save() async {
    final title = _titleController.text.trim();
    final lyrics = _lyricController.text.trim();

    if (title.isEmpty || lyrics.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Title and lyrics are required.')),
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
          postId: widget.associatedPostId.isEmpty ? null : widget.associatedPostId,
        );
      } else {
        await _beatNowService.createLyric(
          title: title,
          lyrics: lyrics,
          postId: widget.associatedPostId.isEmpty ? null : widget.associatedPostId,
        );
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(widget.isEditing ? 'Lyric updated.' : 'Lyric saved.')),
      );
      Navigator.pop(context);
    } on ApiException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.message)),
      );
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF050505),
      appBar: AppBar(
        backgroundColor: const Color(0xFF050505),
        title: const Text('Lyric Editor'),
        actions: [
          IconButton(
            icon: _isSaving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.save),
            onPressed: _isSaving ? null : _save,
          ),
          IconButton(
            icon: Icon(_isListening ? Icons.mic_off : Icons.mic),
            onPressed: _toggleListening,
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (widget.associatedPostId.isNotEmpty) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Text(
                  widget.associatedBeatTitle.isNotEmpty
                      ? 'Associated beat: ${widget.associatedBeatTitle}'
                      : 'Associated beat: ${widget.associatedPostId}',
                  style: const TextStyle(color: Colors.white),
                ),
              ),
              const SizedBox(height: 16),
            ],
            TextFormField(
              controller: _titleController,
              style: const TextStyle(fontSize: 22, color: Colors.white, fontWeight: FontWeight.bold),
              decoration: const InputDecoration(
                hintText: 'Title',
                border: InputBorder.none,
                hintStyle: TextStyle(fontSize: 22, color: Colors.white54, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 14),
            Expanded(
              child: TextFormField(
                controller: _lyricController,
                decoration: const InputDecoration(
                  hintText: 'Type or speak your lyrics here...',
                  border: InputBorder.none,
                  hintStyle: TextStyle(color: Colors.white54),
                ),
                style: const TextStyle(color: Colors.white, height: 1.6),
                keyboardType: TextInputType.multiline,
                maxLines: null,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
