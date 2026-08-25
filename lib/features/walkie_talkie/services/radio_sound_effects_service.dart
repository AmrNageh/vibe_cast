import 'dart:async';
import 'dart:math' as math;
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:injectable/injectable.dart';

@lazySingleton
class RadioSoundEffectsService {
  final AudioPlayer _audioPlayer = AudioPlayer();

  Uint8List? _pttStartWav;
  Uint8List? _pttStopWav;
  Uint8List? _emergencyWav;

  RadioSoundEffectsService() {
    _initSounds();
  }

  void _initSounds() {
    try {
      _pttStartWav = _generateBeepWav(frequency: 950.0, durationMs: 70, sampleRate: 22050);
      _pttStopWav = _generateSquelchWav(durationMs: 110, sampleRate: 22050);
      _emergencyWav = _generateEmergencySirenWav(durationMs: 400, sampleRate: 22050);
    } catch (e) {
      debugPrint('Error generating sound effects: $e');
    }
  }

  /// Plays crisp radio chirp when PTT button is pressed
  Future<void> playPttStartSound() async {
    try {
      if (_pttStartWav != null) {
        await _audioPlayer.stop();
        await _audioPlayer.play(BytesSource(_pttStartWav!));
      }
    } catch (e) {
      debugPrint('Error playing PTT start sound: $e');
    }
  }

  /// Plays classic radio squelch/roger beep when PTT button is released
  Future<void> playPttStopSound() async {
    try {
      if (_pttStopWav != null) {
        await _audioPlayer.stop();
        await _audioPlayer.play(BytesSource(_pttStopWav!));
      }
    } catch (e) {
      debugPrint('Error playing PTT stop sound: $e');
    }
  }

  /// Plays tactical emergency siren alert
  Future<void> playEmergencySound() async {
    try {
      if (_emergencyWav != null) {
        await _audioPlayer.stop();
        await _audioPlayer.play(BytesSource(_emergencyWav!));
      }
    } catch (e) {
      debugPrint('Error playing emergency sound: $e');
    }
  }

  /// Programmatically generates a PCM 16-bit Mono WAV file buffer for a pure tone chirp
  Uint8List _generateBeepWav({
    required double frequency,
    required int durationMs,
    required int sampleRate,
  }) {
    final int numSamples = (sampleRate * durationMs / 1000).round();
    final int dataSize = numSamples * 2;
    final int fileSize = 36 + dataSize;

    final ByteData header = ByteData(44);
    // RIFF header
    header.setUint8(0, 0x52); // R
    header.setUint8(1, 0x49); // I
    header.setUint8(2, 0x46); // F
    header.setUint8(3, 0x46); // F
    header.setUint32(4, fileSize, Endian.little);
    header.setUint8(8, 0x57); // W
    header.setUint8(9, 0x41); // A
    header.setUint8(10, 0x56); // V
    header.setUint8(11, 0x45); // E

    // fmt chunk
    header.setUint8(12, 0x66); // f
    header.setUint8(13, 0x6D); // m
    header.setUint8(14, 0x74); // t
    header.setUint8(15, 0x20); // ' '
    header.setUint32(16, 16, Endian.little); // Chunk size
    header.setUint16(20, 1, Endian.little); // Format 1 (PCM)
    header.setUint16(22, 1, Endian.little); // Mono
    header.setUint32(24, sampleRate, Endian.little);
    header.setUint32(28, sampleRate * 2, Endian.little); // Byte rate
    header.setUint16(32, 2, Endian.little); // Block align
    header.setUint16(34, 16, Endian.little); // Bits per sample

    // data chunk
    header.setUint8(36, 0x64); // d
    header.setUint8(37, 0x61); // a
    header.setUint8(38, 0x74); // t
    header.setUint8(39, 0x61); // a
    header.setUint32(40, dataSize, Endian.little);

    final ByteData pcm = ByteData(dataSize);
    for (int i = 0; i < numSamples; i++) {
      final double t = i / sampleRate;
      final double sample = math.sin(2 * math.pi * frequency * t);
      // Fast fade out to avoid pop
      final double envelope = (numSamples - i) / numSamples;
      final int value = (sample * envelope * 24000).clamp(-32768, 32767).toInt();
      pcm.setInt16(i * 2, value, Endian.little);
    }

    final Uint8List wavBytes = Uint8List(44 + dataSize);
    wavBytes.setRange(0, 44, header.buffer.asUint8List());
    wavBytes.setRange(44, 44 + dataSize, pcm.buffer.asUint8List());
    return wavBytes;
  }

