/// 后端 WebSocket 聊天服务实现参考
///
/// 本文件展示如何在 Dart 后端中实现 WebSocket 聊天服务
/// 支持 Shelf 或 Dart Frog 等框架
///
/// 集成步骤：
/// 1. 在 pubspec.yaml 中添加依赖
/// 2. 在主路由中添加 WebSocket 处理
/// 3. 实现消息广播和持久化

import 'dart:async';
import 'dart:convert';
// import 'package:shelf_web_socket/shelf_web_socket.dart';
// import 'package:shelf/shelf.dart' as shelf;
// import 'web_socket_channel/web_socket_channel.dart';

/// 聊天消息模型（与前端保持一致）
class ChatMessage {
  final String messageId;
  final String senderId;
  final String senderName;
  final String content;
  final DateTime timestamp;

  ChatMessage({
    required this.messageId,
    required this.senderId,
    required this.senderName,
    required this.content,
    required this.timestamp,
  });

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      messageId: json['message_id'] as String,
      senderId: json['sender_id'] as String,
      senderName: json['sender_name'] as String,
      content: json['content'] as String,
      timestamp: DateTime.parse(json['timestamp'] as String),
    );
  }

  Map<String, dynamic> toJson() => {
    'message_id': messageId,
    'sender_id': senderId,
    'sender_name': senderName,
    'content': content,
    'timestamp': timestamp.toIso8601String(),
  };
}

/// 房间聊天管理器
class RoomChatManager {
  final Map<String, Set<dynamic>> _roomConnections = {};
  final Map<String, List<ChatMessage>> _roomMessages = {};

  /// 加入房间
  void joinRoom(String roomId, dynamic connection) {
    _roomConnections.putIfAbsent(roomId, () => {});
    _roomConnections[roomId]!.add(connection);
    _roomMessages.putIfAbsent(roomId, () => []);
  }

  /// 离开房间
  void leaveRoom(String roomId, dynamic connection) {
    _roomConnections[roomId]?.remove(connection);
  }

  /// 广播消息到房间内所有连接
  void broadcastMessage(String roomId, ChatMessage message) {
    // 存储消息（可选，用于历史查询）
    _roomMessages[roomId]?.add(message);

    // 保留最近100条消息
    if (_roomMessages[roomId]!.length > 100) {
      _roomMessages[roomId] = _roomMessages[roomId]!.sublist(
        _roomMessages[roomId]!.length - 100,
      );
    }

    // 广播给所有连接
    final json = jsonEncode(message.toJson());
    for (final connection in _roomConnections[roomId] ?? []) {
      try {
        connection.sink.add(json);
      } catch (_) {
        // 连接已断开，下次 close 事件会清理
      }
    }
  }

  /// 获取房间消息历史
  List<ChatMessage> getMessageHistory(String roomId, {int limit = 50}) {
    final messages = _roomMessages[roomId] ?? [];
    final start = (messages.length - limit).clamp(0, messages.length);
    return messages.sublist(start);
  }

  /// 清理房间（当房间完成时调用）
  void cleanupRoom(String roomId) {
    for (final connection in _roomConnections[roomId] ?? []) {
      try {
        connection.sink.close();
      } catch (_) {}
    }
    _roomConnections.remove(roomId);
    _roomMessages.remove(roomId);
  }
}

/// ============================================
/// Shelf 框架集成示例
/// ============================================
/// 在 server.dart 中的使用方式：
///
/// ```dart
/// import 'package:shelf_web_socket/shelf_web_socket.dart';
/// import 'package:shelf/shelf.dart' as shelf;
/// import 'package:shelf_router/shelf_router.dart';
///
/// final chatManager = RoomChatManager();
///
/// // 路由定义
/// var router = Router()
///   ..get('/rooms/<roomId>/chat',
///     webSocketHandler(
///       (webSocket) async {
///         final roomId = request.requestedUri.pathSegments[1];
///         final token = request.requestedUri.queryParameters['token'];
///
///         // 验证 token
///         if (!_verifyToken(token)) {
///           webSocket.sink.close(4001, 'Unauthorized');
///           return;
///         }
///
///         // 加入房间
///         chatManager.joinRoom(roomId, webSocket);
///
///         // 监听消息
///         webSocket.stream.listen(
///           (message) {
///             try {
///               final json = jsonDecode(message) as Map<String, dynamic>;
///               final chatMsg = ChatMessage.fromJson(json);
///
///               // 广播给房间所有用户
///               chatManager.broadcastMessage(roomId, chatMsg);
///             } catch (e) {
///               print('消息解析失败: $e');
///             }
///           },
///           onDone: () {
///             chatManager.leaveRoom(roomId, webSocket);
///           },
///           onError: (error) {
///             print('WebSocket 错误: $error');
///             chatManager.leaveRoom(roomId, webSocket);
///           },
///         );
///       },
///     ),
///   )
///   ..get('/rooms/<roomId>/messages',
///     (shelf.Request request) {
///       final roomId = request.requestedUri.pathSegments[1];
///       final limit = int.tryParse(
///           request.requestedUri.queryParameters['limit'] ?? '50') ?? 50;
///
///       final messages = chatManager.getMessageHistory(roomId, limit: limit);
///       return shelf.Response.ok(
///         jsonEncode(messages.map((m) => m.toJson()).toList()),
///         headers: {'Content-Type': 'application/json'},
///       );
///     },
///   );
/// ```

