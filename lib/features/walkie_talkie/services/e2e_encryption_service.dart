import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:encrypt/encrypt.dart' as enc;
import 'package:flutter/foundation.dart';
import 'package:injectable/injectable.dart';

@lazySingleton
class E2EEncryptionService {
  final Map<String, enc.Encrypter> _encrypters = {};

  enc.Encrypter _getEncrypter(String groupId) {
    if (_encrypters.containsKey(groupId)) {
      return _encrypters[groupId]!;
    }
    
    // Derive a 32-byte AES key from the groupId + a secret salt
    final salt = utf8.encode('VibeCast_Tactical_Secret_2026');
    final groupBytes = utf8.encode(groupId);
    final digest = sha256.convert([...salt, ...groupBytes]);
    final key = enc.Key(Uint8List.fromList(digest.bytes));
    
    // Create AES CTR encrypter (stream cipher, no padding required)
    final encrypter = enc.Encrypter(enc.AES(key, mode: enc.AESMode.ctr, padding: null));
    _encrypters[groupId] = encrypter;
    return encrypter;
  }

  Uint8List encryptAudio(String groupId, Uint8List rawAudio) {
    try {
      final encrypter = _getEncrypter(groupId);
      final iv = enc.IV.fromSecureRandom(16);
      
      final encrypted = encrypter.encryptBytes(rawAudio, iv: iv);
      
      // Prepend the 16-byte IV to the ciphertext
      final outBytes = Uint8List(16 + encrypted.bytes.length);
      outBytes.setRange(0, 16, iv.bytes);
      outBytes.setRange(16, outBytes.length, encrypted.bytes);
      return outBytes;
    } catch (e) {
      debugPrint('Encryption error: $e');
      return rawAudio; // Fallback to raw if error
    }
  }

  Uint8List decryptAudio(String groupId, Uint8List encryptedData) {
    try {
      if (encryptedData.length <= 16) return encryptedData; // Too small to be encrypted
      
      final iv = enc.IV(encryptedData.sublist(0, 16));
      final ciphertext = encryptedData.sublist(16);
      
      final encrypter = _getEncrypter(groupId);
      final decrypted = encrypter.decryptBytes(enc.Encrypted(ciphertext), iv: iv);
      
      return Uint8List.fromList(decrypted);
    } catch (e) {
      debugPrint('Decryption error: $e');
      return encryptedData;
    }
  }
}