  /// Programmatically generates a tactical radio squelch + roger beep WAV
  Uint8List _generateSquelchWav({
    required int durationMs,
    required int sampleRate,
  }) {
    final int numSamples = (sampleRate * durationMs / 1000).round();
    final int dataSize = numSamples * 2;
    final int fileSize = 36 + dataSize;

    final ByteData header = ByteData(44);
    header.setUint8(0, 0x52); header.setUint8(1, 0x49); header.setUint8(2, 0x46); header.setUint8(3, 0x46);
    header.setUint32(4, fileSize, Endian.little);
    header.setUint8(8, 0x57); header.setUint8(9, 0x41); header.setUint8(10, 0x56); header.setUint8(11, 0x45);

    header.setUint8(12, 0x66); header.setUint8(13, 0x6D); header.setUint8(14, 0x74); header.setUint8(15, 0x20);
    header.setUint32(16, 16, Endian.little);
    header.setUint16(20, 1, Endian.little);
    header.setUint16(22, 1, Endian.little);
    header.setUint32(24, sampleRate, Endian.little);
    header.setUint32(28, sampleRate * 2, Endian.little);
    header.setUint16(32, 2, Endian.little);
    header.setUint16(34, 16, Endian.little);

    header.setUint8(36, 0x64); header.setUint8(37, 0x61); header.setUint8(38, 0x74); header.setUint8(39, 0x61);
    header.setUint32(40, dataSize, Endian.little);

    final ByteData pcm = ByteData(dataSize);
    final math.Random random = math.Random();

    for (int i = 0; i < numSamples; i++) {
      final double t = i / sampleRate;
      double sample = 0.0;

      if (i < numSamples * 0.4) {
        // Part 1: Squelch white noise
        sample = (random.nextDouble() * 2.0 - 1.0) * 0.4;
      } else {
        // Part 2: Roger beep (1200Hz tone)
        sample = math.sin(2 * math.pi * 1200 * t) * 0.6;
      }

      final double envelope = (numSamples - i) / numSamples;
      final int value = (sample * envelope * 24000).clamp(-32768, 32767).toInt();
      pcm.setInt16(i * 2, value, Endian.little);
    }

    final Uint8List wavBytes = Uint8List(44 + dataSize);
    wavBytes.setRange(0, 44, header.buffer.asUint8List());
    wavBytes.setRange(44, 44 + dataSize, pcm.buffer.asUint8List());
    return wavBytes;
  }

  /// Programmatically generates a tactical emergency siren WAV
  Uint8List _generateEmergencySirenWav({
    required int durationMs,
    required int sampleRate,
  }) {
    final int numSamples = (sampleRate * durationMs / 1000).round();
    final int dataSize = numSamples * 2;
    final int fileSize = 36 + dataSize;

    final ByteData header = ByteData(44);
    header.setUint8(0, 0x52); header.setUint8(1, 0x49); header.setUint8(2, 0x46); header.setUint8(3, 0x46);
    header.setUint32(4, fileSize, Endian.little);
    header.setUint8(8, 0x57); header.setUint8(9, 0x41); header.setUint8(10, 0x56); header.setUint8(11, 0x45);

    header.setUint8(12, 0x66); header.setUint8(13, 0x6D); header.setUint8(14, 0x74); header.setUint8(15, 0x20);
    header.setUint32(16, 16, Endian.little);
    header.setUint16(20, 1, Endian.little);
    header.setUint16(22, 1, Endian.little);
    header.setUint32(24, sampleRate, Endian.little);
    header.setUint32(28, sampleRate * 2, Endian.little);
    header.setUint16(32, 2, Endian.little);
    header.setUint16(34, 16, Endian.little);

    header.setUint8(36, 0x64); header.setUint8(37, 0x61); header.setUint8(38, 0x74); header.setUint8(39, 0x61);
    header.setUint32(40, dataSize, Endian.little);

    final ByteData pcm = ByteData(dataSize);
    for (int i = 0; i < numSamples; i++) {
      final double t = i / sampleRate;
      // Frequency sweep 600Hz -> 1400Hz siren
      final double freq = 600.0 + 800.0 * math.sin(2 * math.pi * 3.0 * t).abs();
      final double sample = math.sin(2 * math.pi * freq * t);
      final int value = (sample * 26000).clamp(-32768, 32767).toInt();
      pcm.setInt16(i * 2, value, Endian.little);
    }

    final Uint8List wavBytes = Uint8List(44 + dataSize);
    wavBytes.setRange(0, 44, header.buffer.asUint8List());
    wavBytes.setRange(44, 44 + dataSize, pcm.buffer.asUint8List());
    return wavBytes;
  }

  void dispose() {
    _audioPlayer.dispose();
  }
}
