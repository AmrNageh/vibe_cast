import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:injectable/injectable.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:audio_session/audio_session.dart';

@lazySingleton
class AudioPlaybackService {
  FlutterSoundPlayer? _player;
  bool _isInitialized = false;
  bool _isInitializing = false;
  bool _isStreaming = false;

  final _playbackAmplitudeController =
      StreamController<double>.broadcast();
  Stream<double> get playbackAmplitudeStream =>
      _playbackAmplitudeController.stream;

  Timer? _animTimer;

  Future<void> init() async {
    if (_isInitialized) return;
    if (_isInitializing) {
      while (_isInitializing && !_isInitialized) {
        await Future.delayed(const Duration(milliseconds: 50));
      }
      return;
    }

    _isInitializing = true;
    try {
      final session = await AudioSession.instance;
      await session.configure(AudioSessionConfiguration(
        avAudioSessionCategory: AVAudioSessionCategory.playback,
        avAudioSessionCategoryOptions:
            AVAudioSessionCategoryOptions.defaultToSpeaker |
                AVAudioSessionCategoryOptions.mixWithOthers,
        avAudioSessionMode: AVAudioSessionMode.defaultMode,
        avAudioSessionRouteSharingPolicy:
            AVAudioSessionRouteSharingPolicy.defaultPolicy,
        avAudioSessionSetActiveOptions:
            AVAudioSessionSetActiveOptions.none,
        androidAudioAttributes: const AndroidAudioAttributes(
          contentType: AndroidAudioContentType.speech,
          flags: AndroidAudioFlags.none,
          usage: AndroidAudioUsage.voiceCommunication,
        ),
        androidAudioFocusGainType:
            AndroidAudioFocusGainType.gainTransientMayDuck,
        androidWillPauseWhenDucked: true,
      ));

      _player = FlutterSoundPlayer();
      await _player!.openPlayer();
      _isInitialized = true;
    } catch (e) {
      debugPrint('AudioPlaybackService init error: $e');
      _isInitialized = false;
    } finally {
      _isInitializing = false;
    }
  }

  /// Start live streaming playback. Call once when remote PTT starts.
  Future<void> startLivePlayback() async {
    if (!_isInitialized) await init();
    if (!_isInitialized) return;
    if (_isStreaming) return;

    try {
      await _player!.startPlayerFromStream(
        codec: Codec.pcm16,
        numChannels: 1,
        sampleRate: 16000,
        interleaved: true,
        bufferSize: 4096,
      );

      _isStreaming = true;

      _animTimer?.cancel();
      _animTimer =
          Timer.periodic(const Duration(milliseconds: 100), (timer) {
        final double amp = 0.2 + (math.Random().nextDouble() * 0.6);
        _playbackAmplitudeController.add(amp);
      });

      debugPrint('Live playback stream started');
    } catch (e) {
      debugPrint('Failed to start live playback: $e');
      _isStreaming = false;
    }
  }

  /// Feed an incoming PCM chunk directly into the player.
  void feedChunk(Uint8List chunk) {
    if (!_isStreaming) return;
    try {
      _player!.feedUint8FromStream(chunk);
    } catch (e) {
      debugPrint('Error feeding chunk: $e');
    }
  }

  /// Stop live streaming playback. Call when remote PTT stops.
  Future<void> stopLivePlayback() async {
    _isStreaming = false;
    _animTimer?.cancel();
    _playbackAmplitudeController.add(0.0);

    try {
      if (_player != null && !_player!.isStopped) {
        await _player!.stopPlayer();
      }
    } catch (e) {
      debugPrint('Error stopping live playback: $e');
    }

    debugPrint('Live playback stream stopped');
  }

  Future<void> stop() async => stopLivePlayback();

  void dispose() {
    stop();
    _animTimer?.cancel();
    _playbackAmplitudeController.close();
    _player?.closePlayer();
    _player = null;
    _isInitialized = false;
  }
}
