import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/widgets.dart';

enum AudioPlaybackStatus { idle, buffering, playing, paused, completed, error }

class AudioPlaybackService with WidgetsBindingObserver {
  AudioPlaybackService._() {
    WidgetsBinding.instance.addObserver(this);
    _listenToActivePlayer();
  }

  static final AudioPlaybackService instance = AudioPlaybackService._();

  AudioPlayer _activePlayer = AudioPlayer();
  AudioPlayer _preloadPlayer = AudioPlayer();
  StreamSubscription<PlayerState>? _activeStateSubscription;
  final StreamController<AudioPlaybackStatus> _statusController =
      StreamController<AudioPlaybackStatus>.broadcast();
  Future<void> _commands = Future<void>.value();
  Future<void> _preparation = Future<void>.value();
  AudioPlaybackStatus _status = AudioPlaybackStatus.idle;
  String? _currentUrl;
  String? _preparedUrl;
  int _requestId = 0;
  bool _configured = false;
  bool _resumeOnForeground = false;

  Stream<AudioPlaybackStatus> get statusChanges => _statusController.stream;
  AudioPlaybackStatus get status => _status;
  bool get isPlaying => _status == AudioPlaybackStatus.playing;

  void _emit(AudioPlaybackStatus status) {
    _status = status;
    if (!_statusController.isClosed) _statusController.add(status);
  }

  void _listenToActivePlayer() {
    _activeStateSubscription = _activePlayer.onPlayerStateChanged.listen(
      (state) {
        switch (state) {
          case PlayerState.playing:
            _emit(AudioPlaybackStatus.playing);
          case PlayerState.paused:
            _emit(AudioPlaybackStatus.paused);
          case PlayerState.completed:
            _emit(AudioPlaybackStatus.completed);
          case PlayerState.stopped:
          case PlayerState.disposed:
            if (_currentUrl == null) _emit(AudioPlaybackStatus.idle);
        }
      },
      onError: (Object error) {
        debugPrint('Audio state stream error: $error');
        _emit(AudioPlaybackStatus.error);
      },
    );
  }

  Future<void> _configurePlayers() async {
    if (_configured) return;
    await Future.wait([
      _activePlayer.setReleaseMode(ReleaseMode.stop),
      _preloadPlayer.setReleaseMode(ReleaseMode.stop),
    ]);
    _configured = true;
  }

  Future<void> play(String url, {String? nextUrl}) async {
    if (url.isEmpty) {
      await stop();
      return;
    }

    final requestId = ++_requestId;
    _resumeOnForeground = false;
    _currentUrl = url;
    _emit(AudioPlaybackStatus.buffering);
    _commands = _commands.catchError((Object _) {}).then((_) async {
      try {
        if (requestId != _requestId) return;
        await _configurePlayers();

        if (_preparedUrl == url) {
          await _activePlayer.stop();
          if (requestId != _requestId) return;
          await _activeStateSubscription?.cancel();
          final oldActive = _activePlayer;
          _activePlayer = _preloadPlayer;
          _preloadPlayer = oldActive;
          _preparedUrl = null;
          _listenToActivePlayer();
          await _activePlayer.resume();
        } else {
          await _activePlayer.stop();
          if (requestId != _requestId) return;
          await _activePlayer.setSource(UrlSource(url));
          if (requestId != _requestId) return;
          await _activePlayer.resume();
        }

        if (requestId == _requestId && nextUrl != null && nextUrl.isNotEmpty) {
          _prepareNext(nextUrl, requestId);
        }
      } catch (error) {
        if (requestId == _requestId) {
          debugPrint('Audio playback error: $error');
          _emit(AudioPlaybackStatus.error);
        }
      }
    });
    await _commands;
  }

  void _prepareNext(String url, int requestId) {
    if (url == _currentUrl || url == _preparedUrl) return;
    _preparation = _preparation.catchError((Object _) {}).then((_) async {
      if (requestId != _requestId) return;
      try {
        await _preloadPlayer.stop();
        await _preloadPlayer.setSource(UrlSource(url));
        if (requestId == _requestId) _preparedUrl = url;
      } catch (error) {
        debugPrint('Audio preload error: $error');
      }
    });
  }

  Future<void> pause({bool preserveForForeground = false}) async {
    final requestId = ++_requestId;
    _resumeOnForeground =
        preserveForForeground && (isPlaying || _resumeOnForeground);
    _commands = _commands.catchError((Object _) {}).then((_) async {
      if (requestId != _requestId) return;
      try {
        await _activePlayer.pause();
        _emit(AudioPlaybackStatus.paused);
      } catch (error) {
        debugPrint('Audio pause error: $error');
        _emit(AudioPlaybackStatus.error);
      }
    });
    await _commands;
  }

  Future<void> resume() async {
    final requestId = ++_requestId;
    _resumeOnForeground = false;
    _commands = _commands.catchError((Object _) {}).then((_) async {
      if (requestId != _requestId || _currentUrl == null) return;
      _emit(AudioPlaybackStatus.buffering);
      try {
        await _activePlayer.resume();
        _emit(AudioPlaybackStatus.playing);
      } catch (error) {
        debugPrint('Audio resume error: $error');
        _emit(AudioPlaybackStatus.error);
      }
    });
    await _commands;
  }

  Future<void> stop() async {
    final requestId = ++_requestId;
    _resumeOnForeground = false;
    _currentUrl = null;
    _emit(AudioPlaybackStatus.idle);
    _commands = _commands.catchError((Object _) {}).then((_) async {
      if (requestId != _requestId) return;
      try {
        await _activePlayer.stop();
      } catch (error) {
        debugPrint('Audio stop error: $error');
      }
    });
    await _commands;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      unawaited(pause(preserveForForeground: true));
    } else if (state == AppLifecycleState.resumed && _resumeOnForeground) {
      unawaited(resume());
    }
  }
}
