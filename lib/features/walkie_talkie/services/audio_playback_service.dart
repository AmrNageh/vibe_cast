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
  Completer<void>? _initCompleter;

  // Stream state guards to prevent native crashes
  bool _isStreaming = false;
  bool _isPlayerActive = false;
  bool _isStopping = false;
  bool _isPrebuffering = true;

  // Jitter buffer queue (Pre-buffers chunks before starting native player)
  final List<Uint8List> _bufferQueue = [];
  static const int _prebufferThreshold = 3;
  static const int _maxQueueSize = 25;

  final _playbackAmplitudeController =
      StreamController<double>.broadcast();
  Stream<double> get playbackAmplitudeStream =>
      _playbackAmplitudeController.stream;

  Timer? _animTimer;

  Future<void> init() async {
    if (_isInitialized) return;

    // If already initializing, wait for it to complete instead of racing
    if (_initCompleter != null) {
      await _initCompleter!.future;
      return;
    }

    _initCompleter = Completer<void>();
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

      // Don't open the player here; we will open it dynamically per stream
      _isInitialized = true;
    } catch (e) {
      debugPrint('AudioPlaybackService init error: $e');
      _isInitialized = false;
    } finally {
      _initCompleter?.complete();
      _initCompleter = null;
    }
  }

  /// Start live streaming playback session. Called when remote PTT starts.
  Future<void> startLivePlayback() async {
    if (!_isInitialized) await init();
    if (!_isInitialized) return;

    // FIX Bug #1: Force-stop native player if it's still running before restart
    if (_isPlayerActive) {
      await _forceStopNativePlayer();
    }

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

  bool _isFeeding = false;

  /// Feeds an incoming PCM chunk into the jitter buffer.
  void feedChunk(Uint8List chunk) {
    if (!_isStreaming || _isStopping || chunk.isEmpty) return;

    if (_bufferQueue.length < _maxQueueSize) {
      _bufferQueue.add(chunk);
    } else {
      _bufferQueue.removeAt(0);
      _bufferQueue.add(chunk);
    }

    if (_isPrebuffering) {
      // Check pre-buffering threshold
      if (_bufferQueue.length >= _prebufferThreshold) {
        _isPrebuffering = false;
        _startNativePlayer();
      }
    } else if (_isPlayerActive) {
      // Player is active — process queue sequentially
      _processQueue();
    }
  }

  /// Starts native player and immediately drains the pre-buffer.
  Future<void> _startNativePlayer() async {
    if (!_isStreaming || _isStopping || _isPlayerActive) return;

    try {
      if (_player == null) {
        _player = FlutterSoundPlayer();
        await _player!.openPlayer();
      }
      
      await _player!.startPlayerFromStream(
        codec: Codec.pcm16,
        numChannels: 1,
        sampleRate: 16000,
        interleaved: true,
        bufferSize: 4096,
      );

      _isPlayerActive = true;
      debugPrint('Native AudioTrack player started from stream');

      // Immediately process pre-buffered chunks
      _processQueue();
    } catch (e) {
      debugPrint('Failed to start native stream player: $e');
      _isPlayerActive = false;
    }
  }

  /// Drains all queued chunks sequentially to native player.
  Future<void> _processQueue() async {
    if (_isFeeding || !_isPlayerActive || _isStopping || _player == null) return;
    
    _isFeeding = true;
    try {
      while (_bufferQueue.isNotEmpty && _isPlayerActive && !_isStopping && _player != null) {
        final chunk = _bufferQueue.removeAt(0);
        try {
          await _player!.feedUint8FromStream(chunk);
        } catch (e) {
          debugPrint('Safe caught feed error: $e');
          // If feeding fails (e.g. stream closed), stop processing
          break;
        }
      }
    } finally {
      _isFeeding = false;
    }
  }

  /// Force-stops native player, awaiting completion.
  Future<void> _forceStopNativePlayer() async {
    try {
      if (_player != null) {
        if (!_player!.isStopped) {
          await _player!.stopPlayer();
        }
        await _player!.closePlayer();
        _player = null;
      }
    } catch (e) {
      debugPrint('Force stop player error: $e');
    }
    _isPlayerActive = false;
  }

  /// Safely stop live streaming playback without native crash.
  /// FIX Bug #5: Waits for init to complete before stopping.
  Future<void> stopLivePlayback() async {
    _isStopping = true;
    _isStreaming = false;
    _isPrebuffering = false;

    // Wait for any in-progress init to complete before stopping
    if (_initCompleter != null) {
      await _initCompleter!.future;
    }

    _animTimer?.cancel();
    _playbackAmplitudeController.add(0.0);

    // Clear remaining queued chunks
    _bufferQueue.clear();

    // Force stop native player
    await _forceStopNativePlayer();

    _isStopping = false;
    debugPrint('Live playback stream safely stopped');
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
