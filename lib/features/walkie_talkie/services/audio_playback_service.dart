import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:injectable/injectable.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:audio_session/audio_session.dart';
import 'package:path_provider/path_provider.dart';

@lazySingleton
class AudioPlaybackService {
  FlutterSoundPlayer? _player;
  bool _isInitialized = false;
  bool _isInitializing = false;

  final List<String> _playQueue = [];
  bool _isPlayingQueue = false;

  final _playbackAmplitudeController = StreamController<double>.broadcast();
  Stream<double> get playbackAmplitudeStream => _playbackAmplitudeController.stream;
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
        avAudioSessionCategoryOptions: AVAudioSessionCategoryOptions.defaultToSpeaker | AVAudioSessionCategoryOptions.mixWithOthers,
        avAudioSessionMode: AVAudioSessionMode.defaultMode,
        avAudioSessionRouteSharingPolicy: AVAudioSessionRouteSharingPolicy.defaultPolicy,
        avAudioSessionSetActiveOptions: AVAudioSessionSetActiveOptions.none,
        androidAudioAttributes: AndroidAudioAttributes(
                  contentType: AndroidAudioContentType.speech,
                  flags: AndroidAudioFlags.none,
                  usage: AndroidAudioUsage.voiceCommunication,
                ),
        androidAudioFocusGainType: AndroidAudioFocusGainType.gainTransientMayDuck,
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

  // Receives a complete audio file in Uint8List format
  Future<void> playAudioBlob(Uint8List audioData) async {
    if (!_isInitialized) await init();
    if (!_isInitialized) return;

    try {
      final tempDir = await getTemporaryDirectory();
      final tempFile = File('${tempDir.path}/vibe_cast_play_${DateTime.now().millisecondsSinceEpoch}.aac');
      await tempFile.writeAsBytes(audioData);
      
      _playQueue.add(tempFile.path);
      _processQueue();
    } catch (e) {
      debugPrint('Failed to save audio blob for playback: $e');
    }
  }

  Future<void> _processQueue() async {
    if (_isPlayingQueue || _playQueue.isEmpty) return;
    _isPlayingQueue = true;

    try {
      final session = await AudioSession.instance;
      if (Platform.isAndroid) {
        try {
          await session.setActive(true);
        } catch (_) {}
      }

      while (_playQueue.isNotEmpty) {
        final filePath = _playQueue.removeAt(0);
        
        final completer = Completer<void>();
        _animTimer?.cancel();
        _animTimer = Timer.periodic(const Duration(milliseconds: 100), (timer) {
           final double amp = 0.2 + (math.Random().nextDouble() * 0.6);
           _playbackAmplitudeController.add(amp);
        });

        await _player!.startPlayer(
          fromURI: filePath,
          codec: Codec.aacADTS,
          whenFinished: () {
            _animTimer?.cancel();
            _playbackAmplitudeController.add(0.0);
            if (!completer.isCompleted) completer.complete();
          },
        );
        
        await completer.future;

        // Clean up temp file
        final file = File(filePath);
        if (await file.exists()) {
          await file.delete();
        }
      }
    } catch (e) {
      debugPrint('Error playing audio queue: $e');
    } finally {
      _isPlayingQueue = false;
      // Re-trigger in case new items arrived while finishing
      if (_playQueue.isNotEmpty) {
        _processQueue();
      }
    }
  }

  Future<void> stop() async {
    _playQueue.clear();
    _animTimer?.cancel();
    _playbackAmplitudeController.add(0.0);
    if (_player != null && !_player!.isStopped) {
      try {
        await _player!.stopPlayer();
      } catch (e) {
        debugPrint('Error stopping player: $e');
      }
    }
    _isPlayingQueue = false;
  }

  void dispose() {
    stop();
    _animTimer?.cancel();
    _playbackAmplitudeController.close();
    _player?.closePlayer();
    _player = null;
    _isInitialized = false;
  }
}
