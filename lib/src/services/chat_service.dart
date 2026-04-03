import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

/// 聊天消息模型
class ChatMessage {
  final String messageId;
  final String senderId;
  final String senderName;
  final String content;
  final DateTime timestamp;
  final String messageType;
  final String deliveryStatus; // 'sent' | 'pending'

  ChatMessage({
    required this.messageId,
    required this.senderId,
    required this.senderName,
    required this.content,
    required this.timestamp,
    this.messageType = 'text',
    this.deliveryStatus = 'sent',
  });

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      messageId: json['message_id'] as String? ?? 'msg_0',
      senderId: json['sender_id'] as String? ?? '',
      senderName: json['sender_name'] as String? ?? '匿名用户',
      content: json['content'] as String? ?? '',
      timestamp: DateTime.parse(
        json['timestamp'] as String? ?? DateTime.now().toIso8601String(),
      ),
      messageType: json['message_type'] as String? ?? 'text',
      deliveryStatus: json['delivery_status'] as String? ?? 'sent',
    );
  }

  Map<String, dynamic> toJson() => {
    'message_id': messageId,
    'sender_id': senderId,
    'sender_name': senderName,
    'content': content,
    'timestamp': timestamp.toIso8601String(),
    'message_type': messageType,
    'delivery_status': deliveryStatus,
  };

  ChatMessage copyWith({
    String? messageId,
    String? senderId,
    String? senderName,
    String? content,
    DateTime? timestamp,
    String? messageType,
    String? deliveryStatus,
  }) {
    return ChatMessage(
      messageId: messageId ?? this.messageId,
      senderId: senderId ?? this.senderId,
      senderName: senderName ?? this.senderName,
      content: content ?? this.content,
      timestamp: timestamp ?? this.timestamp,
      messageType: messageType ?? this.messageType,
      deliveryStatus: deliveryStatus ?? this.deliveryStatus,
    );
  }

  bool get isSystemMessage => messageType == 'system';

  @override
  String toString() => '$senderName: $content';
}

/// WebSocket 聊天服务
class ChatService {
  WebSocketChannel? _channel;
  late StreamController<ChatMessage> _messageController;
  late StreamController<bool> _connectionController;
  Timer? _reconnectTimer;
  Timer? _heartbeatTimer;
  String? _roomId;
  String? _token;
  String? _wsBase;
  String? _httpBase;
  bool _disposed = false;
  bool _manualDisconnect = false;
  bool _isFlushingQueue = false;
  final List<ChatMessage> _pendingMessages = <ChatMessage>[];

  static const String _pendingQueuePrefix = 'chat_pending_queue_';

  /// 消息流
  Stream<ChatMessage> get messageStream => _messageController.stream;

  /// 连接状态流
  Stream<bool> get connectionStream => _connectionController.stream;

  /// 是否已连接
  bool get isConnected => _channel != null && !_disposed;

  /// 当前房间 ID
  String? get roomId => _roomId;

  ChatService() {
    _messageController = StreamController<ChatMessage>.broadcast();
    _connectionController = StreamController<bool>.broadcast();
  }

  /// 连接到聊天室
  Future<void> connect({
    required String roomId,
    required String token,
    String apiBase = 'ws://127.0.0.1:8080',
  }) async {
    if (_disposed) {
      _messageController = StreamController<ChatMessage>.broadcast();
      _connectionController = StreamController<bool>.broadcast();
      _disposed = false;
    }

    _roomId = roomId;
    _token = token;
    _manualDisconnect = false;

    // 根据 ws:// 或 wss:// 推断 http:// 或 https://
    if (apiBase.startsWith('wss://')) {
      _wsBase = apiBase;
      _httpBase = apiBase.replaceFirst('wss://', 'https://');
    } else if (apiBase.startsWith('ws://')) {
      _wsBase = apiBase;
      _httpBase = apiBase.replaceFirst('ws://', 'http://');
    } else {
      _wsBase = 'ws://$apiBase';
      _httpBase = 'http://$apiBase';
    }

    await _loadPendingMessages();
    if (!_messageController.isClosed && _pendingMessages.isNotEmpty) {
      for (final message in _pendingMessages) {
        _messageController.add(message);
      }
    }
    await _doConnect();
  }

  Future<void> _doConnect() async {
    if (_disposed || _manualDisconnect) return;

    try {
      final uri = Uri.parse('$_wsBase/rooms/$_roomId/chat?token=$_token');
      _channel = WebSocketChannel.connect(uri);

      // 监听消息
      _channel!.stream.listen(
        (message) {
          if (_disposed) return;
          try {
            final json = jsonDecode(message as String) as Map<String, dynamic>;
            final chatMsg = ChatMessage.fromJson(json);
            if (!_messageController.isClosed) {
              _messageController.add(chatMsg);
            }
          } catch (e) {
            print('聊天消息解析失败: $e');
          }
        },
        onError: (error) {
          print('WebSocket 错误: $error');
          if (!_connectionController.isClosed) {
            _connectionController.add(false);
          }
          _channel = null;
          _scheduleReconnect();
        },
        onDone: () {
          print('WebSocket 连接已关闭');
          if (!_connectionController.isClosed) {
            _connectionController.add(false);
          }
          _channel = null;
          if (!_manualDisconnect) {
            _scheduleReconnect();
          }
        },
      );

      if (!_connectionController.isClosed) {
        _connectionController.add(true);
      }
      _startHeartbeat();
      print('聊天室已连接: $_roomId');
      unawaited(_flushPendingMessages());
    } catch (e) {
      print('连接聊天室失败: $e');
      if (!_connectionController.isClosed) {
        _connectionController.add(false);
      }
      _scheduleReconnect();
    }
  }

