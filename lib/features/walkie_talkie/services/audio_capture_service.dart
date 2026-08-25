import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:injectable/injectable.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:audio_session/audio_session.dart';

@lazySingleton
class AudioCaptureService {
  final FlutterSoundRecorder _audioRecorder = FlutterSoundRecorder();
  StreamSubscription? _progressSub;
  bool _isInitialized = false;

  final _amplitudeStreamController = StreamController<double>.broadcast();
  Stream<double> get amplitudeStream => _amplitudeStreamController.stream;

  // Chunk stream — emits raw PCM chunks as they are recorded
  final StreamController<Uint8List> _chunkController =
      StreamController<Uint8List>.broadcast();
  Stream<Uint8List> get chunkStream => _chunkController.stream;

  // flutter_sound now accepts StreamSink<Uint8List> directly (Food is deprecated)
  StreamController<Uint8List>? _recordStreamController;

  Future<void> init() async {
    if (_isInitialized) return;
    await _audioRecorder.openRecorder();
    await _audioRecorder.setSubscriptionDuration(
        const Duration(milliseconds: 60));
    _isInitialized = true;
  }

  Future<void> startRecording() async {
    final status = await Permission.microphone.request();
    if (!status.isGranted) return;

    if (!_isInitialized) await init();
    if (_audioRecorder.isRecording) await stopRecording();

    try {
      final session = await AudioSession.instance;
      await session.configure(AudioSessionConfiguration(
        avAudioSessionCategory: AVAudioSessionCategory.playAndRecord,
        avAudioSessionCategoryOptions:
            AVAudioSessionCategoryOptions.defaultToSpeaker |
                AVAudioSessionCategoryOptions.mixWithOthers,
        avAudioSessionMode: AVAudioSessionMode.spokenAudio,
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
            AndroidAudioFocusGainType.gainTransientExclusive,
        androidWillPauseWhenDucked: true,
      ));

      try {
        await session.setActive(true);
      } catch (_) {}

      // flutter_sound writes raw Uint8List chunks into this sink directly
      _recordStreamController?.close();
      _recordStreamController = StreamController<Uint8List>();

      // Forward every chunk to our broadcast chunk stream
      _recordStreamController!.stream.listen((chunk) {
        if (chunk.isNotEmpty) _chunkController.add(chunk);
      });

      await _audioRecorder.startRecorder(
        toStream: _recordStreamController!.sink,
        codec: Codec.pcm16,
        numChannels: 1,
        sampleRate: 16000, // 16kHz mono — good quality, low bandwidth
      );

      // Amplitude monitoring
      if (_audioRecorder.onProgress != null) {
        _progressSub = _audioRecorder.onProgress!.listen((e) {
          double decibels = e.decibels ?? 0.0;
          double val = (decibels / 120.0).clamp(0.0, 1.0);
          _amplitudeStreamController.add(val);
        });
      }
    } catch (e) {
      debugPrint('Failed to start live recording: $e');
    }
  }

  Future<void> stopRecording() async {
    await _progressSub?.cancel();
    _progressSub = null;

    if (_audioRecorder.isRecording) {
      await _audioRecorder.stopRecorder();
    }

    _recordStreamController?.close();
    _recordStreamController = null;

    _amplitudeStreamController.add(0.0);
  }

  void dispose() {
    stopRecording();
    _amplitudeStreamController.close();
    _chunkController.close();
    if (_isInitialized) {
      _audioRecorder.closeRecorder();
    }
  }
}
