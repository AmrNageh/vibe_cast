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

  // Stream state guards to prevent native crashes
  bool _isStreaming = false;
  bool _isPlayerActive = false;
  bool _isStopping = false;
  bool _isPrebuffering = true;

  // Jitter buffer queue (Pre-buffers 3 chunks / ~180ms to prevent voice cutting & underruns)
  final List<Uint8List> _bufferQueue = [];
  static const int _prebufferThreshold = 3;
  static const int _maxQueueSize = 25; // Prevents memory bloat if network lags severely

  Timer? _playbackLoopTimer;

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

  /// Start live streaming playback session. Called when remote PTT starts.
  Future<void> startLivePlayback() async {
    if (!_isInitialized) await init();
    if (!_isInitialized) return;

    // Reset stream state safely
    _isStreaming = true;
    _isStopping = false;
    _isPlayerActive = false;
    _isPrebuffering = true;
    _bufferQueue.clear();

    _animTimer?.cancel();
    _animTimer = Timer.periodic(const Duration(milliseconds: 100), (timer) {
      if (_isStreaming && _isPlayerActive) {
        final double amp = 0.2 + (math.Random().nextDouble() * 0.6);
        _playbackAmplitudeController.add(amp);
      }
    });

    debugPrint('Live playback jitter buffer initialized');
  }

  /// Feeds an incoming PCM chunk into the jitter buffer.
  void feedChunk(Uint8List chunk) {
    if (!_isStreaming || _isStopping || chunk.isEmpty) return;

    // Push into jitter queue
    if (_bufferQueue.length < _maxQueueSize) {
      _bufferQueue.add(chunk);
    } else {
      // Queue overrun drop oldest packet to maintain low latency
      _bufferQueue.removeAt(0);
      _bufferQueue.add(chunk);
    }

    // Check pre-buffering condition
    if (_isPrebuffering && _bufferQueue.length >= _prebufferThreshold) {
      _isPrebuffering = false;
      _startNativePlayer();
    }
  }

  /// Starts native player and begins periodic queue draining loop.
  Future<void> _startNativePlayer() async {
    if (!_isStreaming || _isStopping || _isPlayerActive) return;

    try {
      await _player!.startPlayerFromStream(
        codec: Codec.pcm16,
        numChannels: 1,
        sampleRate: 16000,
        interleaved: true,
        bufferSize: 4096,
      );

      _isPlayerActive = true;
      debugPrint('Native AudioTrack player started from stream');

      // Start periodic queue consumer loop to feed native hardware smoothly
      _playbackLoopTimer?.cancel();
      _playbackLoopTimer = Timer.periodic(const Duration(milliseconds: 30), (timer) {
        _drainQueue();
      });
    } catch (e) {
      debugPrint('Failed to start native stream player: $e');
      _isPlayerActive = false;
    }
  }

  /// Drains available chunks in jitter buffer to native AudioTrack.
  void _drainQueue() {
    if (!_isStreaming || _isStopping || !_isPlayerActive || _player == null) {
      return;
    }

    while (_bufferQueue.isNotEmpty && _isPlayerActive && !_isStopping) {
      final chunk = _bufferQueue.removeAt(0);
      try {
        _player!.feedUint8FromStream(chunk);
      } catch (e) {
        debugPrint('Safe caught feed error: $e');
        break;
      }
    }
  }

  /// Safely stop live streaming playback without native crash.
  Future<void> stopLivePlayback() async {
    _isStopping = true;
    _isStreaming = false;
    _isPlayerActive = false;
    _isPrebuffering = false;

    _playbackLoopTimer?.cancel();
    _playbackLoopTimer = null;

    _animTimer?.cancel();
    _playbackAmplitudeController.add(0.0);

    // Drain remaining chunks before stopping
    _bufferQueue.clear();

    try {
      if (_player != null && !_player!.isStopped) {
        await _player!.stopPlayer();
      }
    } catch (e) {
      debugPrint('Safe caught stop error: $e');
    } finally {
      _isStopping = false;
    }

    debugPrint('Live playback stream safely stopped');
  }

  Future<void> stop() async => stopLivePlayback();

  void dispose() {
    stop();
    _playbackLoopTimer?.cancel();
    _animTimer?.cancel();
    _playbackAmplitudeController.close();
    _player?.closePlayer();
    _player = null;
    _isInitialized = false;
  }
}