  /// 发送消息
  Future<void> sendMessage(
    String content, {
    required String senderId,
    required String senderName,
  }) async {
    if (_disposed) {
      throw Exception('ChatService 已释放');
    }

    final messageId = 'msg_${DateTime.now().millisecondsSinceEpoch}';
    final message = ChatMessage(
      messageId: messageId,
      senderId: senderId,
      senderName: senderName,
      content: content,
      timestamp: DateTime.now(),
      deliveryStatus: 'sent',
    );
    final pendingMessage = message.copyWith(deliveryStatus: 'pending');

    if (_channel != null) {
      try {
        _channel!.sink.add(jsonEncode(message.toJson()));
        if (!_messageController.isClosed) {
          _messageController.add(message);
        }
      } catch (e) {
        print('发送消息失败: $e');
        unawaited(_enqueuePendingMessage(pendingMessage));
        if (!_messageController.isClosed) {
          _messageController.add(pendingMessage);
        }
      }
    } else {
      unawaited(_enqueuePendingMessage(pendingMessage));
      if (!_messageController.isClosed) {
        _messageController.add(pendingMessage);
      }
    }
  }

  /// 加载历史消息
  Future<List<ChatMessage>> loadHistory({int limit = 50}) async {
    if (_roomId == null || _httpBase == null) {
      return [];
    }

    try {
      final uri = Uri.parse('$_httpBase/rooms/$_roomId/messages?limit=$limit');
      final response = await http
          .get(uri, headers: {'Authorization': 'Bearer $_token'})
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        final List<dynamic> jsonList;
        if (decoded is List<dynamic>) {
          jsonList = decoded;
        } else if (decoded is Map<String, dynamic> && decoded['data'] is List) {
          jsonList = decoded['data'] as List<dynamic>;
        } else {
          return [];
        }
        return jsonList
            .map((json) => ChatMessage.fromJson(json as Map<String, dynamic>))
            .toList();
      }
    } catch (e) {
      print('加载历史消息失败: $e');
    }
    return [];
  }

  Future<void> _loadPendingMessages() async {
    _pendingMessages.clear();
    final roomId = _roomId;
    if (roomId == null || roomId.isEmpty) {
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_pendingQueueKey(roomId));
    if (raw == null || raw.trim().isEmpty) {
      return;
    }

    try {
      final decoded = jsonDecode(raw);
      if (decoded is List) {
        for (final item in decoded) {
          if (item is Map<String, dynamic>) {
            _pendingMessages.add(ChatMessage.fromJson(item));
          }
        }
      }
    } catch (e) {
      print('加载待发送消息失败: $e');
    }
  }

  Future<void> _enqueuePendingMessage(ChatMessage message) async {
    _pendingMessages.add(message);
    await _savePendingMessages();
  }

  Future<void> _flushPendingMessages() async {
    if (_isFlushingQueue || _disposed || _manualDisconnect) {
      return;
    }
    if (_channel == null || _pendingMessages.isEmpty) {
      return;
    }

    _isFlushingQueue = true;
    try {
      final pending = List<ChatMessage>.from(_pendingMessages);
      for (final message in pending) {
        try {
          final sentMessage = message.copyWith(deliveryStatus: 'sent');
          _channel!.sink.add(jsonEncode(sentMessage.toJson()));
          if (!_messageController.isClosed) {
            _messageController.add(sentMessage);
          }
          _pendingMessages.removeWhere(
            (item) => item.messageId == message.messageId,
          );
        } catch (e) {
          print('补发消息失败: $e');
          break;
        }
      }
      await _savePendingMessages();
    } finally {
      _isFlushingQueue = false;
    }
  }

  String _pendingQueueKey(String roomId) => '$_pendingQueuePrefix$roomId';

  Future<void> _savePendingMessages() async {
    final roomId = _roomId;
    if (roomId == null || roomId.isEmpty) {
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    if (_pendingMessages.isEmpty) {
      await prefs.remove(_pendingQueueKey(roomId));
      return;
    }

    final payload = _pendingMessages
        .map((message) => message.toJson())
        .toList();
    await prefs.setString(_pendingQueueKey(roomId), jsonEncode(payload));
  }

  /// 心跳保持连接
  void _startHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (_channel != null && !_disposed) {
        try {
          // 发送 ping 消息保持连接
          _channel!.sink.add(jsonEncode({'type': 'ping'}));
        } catch (_) {}
      }
    });
  }

  /// 断线重连
  void _scheduleReconnect() {
    if (_disposed || _manualDisconnect) return;

    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(const Duration(seconds: 3), () async {
      if (_roomId != null &&
          _token != null &&
          _wsBase != null &&
          !_disposed &&
          !_manualDisconnect) {
        print('尝试重新连接聊天室...');
        await _doConnect();
      }
    });
  }

  /// 关闭连接
  Future<void> close() async {
    _manualDisconnect = true;
    _reconnectTimer?.cancel();
    _heartbeatTimer?.cancel();
    await _savePendingMessages();
    await _channel?.sink.close();
    _channel = null;
    if (!_messageController.isClosed) {
      _messageController.close();
    }
    if (!_connectionController.isClosed) {
      _connectionController.close();
    }
    _disposed = true;
  }

  /// 清理资源
  void dispose() {
    _disposed = true;
    _manualDisconnect = true;
    _reconnectTimer?.cancel();
    _heartbeatTimer?.cancel();
    unawaited(_savePendingMessages());
    if (_channel != null) {
      _channel!.sink.close();
      _channel = null;
    }
    if (!_messageController.isClosed) {
      _messageController.close();
    }
    if (!_connectionController.isClosed) {
      _connectionController.close();
    }
  }
}
