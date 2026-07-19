import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:injectable/injectable.dart';
import 'package:flutter_sound/flutter_sound.dart';

@lazySingleton
class AudioPlaybackService {
  FlutterSoundPlayer? _player;
  StreamSubscription? _subscription;
  bool _isInitialized = false;

  Future<void> init() async {
    if (_isInitialized) return;
    _player = FlutterSoundPlayer();
    await _player!.openPlayer();
    _isInitialized = true;
  }

  Future<void> playStream(Stream<Uint8List> stream) async {
    if (!_isInitialized) await init();
    
    // Stop any existing playback and cancel old subscription
    await stop();

    // Start player from stream waiting for PCM16 frames
    await _player!.startPlayerFromStream(
      codec: Codec.pcm16,
      numChannels: 1,
      sampleRate: 16000,
      bufferSize: 8192,
      interleaved: false,
    );

    // Listen and feed the player
    _subscription = stream.listen((data) {
      if (_player!.isOpen() && !_player!.isStopped) {
        // flutter_sound uses foodSink in some versions, but in latest it's feedFromStream
        try {
          _player!.feedUint8FromStream(data);
        } catch (_) {}
      }
    }, onError: (e) {
      debugPrint('Playback stream error: $e');
      stop();
    }, onDone: () {
      stop();
    });
  }

  Future<void> stop() async {
    await _subscription?.cancel();
    _subscription = null;
    if (_player != null && !_player!.isStopped) {
      await _player!.stopPlayer();
    }
  }

  void dispose() {
    stop();
    _player?.closePlayer();
    _player = null;
    _isInitialized = false;
  }
}
