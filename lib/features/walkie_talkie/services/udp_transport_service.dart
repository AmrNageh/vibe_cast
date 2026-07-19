import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:injectable/injectable.dart';

@lazySingleton
class UdpTransportService {
  RawDatagramSocket? _socket;
  final _audioStreamController = StreamController<Uint8List>.broadcast();
  Stream<Uint8List> get audioStream => _audioStreamController.stream;

  int? get localPort => _socket?.port;

  Future<void> initialize() async {
    _socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
    _socket?.listen((RawSocketEvent event) {
      if (event == RawSocketEvent.read) {
        final datagram = _socket?.receive();
        if (datagram != null) {
          _audioStreamController.add(datagram.data);
        }
      }
    });
  }

  void startTransmitting(Uint8List data, String targetIp, int targetPort) {
    if (_socket != null) {
      final address = InternetAddress(targetIp);
      _socket?.send(data, address, targetPort);
    }
  }

  void dispose() {
    _socket?.close();
    _socket = null;
    _audioStreamController.close();
  }
}
