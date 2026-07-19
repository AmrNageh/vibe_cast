import 'dart:async';
import 'dart:typed_data';
import 'package:injectable/injectable.dart';
import 'package:audioplayers/audioplayers.dart';

@lazySingleton
class AudioPlaybackService {
  final AudioPlayer _player = AudioPlayer();
  final List<Uint8List> _buffer = [];
  bool _isPlaying = false;

  void playStream(Stream<Uint8List> stream) {
    stream.listen((data) {
      _buffer.add(data);
      _playNext();
    });
  }

  Future<void> _playNext() async {
    // Jitter buffer: wait until we have at least 3 chunks before starting playback initially
    if (_isPlaying || _buffer.length < 3 && _buffer.isNotEmpty) return;
    if (_buffer.isEmpty) return;

    _isPlaying = true;
    final data = _buffer.removeAt(0);

    await _player.play(BytesSource(data));

    _player.onPlayerComplete.listen((_) {
      _isPlaying = false;
      _playNext();
    });
  }

  void stop() {
    _player.stop();
    _buffer.clear();
    _isPlaying = false;
  }

  void dispose() {
    _player.dispose();
  }
}
