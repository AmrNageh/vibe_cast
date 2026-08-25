import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:injectable/injectable.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:audio_session/audio_session.dart';
import 'package:path_provider/path_provider.dart';

@lazySingleton
class AudioCaptureService {
  final FlutterSoundRecorder _audioRecorder = FlutterSoundRecorder();
  StreamSubscription? _progressSub;
  bool _isInitialized = false;

  final _amplitudeStreamController = StreamController<double>.broadcast();
  Stream<double> get amplitudeStream => _amplitudeStreamController.stream;

  String? _currentFilePath;

  Future<void> init() async {
    if (_isInitialized) return;
    await _audioRecorder.openRecorder();
    await _audioRecorder.setSubscriptionDuration(const Duration(milliseconds: 50));
    _isInitialized = true;
  }

  Future<void> startRecording() async {
    final status = await Permission.microphone.request();
    
    if (status.isGranted) {
      if (!_isInitialized) await init();
      if (_audioRecorder.isRecording) await stopRecording();

      try {
        final session = await AudioSession.instance;
        await session.configure(AudioSessionConfiguration(
          avAudioSessionCategory: AVAudioSessionCategory.playAndRecord,
          avAudioSessionCategoryOptions: AVAudioSessionCategoryOptions.defaultToSpeaker | AVAudioSessionCategoryOptions.mixWithOthers,
          avAudioSessionMode: AVAudioSessionMode.spokenAudio,
          avAudioSessionRouteSharingPolicy: AVAudioSessionRouteSharingPolicy.defaultPolicy,
          avAudioSessionSetActiveOptions: AVAudioSessionSetActiveOptions.none,
          androidAudioAttributes: AndroidAudioAttributes(
            contentType: AndroidAudioContentType.speech,
            flags: AndroidAudioFlags.none,
            usage: AndroidAudioUsage.voiceCommunication,
          ),
          androidAudioFocusGainType: AndroidAudioFocusGainType.gainTransientExclusive,
          androidWillPauseWhenDucked: true,
        ));

        if (Platform.isAndroid) {
          try {
            await session.setActive(true);
          } catch (_) {}
        }

        final tempDir = await getTemporaryDirectory();
        _currentFilePath = '${tempDir.path}/vibe_cast_record_${DateTime.now().millisecondsSinceEpoch}.aac';

        await _audioRecorder.startRecorder(
          toFile: _currentFilePath,
          codec: Codec.aacADTS,
        );

        if (_audioRecorder.onProgress != null) {
          _progressSub = _audioRecorder.onProgress!.listen((e) {
            double decibels = e.decibels ?? 0.0;
            double val = decibels / 120.0;
            if (val < 0) val = 0;
            if (val > 1) val = 1;
            _amplitudeStreamController.add(val);
          });
        }
      } catch (e) {
        debugPrint('Failed to start recording: $e');
      }
    }
  }

  Future<Uint8List?> stopRecording() async {
    await _progressSub?.cancel();
    _progressSub = null;
    
    if (_audioRecorder.isRecording) {
      await _audioRecorder.stopRecorder();
    }
    _amplitudeStreamController.add(0.0);

    if (_currentFilePath != null) {
      final file = File(_currentFilePath!);
      if (await file.exists()) {
        final bytes = await file.readAsBytes();
        return bytes;
      }
    }
    return null;
  }

  void dispose() {
    stopRecording();
    _amplitudeStreamController.close();
    if (_isInitialized) {
      _audioRecorder.closeRecorder();
    }
  }
}