/// ============================================
/// Dart Frog 框架集成示例 (推荐)
/// ============================================
///
/// 创建文件: routes/rooms/[id]/chat.dart
///
/// ```dart
/// import 'package:dart_frog/dart_frog.dart';
/// import 'package:web_socket_channel/web_socket_channel.dart';
///
/// Response onRequest(RequestContext context, String id) {
///   return handler(context.request, id);
/// }
///
/// Future<Response> handler(Request request, String roomId) async {
///   // 升级为 WebSocket
///   final channel = WebSocketChannel(
///     request.url.scheme == 'https'
///         ? await SecureSocket.connect(request.url.host, request.url.port)
///         : await Socket.connect(request.url.host, request.url.port),
///   );
///
///   final token = request.url.queryParameters['token'];
///
///   // 验证 token
///   if (!_verifyToken(token)) {
///     await channel.sink.close(4001, 'Unauthorized');
///     return Response();
///   }
///
///   // 加入房间
///   _chatManager.joinRoom(roomId, channel);
///
///   // 处理消息
///   channel.stream.listen(
///     (message) {
///       try {
///         final json = jsonDecode(message) as Map<String, dynamic>;
///         final chatMsg = ChatMessage.fromJson(json);
///         _chatManager.broadcastMessage(roomId, chatMsg);
///       } catch (e) {
///         print('消息解析错误: $e');
///       }
///     },
///     onDone: () {
///       _chatManager.leaveRoom(roomId, channel);
///     },
///     onError: (error) {
///       print('WebSocket 错误: $error');
///       _chatManager.leaveRoom(roomId, channel);
///     },
///   );
///
///   return Response();
/// }
///
/// bool _verifyToken(String? token) {
///   // 实现 token 验证逻辑
///   return token != null && token.isNotEmpty;
/// }
/// ```

/// ============================================
/// 必要的 pubspec.yaml 依赖
/// ============================================
///
/// ```yaml
/// dependencies:
///   shelf: ^1.4.0
///   shelf_web_socket: ^1.4.1
///   shelf_router: ^1.1.3
///   web_socket_channel: ^2.4.0
///
/// # 如果使用 Dart Frog
///   dart_frog: ^1.0.0
/// ```

/// ============================================
/// 数据库 - 消息存储表创建语句
/// ============================================
///
/// ```sql
/// CREATE TABLE room_messages (
///   id SERIAL PRIMARY KEY,
///   message_id VARCHAR(50) NOT NULL UNIQUE,
///   room_id VARCHAR(50) NOT NULL,
///   sender_id VARCHAR(50) NOT NULL,
///   sender_name VARCHAR(100) NOT NULL,
///   content TEXT NOT NULL,
///   created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
///   FOREIGN KEY (room_id) REFERENCES rooms(id)
/// );
///
/// CREATE INDEX idx_room_messages_room_id ON room_messages(room_id, created_at DESC);
/// ```

/// ============================================
/// 完整的集成检查体清单
/// ============================================
///
/// - [x] 前端: ChatService 类实现 WebSocket 连接和消息管理
/// - [x] 前端: 集成 web_socket_channel 依赖
/// - [ ] 后端: 添加依赖 (shelf_web_socket 或 dart_frog)
/// - [ ] 后端: 实现 WS 路由处理
/// - [ ] 后端: 实现 RoomChatManager 或类似的消息广播管理
/// - [ ] 后端: 创建消息存储表
/// - [ ] 后端: 实现 GET /rooms/{roomId}/messages 历史查询 API
/// - [ ] 后端: Token 验证集成
/// - [ ] 后端: 并发连接管理和内存优化
/// - [ ] 测试: 单人发送消息验证
/// - [ ] 测试: 多人房间消息广播验证
/// - [ ] 测试: 连接断开重连验证
/// - [ ] 测试: 负载测试（100+并发连接）
