import 'dart:async';
import 'dart:typed_data';
import 'package:injectable/injectable.dart';
import 'package:record/record.dart';

@lazySingleton
class AudioCaptureService {
  final AudioRecorder _audioRecorder = AudioRecorder();
  StreamSubscription<Uint8List>? _recordSub;

  final _audioStreamController = StreamController<Uint8List>.broadcast();
  Stream<Uint8List> get audioStream => _audioStreamController.stream;

  final _amplitudeStreamController = StreamController<double>.broadcast();
  Stream<double> get amplitudeStream => _amplitudeStreamController.stream;

  Timer? _amplitudeTimer;

  bool useOpus = true;

  Future<void> start() async {
    if (await _audioRecorder.hasPermission()) {
      final stream = await _audioRecorder.startStream(RecordConfig(
        encoder: useOpus ? AudioEncoder.opus : AudioEncoder.pcm16bits,
        sampleRate: 16000,
        numChannels: 1,
      ));

      _recordSub = stream.listen((data) {
        _audioStreamController.add(data);
      });

      _amplitudeTimer = Timer.periodic(const Duration(milliseconds: 50), (timer) async {
        if (await _audioRecorder.isRecording()) {
          final amp = await _audioRecorder.getAmplitude();
          // Convert from -160..0 to 0..1 roughly
          double val = (amp.current + 60) / 60;
          if (val < 0) val = 0;
          if (val > 1) val = 1;
          _amplitudeStreamController.add(val);
        }
      });
    }
  }

  Future<void> stop() async {
    _amplitudeTimer?.cancel();
    await _recordSub?.cancel();
    await _audioRecorder.stop();
    _amplitudeStreamController.add(0.0);
  }

  void dispose() {
    stop();
    _audioStreamController.close();
    _amplitudeStreamController.close();
    _audioRecorder.dispose();
  }
}
