import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class WebSocketService extends ChangeNotifier {
  WebSocketChannel? _channel;
  bool isConnected = false;

  // Callbacks for UI/Providers to listen to
  final List<void Function(Map<String, dynamic>)> _messageCallbacks = [];

  void addMessageListener(void Function(Map<String, dynamic>) callback) {
    _messageCallbacks.add(callback);
  }

  void removeMessageListener(void Function(Map<String, dynamic>) callback) {
    _messageCallbacks.remove(callback);
  }

  // Connect to the WebSocket (NO token in URL — backend doesn't read it)
  void connect() {
    final String wsUrl = dotenv.env['EXPO_PUBLIC_WS_URL'] ?? 'ws://localhost:3000';

    try {
      _channel = WebSocketChannel.connect(Uri.parse(wsUrl));
      isConnected = true;
      notifyListeners();

      _channel!.stream.listen(
        (data) {
          try {
            final parsedData = jsonDecode(data);
            for (final callback in List.from(_messageCallbacks)) {
              callback(parsedData);
            }
          } catch (e) {
            print('Error parsing WS message: $e');
          }
        },
        onDone: () {
          isConnected = false;
          notifyListeners();
          print('WebSocket disconnected. Reconnecting in 3s...');
          Future.delayed(const Duration(seconds: 3), () => connect());
        },
        onError: (error) {
          isConnected = false;
          notifyListeners();
          print('WebSocket Error: $error');
        },
      );
    } catch (e) {
      isConnected = false;
      notifyListeners();
      print('WebSocket Connection Error: $e');
    }
  }

  // Register user with the WebSocket server (required by backend)
  void register(int userId) {
    send('register', {'user_id': userId});
  }

  // Send a generic message
  void send(String type, Map<String, dynamic> payload) {
    if (_channel != null && isConnected) {
      final message = jsonEncode({
        'type': type,
        'payload': payload,
      });
      _channel!.sink.add(message);
    } else {
      print('Cannot send message: WebSocket is not connected');
    }
  }

  // Send a public chat message (global broadcast)
  void sendChatMessage(int userId, String messageText, {String? audioUrl, int? replyToId}) {
    send('chat_message', {
      'user_id': userId,
      'message_text': messageText,
      if (audioUrl != null) 'audio_url': audioUrl,
      if (replyToId != null) 'reply_to_id': replyToId,
    });
  }

  // Disconnect
  void disconnect() {
    _channel?.sink.close();
    _channel = null;
    isConnected = false;
    notifyListeners();
  }
}
