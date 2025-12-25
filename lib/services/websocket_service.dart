import 'dart:async';
import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../core/constants.dart';

class WebSocketService {
  static final WebSocketService _instance = WebSocketService._internal();
  factory WebSocketService() => _instance;
  WebSocketService._internal();

  WebSocketChannel? _channel;
  bool _isConnected = false;
  bool get isConnected => _isConnected;

  String? _userId;
  String? _userToken;
  String? _accountId;

  final Set<String> _subscriptions = {}; // Track "EXCHANGE|TOKEN"
  Timer? _reconnectTimer;
  Timer? _heartbeatTimer;
  int _reconnectAttempts = 0;

  final _messageController = StreamController<dynamic>.broadcast();
  Stream<dynamic> get messageStream => _messageController.stream;

  Future<void> connect({
    required String userId,
    required String userToken,
    required String accountId,
  }) async {
    _userId = userId;
    _userToken = userToken;
    _accountId = accountId;

    if (_isConnected) return;
    _establishConnection();
  }

  void _establishConnection() {
    if (_userId == null || _userToken == null) return;

    try {
      print('Connecting to Shoonya WebSocket...');
      _channel = WebSocketChannel.connect(Uri.parse(ApiConstants.websocketUrl));

      // Send connection request
      final connectRequest = {
        't': 'c',
        'uid': _userId,
        'actid': _accountId,
        'susertoken': _userToken,
        'source': 'API',
      };

      _channel!.sink.add(jsonEncode(connectRequest));

      _channel!.stream.listen(
        (message) {
          _isConnected = true;
          _reconnectAttempts = 0;
          _startHeartbeat();
          
          final data = jsonDecode(message);
          
          // If connection is confirmed, re-subscribe
          if (data['t'] == 'ck' && data['s'] == 'OK') {
            print('WebSocket Connection Confirmed');
            _resubscribeAll();
          }
          
          _messageController.add(data);
        },
        onDone: () {
          _isConnected = false;
          _stopHeartbeat();
          _handleReconnect();
          print('WebSocket disconnected');
        },
        onError: (error) {
          _isConnected = false;
          _stopHeartbeat();
          _handleReconnect();
          print('WebSocket error: $error');
        },
      );
    } catch (e) {
      _isConnected = false;
      _handleReconnect();
      print('WebSocket connection failed: $e');
    }
  }

  void _handleReconnect() {
    _reconnectTimer?.cancel();
    if (_reconnectAttempts > 10) {
      print('Max reconnect attempts reached');
      return;
    }

    _reconnectAttempts++;
    final delay = Duration(seconds: _reconnectAttempts * 2);
    print('Reconnecting in ${delay.inSeconds}s (Attempt $_reconnectAttempts)');
    
    _reconnectTimer = Timer(delay, () => _establishConnection());
  }

  void _startHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      if (_isConnected && _channel != null) {
        // Shoonya heartbeat frame
        _channel!.sink.add(jsonEncode({'t': 'h'}));
      }
    });
  }

  void _stopHeartbeat() {
    _heartbeatTimer?.cancel();
  }

  void _resubscribeAll() {
    for (final sub in _subscriptions) {
      final parts = sub.split('|');
      if (parts.length == 2) {
        _sendSubscriptionRequest(parts[0], parts[1], 't');
      }
    }
  }

  void subscribeTouchline(String exchange, String token) {
    final key = '$exchange|$token';
    _subscriptions.add(key);
    
    if (_isConnected) {
      _sendSubscriptionRequest(exchange, token, 't');
    }
  }

  void unsubscribeTouchline(String exchange, String token) {
    final key = '$exchange|$token';
    _subscriptions.remove(key);
    
    if (_isConnected) {
      _channel?.sink.add(jsonEncode({
        't': 'u',
        'k': key,
      }));
    }
  }

  void _sendSubscriptionRequest(String exchange, String token, String type) {
    if (_channel == null) return;
    final request = {
      't': type,
      'k': '$exchange|$token',
    };
    _channel!.sink.add(jsonEncode(request));
  }

  void disconnect() {
    _reconnectTimer?.cancel();
    _stopHeartbeat();
    _channel?.sink.close();
    _isConnected = false;
    _subscriptions.clear();
  }
}
