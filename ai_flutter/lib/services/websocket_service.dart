import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';

class WebSocketService {
  WebSocketChannel? _channel;
final String _url = 'ws://192.168.1.5:8000/ws/predict';
  final int _sequenceLength = 30;
  List<List<double>> _keypointsSequence = [];

  void connect() {
    _channel = WebSocketChannel.connect(Uri.parse(_url));
    _keypointsSequence = [];
  }

  void disconnect() {
    _channel?.sink.close();
    _channel = null;
  }

  void sendKeypoints(List<double> keypoints) {
    if (_channel == null) return;

    _keypointsSequence.add(keypoints);
    if (_keypointsSequence.length > _sequenceLength) {
      _keypointsSequence.removeAt(0);
    }

    if (_keypointsSequence.length == _sequenceLength) {
      _channel!.sink.add(jsonEncode({
        'keypoints': keypoints,
      }));
    }
  }

  Stream<Map<String, dynamic>> get predictions {
    return _channel!.stream.map((data) {
      final Map<String, dynamic> response = jsonDecode(data);
      return response;
    });
  }
} 