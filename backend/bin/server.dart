import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as io;
import 'package:shelf_cors_headers/shelf_cors_headers.dart';
import 'package:shelf_router/shelf_router.dart';
import 'package:shelf_web_socket/shelf_web_socket.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

void main(List<String> args) async {
  final config = await _ServerConfig.load();
  final ip = config.address;
  final port = config.port;

  final app = await _BackendApp.create();

  final pipeline = Pipeline()
      .addMiddleware(logRequests())
      .addMiddleware(corsHeaders())
      .addMiddleware(_jsonContentTypeMiddleware)
      .addHandler(app.router.call);

  final server = await io.serve(pipeline, ip, port);
  stdout.writeln(
    'Backend listening at http://${server.address.host}:${server.port}',
  );

  final done = Completer<void>();
  var shuttingDown = false;

  Future<void> shutdown(String reason) async {
    if (shuttingDown) {
      return;
    }
    shuttingDown = true;
    stdout.writeln('Shutting down backend ($reason)...');
    await server.close(force: true);
    if (!done.isCompleted) {
      done.complete();
    }
  }

  final subscriptions = <StreamSubscription<ProcessSignal>>[];
  final sigintSub = _watchSignal(ProcessSignal.sigint, 'SIGINT', shutdown);
  if (sigintSub != null) {
    subscriptions.add(sigintSub);
  }
  if (!Platform.isWindows) {
    final sigtermSub = _watchSignal(ProcessSignal.sigterm, 'SIGTERM', shutdown);
    if (sigtermSub != null) {
      subscriptions.add(sigtermSub);
    }
  }

  await done.future;
  for (final sub in subscriptions) {
    await sub.cancel();
  }
}

StreamSubscription<ProcessSignal>? _watchSignal(
  ProcessSignal signal,
  String name,
  Future<void> Function(String reason) shutdown,
) {
  try {
    return signal.watch().listen((_) {
      shutdown(name);
    });
  } catch (_) {
    return null;
  }
}

class _ServerConfig {
  const _ServerConfig({required this.address, required this.port});

  final InternetAddress address;
  final int port;

  static Future<_ServerConfig> load() async {
    final configFile = File('config/server.json');
    var host = '0.0.0.0';
    var port = 8080;

    if (await configFile.exists()) {
      final raw = await configFile.readAsString();
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) {
        host = (decoded['host'] ?? host).toString();
        port = _toInt(decoded['port']) ?? port;
      }
    }

    final envHost = Platform.environment['HOST'];
    final envPort = Platform.environment['PORT'];
    if (envHost != null && envHost.trim().isNotEmpty) {
      host = envHost.trim();
    }
    final parsedEnvPort = _toInt(envPort);
    if (parsedEnvPort != null && parsedEnvPort > 0) {
      port = parsedEnvPort;
    }

    final address = _parseAddress(host);
    return _ServerConfig(address: address, port: port);
  }

  static InternetAddress _parseAddress(String host) {
    final normalized = host.trim();
    if (normalized == '0.0.0.0') {
      return InternetAddress.anyIPv4;
    }
    if (normalized == '::') {
      return InternetAddress.anyIPv6;
    }
    return InternetAddress.tryParse(normalized) ?? InternetAddress.anyIPv4;
  }

  static int? _toInt(dynamic value) {
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.toInt();
    }
    if (value == null) {
      return null;
    }
    return int.tryParse(value.toString());
  }
}

Middleware get _jsonContentTypeMiddleware {
  return (innerHandler) {
    return (request) async {
      final response = await innerHandler(request);
      return response.change(
        headers: {
          ...response.headers,
          'content-type': 'application/json; charset=utf-8',
        },
      );
    };
  };
}

class _BackendApp {
  _BackendApp._() {
    _seedData();
  }

  static Future<_BackendApp> create() async {
    final app = _BackendApp._();
    await app._accountStore.load();
    await app._pointRecordStore.load();
    await app._chatManager.load();
    return app;
  }

  final Router router = Router();
  final _AccountStore _accountStore = _AccountStore(
    File('config/accounts.json'),
  );
  final _PointRecordStore _pointRecordStore = _PointRecordStore(
    File('config/point_records.json'),
  );

  final Map<String, String> _tokenToUser = {};
  final List<Map<String, dynamic>> _rooms = [];
  final List<Map<String, dynamic>> _walletFlows = [];
  final List<Map<String, dynamic>> _orders = [];
  final List<Map<String, dynamic>> _reports = [];
  final List<Map<String, dynamic>> _roomInvitations = [];

  // 聊天管理器
  final _RoomChatManager _chatManager = _RoomChatManager(
    _RoomChatStore(File('config/chat_messages.json')),
  );

  int _roomSeq = 13000;
  int _orderSeq = 20260402001;
  int _reportSeq = 1;
  int _inviteSeq = 20260402001;
  static const Duration _inviteTimeout = Duration(minutes: 5);

  void _seedData() {
    _rooms
      ..clear()
      ..addAll([]);

    _walletFlows
      ..clear()
      ..addAll([]);

    _orders
      ..clear()
      ..addAll([]);

    router.post('/auth/login/sms', _loginWithSms);
    router.post('/auth/register/sms', _registerWithSms);
    router.post('/auth/role', _updateRole);
    router.post('/auth/logout', _logout);
    router.get('/user/profile', _getUserProfile);
    router.post('/user/profile', _updateUserProfile);

    router.get('/auth/verify/status', _getVerificationStatus);
    router.get('/auth/verification', _getVerificationStatus);
    router.post('/auth/verify/id-card', _submitVerification);
    router.post('/auth/verification', _submitVerification);

    router.get('/rooms', _getRooms);
    router.get('/rooms/joined', _getJoinedRooms);
    router.get('/companions', _getCompanions);
    router.post('/rooms', _createRoom);
    router.get('/rooms/<roomId>/members', _getRoomMembers);
    router.get('/rooms/<roomId>/invitations', _getRoomInvitations);
    router.get('/invitations/pending', _getPendingInvitations);
    router.post('/rooms/<roomId>/invite', _inviteCompanionToRoom);
    router.post('/rooms/<roomId>/cancel-invite', _cancelCompanionInvitation);
    router.post('/rooms/<roomId>/accept-order', _acceptCompanionOrder);
    router.post('/rooms/<roomId>/reject-order', _rejectCompanionOrder);
    router.post('/rooms/<roomId>/join', _joinRoom);
    router.post('/rooms/<roomId>/dissolve', _dissolveRoom);
    router.post('/rooms/<roomId>/complete', _completeRoom);

    // WebSocket 聊天路由
    router.get('/rooms/<roomId>/chat', _handleWebSocketChat);
    // 聊天消息历史
    router.get('/rooms/<roomId>/messages', _getRoomMessages);

    router.get('/wallet/flows', _walletFlowsHandler);
    router.get('/wallet/balance', _walletBalanceHandler);
    router.post('/wallet/recharge', _recharge);
    router.post('/wallet/withdraw', _withdraw);
    router.get('/points/records', _pointRecordsHandler);
    router.post('/points/bonus', _grantPointBonus);
    router.post('/points/redeem', _redeemPoints);

    router.get('/orders', _getOrders);

    router.post('/reports/rooms', _reportRoom);
    router.post('/reports/orders', _reportOrder);
    router.post('/reports', _submitReport);
    router.get('/reports/mine', _getMyReports);
    router.get('/reports/all', _getAllReports);
    router.post('/reports/<reportId>/review', _reviewReport);
  }

  /// WebSocket 聊天处理
  FutureOr<Response> _handleWebSocketChat(Request request, String roomId) {
    final handler = webSocketHandler((WebSocketChannel webSocket) {
      final token = request.url.queryParameters['token'];
      final userId = token != null ? _tokenToUser[token] : null;

      // 验证 token（简化版，允许 mock-token）
      String finalUserId;
      String userName;
      String userRole;

      if (userId != null) {
        finalUserId = userId;
        final account = _accountStore.findByUserId(userId);
        userName = account?.displayName ?? _displayNameFromUserId(userId);
        userRole = account?.role ?? 'boss';
      } else if (token == 'mock-token') {
        // 支持 mock 模式
        finalUserId = 'mock-user';
        userName = '测试用户';
        userRole = 'boss';
      } else {
        webSocket.sink.close(4001, 'Unauthorized');
        return;
      }

      // 加入房间
      final connection = _ChatConnection(
        webSocket: webSocket,
        userId: finalUserId,
        userName: userName,
        userRole: userRole,
      );
      _chatManager.joinRoom(roomId, connection);

      // 发送历史消息
      final history = _chatManager.getMessageHistory(roomId, limit: 50);
      for (final msg in history) {
        webSocket.sink.add(jsonEncode(msg.toJson()));
      }

      // 发送系统欢迎消息
      final welcomeMsg = _ChatMessage(
        messageId: 'sys_${DateTime.now().millisecondsSinceEpoch}',
        senderId: 'system',
        senderName: '系统',
        content: '$userName 加入了聊天室',
        timestamp: DateTime.now(),
        messageType: 'system',
      );
      unawaited(_chatManager.broadcastMessage(roomId, welcomeMsg));

      // 监听消息
      webSocket.stream.listen(
        (message) {
          try {
            final json = jsonDecode(message as String) as Map<String, dynamic>;
            final messageType = (json['message_type'] ?? 'text').toString();
            final content = (json['content'] ?? '').toString();
            final eventType = (json['type'] ?? '').toString();

            if (eventType == 'ping' || messageType == 'ping') {
              return;
            }
            if (content.trim().isEmpty) {
              return;
            }

            final chatMsg = _ChatMessage(
              messageId:
                  json['message_id'] as String? ??
                  'msg_${DateTime.now().millisecondsSinceEpoch}',
              senderId: finalUserId,
              senderName: userName,
              content: content,
              timestamp: DateTime.now(),
              messageType: messageType,
            );

            // 广播给房间所有用户
            unawaited(_chatManager.broadcastMessage(roomId, chatMsg));
          } catch (e) {
            stdout.writeln('消息解析失败: $e');
          }
        },
        onDone: () {
          _chatManager.leaveRoom(roomId, connection);
          // 发送离开消息
          final leaveMsg = _ChatMessage(
            messageId: 'sys_${DateTime.now().millisecondsSinceEpoch}',
            senderId: 'system',
            senderName: '系统',
            content: '$userName 离开了聊天室',
            timestamp: DateTime.now(),
            messageType: 'system',
          );
          unawaited(_chatManager.broadcastMessage(roomId, leaveMsg));
        },
        onError: (error) {
          stdout.writeln('WebSocket 错误: $error');
          _chatManager.leaveRoom(roomId, connection);
        },
      );
    });
    return handler(request);
  }

  /// 获取房间聊天历史
  Response _getRoomMessages(Request request, String roomId) {
    final limitParam = request.url.queryParameters['limit'];
    final offsetParam = request.url.queryParameters['offset'];
    final limit = (int.tryParse(limitParam ?? '50') ?? 50).clamp(1, 200);
    final offset = (int.tryParse(offsetParam ?? '0') ?? 0).clamp(0, 1000000);

    final messages = _chatManager.getMessageHistory(
      roomId,
      limit: limit,
      offset: offset,
    );
    final total = _chatManager.getMessageTotal(roomId);

    return _ok({
      'items': messages.map((m) => m.toJson()).toList(),
      'paging': {
        'limit': limit,
        'offset': offset,
        'total': total,
        'has_more': offset + messages.length < total,
      },
    });
  }

  Future<Response> _loginWithSms(Request request) async {
    final body = await _readJsonBody(request);
    final phone = (body['phone'] ?? '').toString().trim();
    final smsCode = (body['sms_code'] ?? '').toString().trim();

    if (phone.isEmpty || smsCode.isEmpty) {
      return _error('phone 或 sms_code 不能为空', statusCode: 400);
    }

    final account = _accountStore.findByPhone(phone);
    if (account == null) {
      return _error('账号不存在，请先注册', statusCode: 404);
    }
    if (account.smsCode != smsCode) {
      return _error('验证码不正确', statusCode: 401);
    }

    final accessToken = 'token_${DateTime.now().millisecondsSinceEpoch}_$phone';
    final refreshToken =
        'refresh_${DateTime.now().millisecondsSinceEpoch}_$phone';

    account.lastLoginAt = DateTime.now();
    await _accountStore.save();
    _tokenToUser[accessToken] = account.userId;

    return _ok({
      'access_token': accessToken,
      'refresh_token': refreshToken,
      'user_id': account.userId,
      'user_role': account.role,
      'verification_status': account.verificationStatus,
    });
  }

  Future<Response> _logout(Request request) async {
    final token = _extractToken(request);
    if (token != null) {
      _tokenToUser.remove(token);
    }
    return _ok({'success': true});
  }

  Future<Response> _updateRole(Request request) async {
    final currentUserId = _currentUserId(request);
    if (currentUserId.isEmpty) {
      return _error('unauthorized', statusCode: 401);
    }

    final body = await _readJsonBody(request);
    final userRole = (body['user_role'] ?? '').toString().trim();
    if (userRole != 'boss' && userRole != 'companion') {
      return _error('user_role 参数无效', statusCode: 400);
    }

    final account = _accountStore.findByUserId(currentUserId);
    if (account == null) {
      return _error('account not found', statusCode: 404);
    }

    account.role = userRole;
    account.updatedAt = DateTime.now();
    await _accountStore.save();
    return _ok({'success': true, 'user_role': account.role});
  }

  Future<Response> _registerWithSms(Request request) async {
    final body = await _readJsonBody(request);
    final phone = (body['phone'] ?? '').toString().trim();
    final smsCode = (body['sms_code'] ?? '').toString().trim();
    final userRole = (body['user_role'] ?? 'boss').toString().trim();
    final displayName = (body['display_name'] ?? '').toString().trim();

    if (phone.isEmpty || smsCode.isEmpty) {
      return _error('phone 或 sms_code 不能为空', statusCode: 400);
    }

    if (userRole != 'boss' && userRole != 'companion') {
      return _error('user_role 参数无效', statusCode: 400);
    }

    if (_accountStore.findByPhone(phone) != null) {
      return _error('账号已存在，请直接登录', statusCode: 409);
    }

    final account = await _accountStore.register(
      phone: phone,
      smsCode: smsCode,
      role: userRole,
      displayName: displayName,
    );
    final accessToken = 'token_${DateTime.now().millisecondsSinceEpoch}_$phone';
    final refreshToken =
        'refresh_${DateTime.now().millisecondsSinceEpoch}_$phone';

    _tokenToUser[accessToken] = account.userId;

    return _ok({
      'access_token': accessToken,
      'refresh_token': refreshToken,
      'user_id': account.userId,
      'user_role': account.role,
      'verification_status': account.verificationStatus,
    });
  }

  Future<Response> _getUserProfile(Request request) async {
    final currentUserId = _currentUserId(request);
    if (currentUserId.isEmpty) {
      return _error('unauthorized', statusCode: 401);
    }

    final account = _accountStore.findByUserId(currentUserId);
    if (account == null) {
      return _error('account not found', statusCode: 404);
    }

    return _ok({
      'user_id': account.userId,
      'display_name': account.displayName,
      'phone': account.phone,
      'avatar': account.avatar,
    });
  }

  Future<Response> _updateUserProfile(Request request) async {
    final currentUserId = _currentUserId(request);
    if (currentUserId.isEmpty) {
      return _error('unauthorized', statusCode: 401);
    }

    final body = await _readJsonBody(request);
    final displayName = (body['display_name'] ?? '').toString().trim();
    final phone = (body['phone'] ?? '').toString().trim();
    final password = (body['password'] ?? '').toString().trim();
    final avatar = (body['avatar'] ?? '').toString().trim();

    if (displayName.isEmpty || phone.isEmpty) {
      return _error('display_name/phone 不能为空', statusCode: 400);
    }

    _StoredAccount? account;
    try {
      account = await _accountStore.updateProfile(
        userId: currentUserId,
        displayName: displayName,
        phone: phone,
        password: password.isEmpty ? null : password,
        avatar: avatar.isEmpty ? null : avatar,
      );
    } on FormatException catch (e) {
      return _error(e.message, statusCode: 409);
    }

    if (account == null) {
      return _error('account not found', statusCode: 404);
    }

    return _ok({
      'user_id': account.userId,
      'display_name': account.displayName,
      'phone': account.phone,
      'avatar': account.avatar,
    });
  }

  Future<Response> _getVerificationStatus(Request request) async {
    final currentUserId = _currentUserId(request);
    if (currentUserId.isEmpty) {
      return _error('unauthorized', statusCode: 401);
    }

    final account = _accountStore.findByUserId(currentUserId);
    if (account == null) {
      return _error('account not found', statusCode: 404);
    }

    return _ok(_verificationPayload(account));
  }

  Future<Response> _submitVerification(Request request) async {
    final currentUserId = _currentUserId(request);
    if (currentUserId.isEmpty) {
      return _error('unauthorized', statusCode: 401);
    }

    final body = await _readJsonBody(request);
    final realName = (body['real_name'] ?? '').toString().trim();
    final idCardNumber = (body['id_card_number'] ?? '').toString().trim();
    final idFrontUrl = (body['id_front_url'] ?? '').toString().trim();
    final idBackUrl = (body['id_back_url'] ?? '').toString().trim();
    final withHandUrl = (body['with_hand_url'] ?? '').toString().trim();

    if (realName.isEmpty ||
        idCardNumber.isEmpty ||
        idFrontUrl.isEmpty ||
        idBackUrl.isEmpty ||
        withHandUrl.isEmpty) {
      return _error('实名认证参数无效', statusCode: 400);
    }

    final account = _accountStore.findByUserId(currentUserId);
    if (account == null) {
      return _error('account not found', statusCode: 404);
    }

    account.verificationStatus = 'pending';
    account.verificationRealName = realName;
    account.verificationIdCardNumber = idCardNumber;
    account.verificationIdFrontUrl = idFrontUrl;
    account.verificationIdBackUrl = idBackUrl;
    account.verificationWithHandUrl = withHandUrl;
    account.verificationRejectReason = null;
    account.verificationSubmittedAt = DateTime.now();
    account.verificationVerifiedAt = null;
    account.updatedAt = DateTime.now();
    await _accountStore.save();

    return _ok(_verificationPayload(account));
  }

  Map<String, dynamic> _verificationPayload(_StoredAccount account) {
    return {
      'user_id': account.userId,
      'status': account.verificationStatus,
      'real_name': account.verificationRealName,
      'id_card_number': account.verificationIdCardNumber,
      'id_front_url': account.verificationIdFrontUrl,
      'id_back_url': account.verificationIdBackUrl,
      'with_hand_url': account.verificationWithHandUrl,
      'reject_reason': account.verificationRejectReason,
      'submitted_at': account.verificationSubmittedAt?.toIso8601String(),
      'verified_at': account.verificationVerifiedAt?.toIso8601String(),
    };
  }

  Future<Response> _getRooms(Request request) async {
    final authError = _requireAuth(request);
    if (authError != null) {
      return authError;
    }

    _expirePendingInvitations();

    final keyword = (request.url.queryParameters['keyword'] ?? '').trim();
    final filter = (request.url.queryParameters['filter'] ?? '全部').trim();
    final sort = (request.url.queryParameters['sort'] ?? 'latest').trim();
    final role = (request.url.queryParameters['role'] ?? '').trim();
    final currentUser = _currentUserId(request);

    final filtered = _rooms
        .where((room) {
          final hitKeyword =
              keyword.isEmpty ||
              room['title'].toString().contains(keyword) ||
              room['owner_name'].toString().contains(keyword) ||
              (room['tags'] as List).join(' ').contains(keyword);
          final hitFilter =
              filter == '全部' ||
              room['status'] == filter ||
              (room['tags'] as List).contains(filter);

          var hitRole = true;
          if (role == 'boss' || role == 'companion') {
            final creatorRole = (room['creator_role'] ?? '').toString();
            final creatorUserId = (room['creator_user_id'] ?? '').toString();
            if (role == 'companion') {
              final members = _roomMembers(room);
              hitRole = members.any((member) {
                final memberUserId = (member['user_id'] ?? '').toString();
                final memberStatus = (member['status'] ?? '').toString();
                return memberUserId == currentUser &&
                    (memberStatus == '房主' ||
                        memberStatus == '待确认接单' ||
                        memberStatus == '已加入' ||
                        memberStatus == '已接单');
              });
            } else {
              hitRole = creatorRole != role || creatorUserId == currentUser;
            }
          }

          return hitKeyword && hitFilter && hitRole;
        })
        .toList(growable: true);

    switch (sort) {
      case 'price_asc':
        filtered.sort(
          (a, b) => _toInt(a['unit_price']).compareTo(_toInt(b['unit_price'])),
        );
        break;
      case 'price_desc':
        filtered.sort(
          (a, b) => _toInt(b['unit_price']).compareTo(_toInt(a['unit_price'])),
        );
        break;
      case 'seats_desc':
        filtered.sort(
          (a, b) => _toInt(b['seats_left']).compareTo(_toInt(a['seats_left'])),
        );
        break;
      case 'latest':
      default:
        filtered.sort((a, b) {
          final aId = (a['room_id'] ?? '').toString().replaceFirst('R-', '');
          final bId = (b['room_id'] ?? '').toString().replaceFirst('R-', '');
          final aNum = int.tryParse(aId) ?? 0;
          final bNum = int.tryParse(bId) ?? 0;
          return bNum.compareTo(aNum);
        });
        break;
    }

    return _ok({'items': filtered});
  }

  Future<Response> _createRoom(Request request) async {
    final authError = _requireAuth(request);
    if (authError != null) {
      return authError;
    }

    final body = await _readJsonBody(request);
    final title = (body['room_title'] ?? '').toString().trim();
    final unitPrice = _toInt(body['unit_price']);
    final contributionRatio = (body['contribution_ratio'] ?? '').toString();
    final seats = _toInt(body['seats']);
    final note = (body['note'] ?? '').toString();
    final creatorRole = (body['creator_role'] ?? 'boss').toString();
    final currentUserId = _currentUserId(request);
    final ownerName = _displayNameFromUserId(currentUserId);

    if (title.isEmpty || contributionRatio.isEmpty || seats <= 0) {
      return _error(
        'room_title/contribution_ratio/seats 参数无效',
        statusCode: 400,
      );
    }

    if (creatorRole != 'boss' && creatorRole != 'companion') {
      return _error('creator_role 参数无效', statusCode: 400);
    }

    _roomSeq += 1;
    final room = {
      'room_id': 'R-$_roomSeq',
      'title': title,
      'owner_name': ownerName,
      'unit_price': unitPrice,
      'status': '待加入',
      'seats_left': seats,
      'contribution_ratio': contributionRatio,
      'note': note,
      'commission': (unitPrice * 0.75).toInt(),
      'tags': ['新建'],
      'creator_role': creatorRole,
      'creator_user_id': currentUserId,
      'members': [
        {
          'user_id': currentUserId,
          'user_name': ownerName,
          'role': creatorRole,
          'status': '房主',
        },
      ],
    };

    _rooms.insert(0, room);
    return _ok(room, statusCode: 201);
  }

  Future<Response> _getCompanions(Request request) async {
    final authError = _requireAuth(request);
    if (authError != null) {
      return authError;
    }

    final onlineOnly =
        (request.url.queryParameters['online_only'] ?? 'true').toLowerCase() !=
        'false';

    final currentUserId = _currentUserId(request);
    final users = _onlineUserIds()
        .where((userId) => userId != currentUserId)
        .map((userId) {
          final name = _displayNameFromUserId(userId);
          return <String, dynamic>{
            'companion_id': userId,
            'name': name,
            'rank': _rankFromUserId(userId),
            'price_per_game': 180 + userId.length * 5,
            'online': true,
            'service_count': 50 + userId.length,
            'rating': 4.6,
            'tags': const ['在线', '可邀请'],
          };
        })
        .toList(growable: false);

    final list = onlineOnly ? users : users;

    return _ok({'items': list});
  }

  Future<Response> _getJoinedRooms(Request request) async {
    final authError = _requireAuth(request);
    if (authError != null) {
      return authError;
    }

    final currentUserId = _currentUserId(request);
    final list = _rooms
        .where((room) {
          final members = _roomMembers(room);
          return members.any((member) {
            final memberUserId = (member['user_id'] ?? '').toString();
            final memberStatus = (member['status'] ?? '').toString();
            return memberUserId == currentUserId &&
                (memberStatus == '房主' ||
                    memberStatus == '已加入' ||
                    memberStatus == '已接单');
          });
        })
        .toList(growable: false);

    return _ok({'items': list});
  }

  Future<Response> _getRoomMembers(Request request, String roomId) async {
    final authError = _requireAuth(request);
    if (authError != null) {
      return authError;
    }

    final room = _findRoomById(roomId);
    if (room == null) {
      return _error('room not found', statusCode: 404);
    }

    final members = _roomMembers(room);
    return _ok({'items': members});
  }

  Future<Response> _getRoomInvitations(Request request, String roomId) async {
    final authError = _requireAuth(request);
    if (authError != null) {
      return authError;
    }

    final room = _findRoomById(roomId);
    if (room == null) {
      return _error('room not found', statusCode: 404);
    }

    _expirePendingInvitations(roomId: roomId);

    final currentUserId = _currentUserId(request);
    final isOwner = (room['creator_user_id'] ?? '').toString() == currentUserId;
    if (!isOwner) {
      final members = _roomMembers(room);
      final isMember = members.any(
        (member) => (member['user_id'] ?? '').toString() == currentUserId,
      );
      if (!isMember) {
        return _error('无权限查看邀请记录', statusCode: 403);
      }
    }

    final items =
        _roomInvitations
            .where((item) => (item['room_id'] ?? '').toString() == roomId)
            .toList(growable: false)
          ..sort((a, b) {
            final aTime = (a['created_at'] ?? '').toString();
            final bTime = (b['created_at'] ?? '').toString();
            return bTime.compareTo(aTime);
          });

    return _ok({'items': items});
  }

  Future<Response> _getPendingInvitations(Request request) async {
    final authError = _requireAuth(request);
    if (authError != null) {
      return authError;
    }

    _expirePendingInvitations();

    _markOrphanPendingInvitationsFailed();

    final currentUserId = _currentUserId(request);
    final items =
        _roomInvitations
            .where(
              (item) =>
                  (item['invitee_user_id'] ?? '').toString() == currentUserId &&
                  (item['status'] ?? '').toString() == 'pending',
            )
            .toList(growable: false)
          ..sort((a, b) {
            final aTime = (a['created_at'] ?? '').toString();
            final bTime = (b['created_at'] ?? '').toString();
            return bTime.compareTo(aTime);
          });

    return _ok({'items': items});
  }

  Future<Response> _inviteCompanionToRoom(
    Request request,
    String roomId,
  ) async {
    final authError = _requireAuth(request);
    if (authError != null) {
      return authError;
    }

    final room = _findRoomById(roomId);
    if (room == null) {
      return _error('room not found', statusCode: 404);
    }

    final currentUserId = _currentUserId(request);
    if ((room['creator_user_id'] ?? '').toString() != currentUserId) {
      return _error('仅房主可邀请陪玩', statusCode: 403);
    }
    if ((room['creator_role'] ?? '').toString() != 'boss') {
      return _error('仅找陪玩身份可邀请陪玩', statusCode: 403);
    }

    final roomStatus = (room['status'] ?? '').toString();
    if (roomStatus == '已完成' || roomStatus == '已解散') {
      return _error('当前房间状态不允许邀请陪玩', statusCode: 409);
    }

    final body = await _readJsonBody(request);
    final companionId = (body['companion_id'] ?? '').toString();
    if (companionId.isEmpty) {
      return _error('companion_id 参数无效', statusCode: 400);
    }
    if (companionId == currentUserId) {
      return _error('不能邀请自己', statusCode: 400);
    }

    if (!_onlineUserIds().contains(companionId)) {
      return _error('陪玩不存在', statusCode: 404);
    }

    _expirePendingInvitations(roomId: roomId);

    final companionName = _displayNameFromUserId(companionId);

    final seatsLeft = _toInt(room['seats_left']);
    if (seatsLeft <= 0) {
      return _error('房间已满', statusCode: 409);
    }

    final members = _roomMembers(room);
    if (members.any((m) => (m['user_id'] ?? '').toString() == companionId)) {
      return _error('该陪玩已在房间中', statusCode: 409);
    }

    final hasPendingInvite = _roomInvitations.any(
      (item) =>
          (item['room_id'] ?? '').toString() == roomId &&
          (item['invitee_user_id'] ?? '').toString() == companionId &&
          (item['status'] ?? '').toString() == 'pending',
    );
    if (hasPendingInvite) {
      return _error('该陪玩已有待处理邀请', statusCode: 409);
    }

    _inviteSeq += 1;
    final inviteId = 'INV-$_inviteSeq';
    final now = DateTime.now();
    final expiresAt = now.add(_inviteTimeout);
    _roomInvitations.insert(0, {
      'invite_id': inviteId,
      'room_id': roomId,
      'room_title': (room['title'] ?? '').toString(),
      'inviter_user_id': currentUserId,
      'inviter_user_name': _displayNameFromUserId(currentUserId),
      'invitee_user_id': companionId,
      'invitee_user_name': companionName,
      'status': 'pending',
      'created_at': now.toIso8601String(),
      'expires_at': expiresAt.toIso8601String(),
      'decided_at': null,
      'reject_reason': null,
    });

    members.add({
      'user_id': companionId,
      'user_name': companionName,
      'role': 'companion',
      'status': '待确认接单',
      'invite_id': inviteId,
    });
    room['members'] = members;

    return _ok({'success': true, 'room': room});
  }

  Future<Response> _acceptCompanionOrder(Request request, String roomId) async {
    final authError = _requireAuth(request);
    if (authError != null) {
      return authError;
    }

    final room = _findRoomById(roomId);
    if (room == null) {
      return _error('room not found', statusCode: 404);
    }

    final currentUserId = _currentUserId(request);
    _expirePendingInvitations(roomId: roomId);

    final invitation = _findPendingInvitation(
      roomId: roomId,
      inviteeUserId: currentUserId,
    );
    if (invitation == null) {
      return _error('当前房间没有你的待接单邀请', statusCode: 403);
    }

    final roomStatus = (room['status'] ?? '').toString();
    if (roomStatus == '已完成' || roomStatus == '已解散') {
      _markInvitationFailed(
        invitation,
        reason: '房间状态不可接单',
        removePendingMember: true,
      );
      return _error('当前房间状态不允许接单', statusCode: 409);
    }

    final members = _roomMembers(room);
    final memberIndex = members.indexWhere(
      (member) =>
          (member['user_id'] ?? '').toString() == currentUserId &&
          (member['role'] ?? '').toString() == 'companion',
    );

    if (memberIndex < 0) {
      return _error('当前房间没有你的待接单邀请', statusCode: 403);
    }

    final memberStatus = (members[memberIndex]['status'] ?? '').toString();
    if (memberStatus != '待确认接单') {
      _markInvitationFailed(
        invitation,
        reason: '邀请状态不可接单',
        removePendingMember: false,
      );
      return _error('当前邀请状态不可确认接单', statusCode: 409);
    }

    final seatsLeft = _toInt(room['seats_left']);
    if (seatsLeft <= 0) {
      _markInvitationFailed(
        invitation,
        reason: '房间已满',
        removePendingMember: true,
      );
      return _error('房间已满', statusCode: 409);
    }

    members[memberIndex]['status'] = '已接单';
    members[memberIndex].remove('invite_id');
    room['members'] = members;

    invitation['status'] = 'accepted';
    invitation['decided_at'] = DateTime.now().toIso8601String();

    final updatedSeats = seatsLeft - 1;
    room['seats_left'] = updatedSeats;
    room['status'] = updatedSeats == 0 ? '进行中' : '待加入';

    final companionName = _displayNameFromUserId(currentUserId);
    _orderSeq += 1;
    _orders.insert(0, {
      'order_id': 'O-$_orderSeq',
      'room_id': roomId,
      'partner_name': companionName,
      'unit_price': room['unit_price'],
      'contribution_ratio': room['contribution_ratio'],
      'status': room['status'] == '进行中' ? '进行中' : '待开始',
      'room_title': room['title'],
      'settle_to': currentUserId,
    });

    return _ok(room);
  }

  Future<Response> _cancelCompanionInvitation(
    Request request,
    String roomId,
  ) async {
    final authError = _requireAuth(request);
    if (authError != null) {
      return authError;
    }

    final room = _findRoomById(roomId);
    if (room == null) {
      return _error('room not found', statusCode: 404);
    }

    final currentUserId = _currentUserId(request);
    if ((room['creator_user_id'] ?? '').toString() != currentUserId) {
      return _error('仅房主可取消邀请', statusCode: 403);
    }

    final body = await _readJsonBody(request);
    final companionId = (body['companion_id'] ?? '').toString();
    if (companionId.isEmpty) {
      return _error('companion_id 参数无效', statusCode: 400);
    }

    _expirePendingInvitations(roomId: roomId);

    final invitation = _findPendingInvitation(
      roomId: roomId,
      inviteeUserId: companionId,
    );
    if (invitation == null) {
      return _error('未找到可取消的待处理邀请', statusCode: 404);
    }

    invitation['status'] = 'cancelled';
    invitation['decided_at'] = DateTime.now().toIso8601String();
    invitation['reject_reason'] = 'inviter_cancelled';

    final members = _roomMembers(room);
    members.removeWhere(
      (member) =>
          (member['user_id'] ?? '').toString() == companionId &&
          (member['status'] ?? '').toString() == '待确认接单',
    );
    room['members'] = members;

    return _ok({'success': true, 'room': room});
  }

  Future<Response> _rejectCompanionOrder(Request request, String roomId) async {
    final authError = _requireAuth(request);
    if (authError != null) {
      return authError;
    }

    final room = _findRoomById(roomId);
    if (room == null) {
      return _error('room not found', statusCode: 404);
    }

    final roomStatus = (room['status'] ?? '').toString();
    if (roomStatus == '已完成' || roomStatus == '已解散') {
      return _error('当前房间状态不允许拒绝接单', statusCode: 409);
    }

    final currentUserId = _currentUserId(request);
    _expirePendingInvitations(roomId: roomId);

    final invitation = _findPendingInvitation(
      roomId: roomId,
      inviteeUserId: currentUserId,
    );
    if (invitation == null) {
      return _error('当前房间没有你的待接单邀请', statusCode: 403);
    }

    final members = _roomMembers(room);
    final memberIndex = members.indexWhere(
      (member) =>
          (member['user_id'] ?? '').toString() == currentUserId &&
          (member['role'] ?? '').toString() == 'companion',
    );

    if (memberIndex < 0) {
      return _error('当前房间没有你的待接单邀请', statusCode: 403);
    }

    final memberStatus = (members[memberIndex]['status'] ?? '').toString();
    if (memberStatus != '待确认接单') {
      return _error('当前邀请状态不可拒绝接单', statusCode: 409);
    }

    members.removeAt(memberIndex);
    room['members'] = members;

    invitation['status'] = 'rejected';
    invitation['decided_at'] = DateTime.now().toIso8601String();

    return _ok(room);
  }

  Future<Response> _joinRoom(Request request, String roomId) async {
    final authError = _requireAuth(request);
    if (authError != null) {
      return authError;
    }

    final room = _findRoomById(roomId);
    if (room == null) {
      return _error('room not found', statusCode: 404);
    }

    final roomStatus = (room['status'] ?? '').toString();
    if (roomStatus == '已完成' || roomStatus == '已解散') {
      return _error('当前房间状态无法加入', statusCode: 409);
    }

    final body = await _readJsonBody(request);
    final joinerRole = (body['role'] ?? '').toString();
    if (joinerRole != 'boss' && joinerRole != 'companion') {
      return _error('role 参数无效', statusCode: 400);
    }

    final creatorRole = (room['creator_role'] ?? 'boss').toString();
    if (creatorRole == joinerRole) {
      return _error('当前房间只支持对端角色加入', statusCode: 403);
    }

    final joinerUserId = _currentUserId(request);
    final joinerName = _displayNameFromUserId(joinerUserId);
    final members = _roomMembers(room);

    if (members.any((member) => (member['user_id'] ?? '') == joinerUserId)) {
      return _error('你已在房间中', statusCode: 409);
    }

    final seatsLeft = _toInt(room['seats_left']);
    if (seatsLeft <= 0) {
      return _error('房间已满', statusCode: 409);
    }

    members.add({
      'user_id': joinerUserId,
      'user_name': joinerName,
      'role': joinerRole,
      'status': joinerRole == 'companion' ? '已接单' : '已加入',
    });
    room['members'] = members;

    final updatedSeats = seatsLeft - 1;
    room['seats_left'] = updatedSeats;
    room['status'] = updatedSeats == 0 ? '进行中' : '待加入';

    _orderSeq += 1;
    _orders.insert(0, {
      'order_id': 'O-$_orderSeq',
      'room_id': roomId,
      'partner_name': joinerName,
      'unit_price': room['unit_price'],
      'contribution_ratio': room['contribution_ratio'],
      'status': room['status'] == '进行中' ? '进行中' : '待开始',
      'room_title': room['title'],
    });

    return _ok(room);
  }

  Future<Response> _dissolveRoom(Request request, String roomId) async {
    final authError = _requireAuth(request);
    if (authError != null) {
      return authError;
    }

    final room = _findRoomById(roomId);
    if (room == null) {
      return _error('room not found', statusCode: 404);
    }

    final currentUserId = _currentUserId(request);
    if ((room['creator_user_id'] ?? '').toString() != currentUserId) {
      return _error('仅房主可解散房间', statusCode: 403);
    }

    if ((room['creator_role'] ?? '').toString() != 'boss') {
      return _error('仅找陪玩身份可解散房间', statusCode: 403);
    }

    if ((room['status'] ?? '').toString() == '已完成') {
      return _error('已完成房间不可解散', statusCode: 409);
    }

    _resolvePendingInvitationsForRoom(
      roomId,
      status: 'cancelled',
      reason: 'room_dissolved',
      removePendingMember: false,
    );

    final members = _roomMembers(room);
    for (final member in members) {
      member['status'] = '已解散';
    }
    room['members'] = members;
    room['status'] = '已解散';

    var updatedOrders = 0;
    for (final order in _orders) {
      if ((order['room_id'] ?? '').toString() == roomId) {
        order['status'] = '已解散';
        updatedOrders += 1;
      }
    }

    _rooms.removeWhere((item) => (item['room_id'] ?? '').toString() == roomId);

    return _ok({'success': true, 'updated_orders': updatedOrders});
  }

  Future<Response> _completeRoom(Request request, String roomId) async {
    final authError = _requireAuth(request);
    if (authError != null) {
      return authError;
    }

    final room = _findRoomById(roomId);
    if (room == null) {
      return _error('room not found', statusCode: 404);
    }

    final currentUserId = _currentUserId(request);
    if ((room['creator_user_id'] ?? '').toString() != currentUserId) {
      return _error('仅房主可确认完成', statusCode: 403);
    }

    final roomStatus = (room['status'] ?? '').toString();
    if (roomStatus == '已完成') {
      return _error('房间已完成，无需重复确认', statusCode: 409);
    }
    if (roomStatus == '已解散') {
      return _error('已解散房间不可确认完成', statusCode: 409);
    }

    _resolvePendingInvitationsForRoom(
      roomId,
      status: 'failed',
      reason: 'room_completed',
      removePendingMember: true,
    );

    room['status'] = '已完成';

    final members = _roomMembers(room);
    for (final member in members) {
      member['status'] = '已完成';
    }
    room['members'] = members;

    var updatedOrders = 0;
    var settleAmount = 0;
    for (final order in _orders) {
      if ((order['room_id'] ?? '').toString() == roomId) {
        order['status'] = '已结算给陪玩';
        settleAmount += _toInt(order['unit_price']);
        updatedOrders += 1;
      }
    }

    if (settleAmount > 0) {
      _walletFlows.insert(0, {
        'user_id': currentUserId,
        'type': '陪玩结算',
        'amount': '-$settleAmount',
        'status': '成功',
        'created_at': _nowShort(),
      });
      final points = settleAmount ~/ 10;
      if (points > 0) {
        await _appendPointRecord(
          userId: currentUserId,
          points: points,
          reason: 'consumption',
          relatedOrderId: roomId,
        );
      }
    }

    return _ok({
      'success': true,
      'updated_orders': updatedOrders,
      'settle_amount': settleAmount,
    });
  }

  Future<Response> _walletFlowsHandler(Request request) async {
    final authError = _requireAuth(request);
    if (authError != null) {
      return authError;
    }

    final currentUserId = _currentUserId(request);
    final userFlows = _walletFlows
        .where((flow) => _flowBelongsToUser(flow, currentUserId))
        .toList(growable: false);

    return _ok({'items': userFlows});
  }

  Future<Response> _walletBalanceHandler(Request request) async {
    final authError = _requireAuth(request);
    if (authError != null) {
      return authError;
    }

    final currentUserId = _currentUserId(request);
    final userFlows = _walletFlows
        .where((flow) => _flowBelongsToUser(flow, currentUserId))
        .toList(growable: false);

    var availableBalance = 0;
    var points = _sumUserPoints(currentUserId);

    for (final flow in userFlows) {
      final amountText = (flow['amount'] ?? '').toString().trim();
      final amount = _parseSignedAmount(amountText);
      availableBalance += amount;
    }

    if (availableBalance < 0) {
      availableBalance = 0;
    }

    final level = points >= 2000
        ? 3
        : points >= 500
        ? 2
        : 1;

    return _ok({
      'total_balance': availableBalance,
      'available_balance': availableBalance,
      'frozen_balance': 0,
      'points': points,
      'level': level,
      'updated_at': DateTime.now().toIso8601String(),
    });
  }

  Future<Response> _recharge(Request request) async {
    final authError = _requireAuth(request);
    if (authError != null) {
      return authError;
    }

    final body = await _readJsonBody(request);
    final amount = _toInt(body['amount']);
    final channel = (body['channel'] ?? '').toString();
    final currentUserId = _currentUserId(request);
    if (amount <= 0 || channel.isEmpty) {
      return _error('amount/channel 参数无效', statusCode: 400);
    }

    _walletFlows.insert(0, {
      'user_id': currentUserId,
      'type': '充值',
      'amount': '+$amount',
      'status': '成功',
      'created_at': _nowShort(),
    });

    final points = amount ~/ 10;
    if (points > 0) {
      await _appendPointRecord(
        userId: currentUserId,
        points: points,
        reason: 'activity',
      );
    }

    return _ok({'success': true});
  }

  Future<Response> _withdraw(Request request) async {
    final authError = _requireAuth(request);
    if (authError != null) {
      return authError;
    }

    final body = await _readJsonBody(request);
    final amount = _toInt(body['amount']);
    final currentUserId = _currentUserId(request);
    if (amount <= 0) {
      return _error('amount 参数无效', statusCode: 400);
    }

    _walletFlows.insert(0, {
      'user_id': currentUserId,
      'type': '提现',
      'amount': '-$amount',
      'status': '处理中',
      'created_at': _nowShort(),
    });

    return _ok({'success': true});
  }

  Future<Response> _pointRecordsHandler(Request request) async {
    final authError = _requireAuth(request);
    if (authError != null) {
      return authError;
    }

    final currentUserId = _currentUserId(request);
    final records = _pointRecordStore
        .listByUser(currentUserId)
        .map((record) => record.toJson())
        .toList(growable: false);

    return _ok({'items': records});
  }

  Future<Response> _grantPointBonus(Request request) async {
    final authError = _requireAuth(request);
    if (authError != null) {
      return authError;
    }

    final body = await _readJsonBody(request);
    final points = _toInt(body['points']);
    if (points <= 0) {
      return _error('points 参数无效', statusCode: 400);
    }

    final currentUserId = _currentUserId(request);
    await _appendPointRecord(
      userId: currentUserId,
      points: points,
      reason: 'bonus',
    );

    return _ok({'success': true, 'points': points});
  }

  Future<Response> _redeemPoints(Request request) async {
    final authError = _requireAuth(request);
    if (authError != null) {
      return authError;
    }

    final body = await _readJsonBody(request);
    final points = _toInt(body['points']);
    if (points <= 0) {
      return _error('points 参数无效', statusCode: 400);
    }

    final currentUserId = _currentUserId(request);
    final currentPoints = _sumUserPoints(currentUserId);
    if (points > currentPoints) {
      return _error('积分不足', statusCode: 400);
    }

    await _appendPointRecord(
      userId: currentUserId,
      points: -points,
      reason: 'redemption',
    );

    return _ok({'success': true, 'redeemed_points': points});
  }

  Future<Response> _getOrders(Request request) async {
    final authError = _requireAuth(request);
    if (authError != null) {
      return authError;
    }

    return _ok({'items': _orders});
  }

  Future<Response> _reportRoom(Request request) async {
    final authError = _requireAuth(request);
    if (authError != null) {
      return authError;
    }

    final body = await _readJsonBody(request);
    final roomId = (body['room_id'] ?? '').toString().trim();
    final reason = (body['reason'] ?? '').toString().trim();
    if (roomId.isEmpty || reason.isEmpty) {
      return _error('room_id/reason 参数无效', statusCode: 400);
    }

    final currentUserId = _currentUserId(request);
    final report = _createReportRecord(
      reporterId: currentUserId,
      targetType: 'room',
      targetId: roomId,
      reason: reason,
      description: (body['description'] ?? '').toString().trim(),
      evidenceUrls: (body['evidence_urls'] is List)
          ? (body['evidence_urls'] as List)
                .map((e) => e.toString().trim())
                .where((e) => e.isNotEmpty)
                .toList()
          : const <String>[],
    );

    return _ok({'accepted': true, 'report': report});
  }

  Future<Response> _reportOrder(Request request) async {
    final authError = _requireAuth(request);
    if (authError != null) {
      return authError;
    }

    final body = await _readJsonBody(request);
    final orderId = (body['order_id'] ?? '').toString().trim();
    final reason = (body['reason'] ?? '').toString().trim();
    if (orderId.isEmpty || reason.isEmpty) {
      return _error('order_id/reason 参数无效', statusCode: 400);
    }

    final currentUserId = _currentUserId(request);
    final report = _createReportRecord(
      reporterId: currentUserId,
      targetType: 'order',
      targetId: orderId,
      reason: reason,
      description: (body['description'] ?? '').toString().trim(),
      evidenceUrls: (body['evidence_urls'] is List)
          ? (body['evidence_urls'] as List)
                .map((e) => e.toString().trim())
                .where((e) => e.isNotEmpty)
                .toList()
          : const <String>[],
    );

    return _ok({'accepted': true, 'report': report});
  }

  Future<Response> _submitReport(Request request) async {
    final authError = _requireAuth(request);
    if (authError != null) {
      return authError;
    }

    final body = await _readJsonBody(request);
    final targetType = (body['target_type'] ?? '').toString().trim();
    final targetId = (body['target_id'] ?? '').toString().trim();
    final reason = (body['reason'] ?? '').toString().trim();
    final description = (body['description'] ?? '').toString().trim();

    if (targetType.isEmpty || targetId.isEmpty || reason.isEmpty) {
      return _error('target_type/target_id/reason 参数无效', statusCode: 400);
    }

    final currentUserId = _currentUserId(request);
    final report = _createReportRecord(
      reporterId: currentUserId,
      targetType: targetType,
      targetId: targetId,
      reason: reason,
      description: description,
      evidenceUrls: (body['evidence_urls'] is List)
          ? (body['evidence_urls'] as List)
                .map((e) => e.toString().trim())
                .where((e) => e.isNotEmpty)
                .toList()
          : const <String>[],
    );

    return _ok(report, statusCode: 201);
  }

  Future<Response> _getMyReports(Request request) async {
    final authError = _requireAuth(request);
    if (authError != null) {
      return authError;
    }

    final currentUserId = _currentUserId(request);
    final items =
        _reports
            .where(
              (item) => (item['reporter_id'] ?? '').toString() == currentUserId,
            )
            .toList()
          ..sort(
            (a, b) => (b['created_at'] ?? '').toString().compareTo(
              (a['created_at'] ?? '').toString(),
            ),
          );

    return _ok({'items': items});
  }

  Future<Response> _getAllReports(Request request) async {
    final authError = _requireAuth(request);
    if (authError != null) {
      return authError;
    }

    final currentUserId = _currentUserId(request);
    final account = _accountStore.findByUserId(currentUserId);
    if (account == null) {
      return _error('account not found', statusCode: 404);
    }
    if (account.role != 'boss') {
      return _error('仅审核员可查看全部举报', statusCode: 403);
    }

    final items = List<Map<String, dynamic>>.from(_reports)
      ..sort(
        (a, b) => (b['created_at'] ?? '').toString().compareTo(
          (a['created_at'] ?? '').toString(),
        ),
      );

    return _ok({'items': items});
  }

  Future<Response> _reviewReport(Request request, String reportId) async {
    final authError = _requireAuth(request);
    if (authError != null) {
      return authError;
    }

    final currentUserId = _currentUserId(request);
    final account = _accountStore.findByUserId(currentUserId);
    if (account == null) {
      return _error('account not found', statusCode: 404);
    }
    if (account.role != 'boss') {
      return _error('仅审核员可处理举报', statusCode: 403);
    }

    final body = await _readJsonBody(request);
    final status = (body['status'] ?? '').toString().trim();
    final adminNotes = (body['admin_notes'] ?? '').toString().trim();
    if (status != 'under_review' &&
        status != 'approved' &&
        status != 'rejected') {
      return _error('status 参数无效', statusCode: 400);
    }

    final index = _reports.indexWhere(
      (item) => (item['report_id'] ?? '').toString() == reportId,
    );
    if (index < 0) {
      return _error('report not found', statusCode: 404);
    }

    final report = _reports[index];
    final currentStatus = (report['status'] ?? '').toString();
    if ((currentStatus == 'approved' || currentStatus == 'rejected') &&
        status == 'under_review') {
      return _error('已结案举报不可回退到审核中', statusCode: 409);
    }

    report['status'] = status;
    if (adminNotes.isNotEmpty) {
      report['admin_notes'] = adminNotes;
    }
    report['reviewed_by'] = currentUserId;
    report['reviewed_at'] = DateTime.now().toIso8601String();
    report['resolved_at'] = (status == 'approved' || status == 'rejected')
        ? DateTime.now().toIso8601String()
        : null;

    return _ok(report);
  }

  Map<String, dynamic> _createReportRecord({
    required String reporterId,
    required String targetType,
    required String targetId,
    required String reason,
    required String description,
    required List<String> evidenceUrls,
  }) {
    final now = DateTime.now();
    final report = <String, dynamic>{
      'report_id': 'rp_${now.millisecondsSinceEpoch}_${_reportSeq++}',
      'reporter_id': reporterId,
      'target_type': targetType,
      'target_id': targetId,
      'reason': reason,
      'description': description.isEmpty ? null : description,
      'evidence_urls': evidenceUrls,
      'status': 'pending',
      'admin_notes': null,
      'created_at': now.toIso8601String(),
      'resolved_at': null,
    };
    _reports.add(report);
    return report;
  }

  Future<Map<String, dynamic>> _readJsonBody(Request request) async {
    final raw = await request.readAsString();
    if (raw.isEmpty) {
      return <String, dynamic>{};
    }
    final decoded = jsonDecode(raw);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('JSON body must be an object');
    }
    return decoded;
  }

  Response? _requireAuth(Request request) {
    final token = _extractToken(request);
    if (token == null || !_tokenToUser.containsKey(token)) {
      return _error('unauthorized', statusCode: 401);
    }
    return null;
  }

  String _currentUserId(Request request) {
    final token = _extractToken(request);
    if (token == null) {
      return '';
    }
    return _tokenToUser[token] ?? '';
  }

  String _displayNameFromUserId(String userId) {
    if (userId.isEmpty) {
      return '当前用户';
    }
    final account = _accountStore.findByUserId(userId);
    if (account != null) {
      final displayName = account.displayName.trim();
      if (displayName.isNotEmpty && displayName != '当前用户') {
        return displayName;
      }
    }
    if (userId.startsWith('u_')) {
      final suffix = userId.substring(2);
      if (suffix.length >= 4) {
        return '用户${suffix.substring(suffix.length - 4)}';
      }
    }
    return userId;
  }

  List<String> _onlineUserIds() {
    return _tokenToUser.values.toSet().toList(growable: false);
  }

  String _rankFromUserId(String userId) {
    final hash = userId.codeUnits.fold<int>(0, (sum, value) => sum + value);
    const ranks = ['钻石', '大师', '宗师', '王者'];
    return ranks[hash % ranks.length];
  }

  Map<String, dynamic>? _findRoomById(String roomId) {
    final index = _rooms.indexWhere((room) => room['room_id'] == roomId);
    if (index < 0) {
      return null;
    }
    return _rooms[index];
  }

  List<Map<String, dynamic>> _roomMembers(Map<String, dynamic> room) {
    final raw = room['members'];
    if (raw is List) {
      return raw.whereType<Map<String, dynamic>>().toList(growable: true);
    }
    return <Map<String, dynamic>>[];
  }

  Map<String, dynamic>? _findPendingInvitation({
    required String roomId,
    required String inviteeUserId,
  }) {
    for (final invitation in _roomInvitations) {
      if ((invitation['room_id'] ?? '').toString() != roomId) {
        continue;
      }
      if ((invitation['invitee_user_id'] ?? '').toString() != inviteeUserId) {
        continue;
      }
      if ((invitation['status'] ?? '').toString() != 'pending') {
        continue;
      }
      return invitation;
    }
    return null;
  }

  void _expirePendingInvitations({String? roomId}) {
    final now = DateTime.now();
    for (final invitation in _roomInvitations) {
      if ((invitation['status'] ?? '').toString() != 'pending') {
        continue;
      }
      if (roomId != null &&
          (invitation['room_id'] ?? '').toString() != roomId) {
        continue;
      }

      final expiresAtText = (invitation['expires_at'] ?? '').toString();
      final expiresAt = DateTime.tryParse(expiresAtText);
      if (expiresAt == null || now.isBefore(expiresAt)) {
        continue;
      }

      invitation['status'] = 'expired';
      invitation['decided_at'] = now.toIso8601String();

      final targetRoomId = (invitation['room_id'] ?? '').toString();
      final inviteeUserId = (invitation['invitee_user_id'] ?? '').toString();
      final room = _findRoomById(targetRoomId);
      if (room == null) {
        continue;
      }
      final members = _roomMembers(room);
      members.removeWhere(
        (member) =>
            (member['user_id'] ?? '').toString() == inviteeUserId &&
            (member['status'] ?? '').toString() == '待确认接单',
      );
      room['members'] = members;
    }
  }

  void _markInvitationFailed(
    Map<String, dynamic> invitation, {
    required String reason,
    required bool removePendingMember,
  }) {
    if ((invitation['status'] ?? '').toString() != 'pending') {
      return;
    }

    invitation['status'] = 'failed';
    invitation['decided_at'] = DateTime.now().toIso8601String();
    invitation['reject_reason'] = reason;

    if (!removePendingMember) {
      return;
    }

    final roomId = (invitation['room_id'] ?? '').toString();
    final inviteeUserId = (invitation['invitee_user_id'] ?? '').toString();
    final room = _findRoomById(roomId);
    if (room == null) {
      return;
    }

    final members = _roomMembers(room);
    members.removeWhere(
      (member) =>
          (member['user_id'] ?? '').toString() == inviteeUserId &&
          (member['status'] ?? '').toString() == '待确认接单',
    );
    room['members'] = members;
  }

  void _resolvePendingInvitationsForRoom(
    String roomId, {
    required String status,
    required String reason,
    required bool removePendingMember,
  }) {
    final now = DateTime.now().toIso8601String();
    for (final invitation in _roomInvitations) {
      if ((invitation['room_id'] ?? '').toString() != roomId) {
        continue;
      }
      if ((invitation['status'] ?? '').toString() != 'pending') {
        continue;
      }
      invitation['status'] = status;
      invitation['decided_at'] = now;
      invitation['reject_reason'] = reason;
    }

    if (!removePendingMember) {
      return;
    }

    final room = _findRoomById(roomId);
    if (room == null) {
      return;
    }
    final members = _roomMembers(room);
    members.removeWhere(
      (member) => (member['status'] ?? '').toString() == '待确认接单',
    );
    room['members'] = members;
  }

  void _markOrphanPendingInvitationsFailed() {
    final now = DateTime.now().toIso8601String();
    for (final invitation in _roomInvitations) {
      if ((invitation['status'] ?? '').toString() != 'pending') {
        continue;
      }
      final roomId = (invitation['room_id'] ?? '').toString();
      if (_findRoomById(roomId) != null) {
        continue;
      }
      invitation['status'] = 'failed';
      invitation['decided_at'] = now;
      invitation['reject_reason'] = 'room_not_found';
    }
  }

  String? _extractToken(Request request) {
    final authHeader = request.headers['authorization'];
    if (authHeader == null || !authHeader.startsWith('Bearer ')) {
      return null;
    }
    return authHeader.substring(7).trim();
  }

  int _toInt(dynamic value) {
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.toInt();
    }
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  int _parseSignedAmount(String amountText) {
    if (amountText.isEmpty) {
      return 0;
    }

    final isNegative = amountText.startsWith('-');
    final digits = amountText.replaceAll(RegExp(r'[^0-9]'), '');
    final value = int.tryParse(digits) ?? 0;
    return isNegative ? -value : value;
  }

  int _sumUserPoints(String userId) {
    var sum = 0;
    for (final record in _pointRecordStore.listByUser(userId)) {
      sum += record.points;
    }
    if (sum < 0) {
      return 0;
    }
    return sum;
  }

  Future<void> _appendPointRecord({
    required String userId,
    required int points,
    required String reason,
    String? relatedOrderId,
  }) async {
    final record = _StoredPointRecord(
      recordId:
          'pr_${DateTime.now().millisecondsSinceEpoch}_${_pointRecordStore.length + 1}',
      userId: userId,
      points: points,
      reason: reason,
      relatedOrderId: relatedOrderId,
      createdAt: DateTime.now(),
    );
    await _pointRecordStore.add(record);
  }

  bool _flowBelongsToUser(Map<String, dynamic> flow, String userId) {
    final flowUserId = (flow['user_id'] ?? '').toString();
    if (flowUserId.isEmpty) {
      return true;
    }
    return flowUserId == userId;
  }

  String _nowShort() {
    final now = DateTime.now();
    final mm = now.month.toString().padLeft(2, '0');
    final dd = now.day.toString().padLeft(2, '0');
    final hh = now.hour.toString().padLeft(2, '0');
    final min = now.minute.toString().padLeft(2, '0');
    return '$mm-$dd $hh:$min';
  }

  Response _ok(dynamic data, {int statusCode = 200}) {
    return Response(statusCode, body: jsonEncode({'data': data}));
  }

  Response _error(String message, {int statusCode = 400}) {
    return Response(statusCode, body: jsonEncode({'message': message}));
  }
}

class _StoredAccount {
  _StoredAccount({
    required this.phone,
    required this.smsCode,
    required this.userId,
    required this.displayName,
    required this.avatar,
    required this.role,
    required this.createdAt,
    required this.updatedAt,
    this.lastLoginAt,
    this.verificationStatus = 'notStarted',
    this.verificationRealName,
    this.verificationIdCardNumber,
    this.verificationIdFrontUrl,
    this.verificationIdBackUrl,
    this.verificationWithHandUrl,
    this.verificationRejectReason,
    this.verificationSubmittedAt,
    this.verificationVerifiedAt,
  });

  String phone;
  String smsCode;
  final String userId;
  String displayName;
  String avatar;
  String role;
  final DateTime createdAt;
  DateTime updatedAt;
  DateTime? lastLoginAt;
  String verificationStatus;
  String? verificationRealName;
  String? verificationIdCardNumber;
  String? verificationIdFrontUrl;
  String? verificationIdBackUrl;
  String? verificationWithHandUrl;
  String? verificationRejectReason;
  DateTime? verificationSubmittedAt;
  DateTime? verificationVerifiedAt;

  factory _StoredAccount.fromJson(Map<String, dynamic> json) {
    return _StoredAccount(
      phone: (json['phone'] ?? '').toString(),
      smsCode: (json['sms_code'] ?? '').toString(),
      userId: (json['user_id'] ?? '').toString(),
      displayName: (json['display_name'] ?? '当前用户').toString(),
      avatar: (json['avatar'] ?? '🎮').toString(),
      role: (json['role'] ?? 'boss').toString(),
      createdAt: _parseDateTime(json['created_at']) ?? DateTime.now(),
      updatedAt: _parseDateTime(json['updated_at']) ?? DateTime.now(),
      lastLoginAt: _parseDateTime(json['last_login_at']),
      verificationStatus: (json['verification_status'] ?? 'notStarted')
          .toString(),
      verificationRealName: json['verification_real_name']?.toString(),
      verificationIdCardNumber: json['verification_id_card_number']?.toString(),
      verificationIdFrontUrl: json['verification_id_front_url']?.toString(),
      verificationIdBackUrl: json['verification_id_back_url']?.toString(),
      verificationWithHandUrl: json['verification_with_hand_url']?.toString(),
      verificationRejectReason: json['verification_reject_reason']?.toString(),
      verificationSubmittedAt: _parseDateTime(
        json['verification_submitted_at'],
      ),
      verificationVerifiedAt: _parseDateTime(json['verification_verified_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'phone': phone,
      'sms_code': smsCode,
      'user_id': userId,
      'display_name': displayName,
      'avatar': avatar,
      'role': role,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      if (lastLoginAt != null) 'last_login_at': lastLoginAt!.toIso8601String(),
      'verification_status': verificationStatus,
      if (verificationRealName != null)
        'verification_real_name': verificationRealName,
      if (verificationIdCardNumber != null)
        'verification_id_card_number': verificationIdCardNumber,
      if (verificationIdFrontUrl != null)
        'verification_id_front_url': verificationIdFrontUrl,
      if (verificationIdBackUrl != null)
        'verification_id_back_url': verificationIdBackUrl,
      if (verificationWithHandUrl != null)
        'verification_with_hand_url': verificationWithHandUrl,
      if (verificationRejectReason != null)
        'verification_reject_reason': verificationRejectReason,
      if (verificationSubmittedAt != null)
        'verification_submitted_at': verificationSubmittedAt!.toIso8601String(),
      if (verificationVerifiedAt != null)
        'verification_verified_at': verificationVerifiedAt!.toIso8601String(),
    };
  }
}

class _AccountStore {
  _AccountStore(this.file);

  final File file;
  final Map<String, _StoredAccount> _accounts = {};

  Future<void> load() async {
    if (await file.exists()) {
      final raw = await file.readAsString();
      if (raw.trim().isNotEmpty) {
        final decoded = jsonDecode(raw);
        if (decoded is Map<String, dynamic>) {
          final items = decoded['accounts'];
          if (items is List) {
            for (final item in items) {
              if (item is Map<String, dynamic>) {
                final account = _StoredAccount.fromJson(item);
                if (account.phone.isNotEmpty) {
                  _accounts[account.phone] = account;
                }
              }
            }
          }
        }
      }
    }

    if (_accounts.isEmpty) {
      final demoAccount = _StoredAccount(
        phone: '13800000000',
        smsCode: '123456',
        userId: 'u_13800000000',
        displayName: '风暴小刘',
        avatar: _randomAvatar(),
        role: 'boss',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      _accounts[demoAccount.phone] = demoAccount;
      await save();
    }
  }

  _StoredAccount? findByPhone(String phone) {
    return _accounts[phone];
  }

  _StoredAccount? findByUserId(String userId) {
    for (final account in _accounts.values) {
      if (account.userId == userId) {
        return account;
      }
    }
    return null;
  }

  Future<_StoredAccount> register({
    required String phone,
    required String smsCode,
    required String role,
    String? displayName,
  }) async {
    final now = DateTime.now();
    final suffix = phone.length >= 4
        ? phone.substring(phone.length - 4)
        : phone;
    final account = _StoredAccount(
      phone: phone,
      smsCode: smsCode,
      userId: 'u_$phone',
      displayName: (displayName ?? '').trim().isEmpty
          ? '玩家$suffix'
          : displayName!.trim(),
      avatar: _randomAvatar(),
      role: role,
      createdAt: now,
      updatedAt: now,
    );
    _accounts[phone] = account;
    await save();
    return account;
  }

  Future<_StoredAccount?> updateProfile({
    required String userId,
    required String displayName,
    required String phone,
    String? password,
    String? avatar,
  }) async {
    final account = findByUserId(userId);
    if (account == null) {
      return null;
    }

    final newPhone = phone.trim();
    if (newPhone.isEmpty) {
      return account;
    }

    final conflict = findByPhone(newPhone);
    if (conflict != null && conflict.userId != userId) {
      throw const FormatException('手机号已被其他账号使用');
    }

    final oldPhone = account.phone;
    account.phone = newPhone;
    account.displayName = displayName.trim().isEmpty
        ? account.displayName
        : displayName.trim();
    if (avatar != null && avatar.trim().isNotEmpty) {
      account.avatar = avatar.trim();
    }
    if (password != null && password.trim().isNotEmpty) {
      account.smsCode = password.trim();
    }
    account.updatedAt = DateTime.now();

    if (oldPhone != account.phone) {
      _accounts.remove(oldPhone);
      _accounts[account.phone] = account;
    }

    await save();
    return account;
  }

  Future<void> save() async {
    if (!await file.parent.exists()) {
      await file.parent.create(recursive: true);
    }

    final payload = {
      'accounts': _accounts.values.map((account) => account.toJson()).toList(),
    };

    await file.writeAsString(
      const JsonEncoder.withIndent('  ').convert(payload),
    );
  }

  static const List<String> _avatarPool = [
    '🎮',
    '🦊',
    '🐼',
    '🐯',
    '🐻',
    '🦁',
    '🐧',
    '🐵',
    '🐨',
    '🐸',
    '🦄',
    '🐙',
  ];

  static String _randomAvatar() {
    final random = Random();
    return _avatarPool[random.nextInt(_avatarPool.length)];
  }
}

class _StoredPointRecord {
  _StoredPointRecord({
    required this.recordId,
    required this.userId,
    required this.points,
    required this.reason,
    this.relatedOrderId,
    required this.createdAt,
  });

  final String recordId;
  final String userId;
  final int points;
  final String reason;
  final String? relatedOrderId;
  final DateTime createdAt;

  factory _StoredPointRecord.fromJson(Map<String, dynamic> json) {
    return _StoredPointRecord(
      recordId: (json['record_id'] ?? '').toString(),
      userId: (json['user_id'] ?? '').toString(),
      points: _toIntLoose(json['points']),
      reason: (json['reason'] ?? 'activity').toString(),
      relatedOrderId: json['related_order_id']?.toString(),
      createdAt: _parseDateTime(json['created_at']) ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'record_id': recordId,
      'user_id': userId,
      'points': points,
      'reason': reason,
      if (relatedOrderId != null) 'related_order_id': relatedOrderId,
      'created_at': createdAt.toIso8601String(),
    };
  }
}

class _PointRecordStore {
  _PointRecordStore(this.file);

  final File file;
  final List<_StoredPointRecord> _records = [];

  int get length => _records.length;

  Future<void> load() async {
    _records.clear();
    if (!await file.exists()) {
      return;
    }

    final raw = await file.readAsString();
    if (raw.trim().isEmpty) {
      return;
    }

    final decoded = jsonDecode(raw);
    if (decoded is! Map<String, dynamic>) {
      return;
    }

    final items = decoded['records'];
    if (items is! List) {
      return;
    }

    for (final item in items) {
      if (item is! Map<String, dynamic>) {
        continue;
      }
      final record = _StoredPointRecord.fromJson(item);
      if (record.recordId.isEmpty || record.userId.isEmpty) {
        continue;
      }
      _records.add(record);
    }
  }

  List<_StoredPointRecord> listByUser(String userId) {
    final list = _records.where((record) => record.userId == userId).toList();
    list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return list;
  }

  Future<void> add(_StoredPointRecord record) async {
    _records.add(record);
    await save();
  }

  Future<void> save() async {
    if (!await file.parent.exists()) {
      await file.parent.create(recursive: true);
    }

    final payload = {
      'records': _records.map((record) => record.toJson()).toList(),
    };
    await file.writeAsString(
      const JsonEncoder.withIndent('  ').convert(payload),
    );
  }
}

int _toIntLoose(dynamic value) {
  if (value is int) {
    return value;
  }
  if (value is num) {
    return value.toInt();
  }
  return int.tryParse(value?.toString() ?? '') ?? 0;
}

DateTime? _parseDateTime(dynamic value) {
  if (value == null) {
    return null;
  }
  return DateTime.tryParse(value.toString());
}

// ============================================
// WebSocket 聊天相关类
// ============================================

/// 聊天消息模型
class _ChatMessage {
  final String messageId;
  final String senderId;
  final String senderName;
  final String content;
  final DateTime timestamp;
  final String messageType; // 'text', 'system', 'image'

  _ChatMessage({
    required this.messageId,
    required this.senderId,
    required this.senderName,
    required this.content,
    required this.timestamp,
    this.messageType = 'text',
  });

  factory _ChatMessage.fromJson(Map<String, dynamic> json) {
    return _ChatMessage(
      messageId: json['message_id'] as String,
      senderId: json['sender_id'] as String,
      senderName: json['sender_name'] as String,
      content: json['content'] as String,
      timestamp: DateTime.parse(json['timestamp'] as String),
      messageType: json['message_type'] as String? ?? 'text',
    );
  }

  Map<String, dynamic> toJson() => {
    'message_id': messageId,
    'sender_id': senderId,
    'sender_name': senderName,
    'content': content,
    'timestamp': timestamp.toIso8601String(),
    'message_type': messageType,
  };
}

/// 聊天连接
class _ChatConnection {
  final WebSocketChannel webSocket;
  final String userId;
  final String userName;
  final String userRole;

  _ChatConnection({
    required this.webSocket,
    required this.userId,
    required this.userName,
    required this.userRole,
  });
}

/// 聊天消息持久化存储
class _RoomChatStore {
  _RoomChatStore(this.file);

  final File file;
  final Map<String, List<_ChatMessage>> _messagesByRoom = {};

  Future<void> load() async {
    _messagesByRoom.clear();
    if (!await file.exists()) {
      return;
    }

    final raw = await file.readAsString();
    if (raw.trim().isEmpty) {
      return;
    }

    final decoded = jsonDecode(raw);
    if (decoded is! Map<String, dynamic>) {
      return;
    }

    final rooms = decoded['rooms'];
    if (rooms is! Map<String, dynamic>) {
      return;
    }

    for (final entry in rooms.entries) {
      final roomId = entry.key.toString();
      final value = entry.value;
      if (value is! List) {
        continue;
      }

      final messages = <_ChatMessage>[];
      for (final item in value) {
        if (item is Map<String, dynamic>) {
          final message = _ChatMessage.fromJson(item);
          if (message.messageId.isNotEmpty) {
            messages.add(message);
          }
        }
      }
      messages.sort((a, b) => a.timestamp.compareTo(b.timestamp));
      if (messages.isNotEmpty) {
        _messagesByRoom[roomId] = messages;
      }
    }
  }

  List<_ChatMessage> listByRoom(
    String roomId, {
    int limit = 50,
    int offset = 0,
  }) {
    final messages = _messagesByRoom[roomId] ?? const <_ChatMessage>[];
    if (messages.isEmpty) {
      return const <_ChatMessage>[];
    }

    final safeLimit = limit <= 0 ? 50 : limit;
    final safeOffset = offset < 0 ? 0 : offset;
    final endExclusive = (messages.length - safeOffset).clamp(
      0,
      messages.length,
    );
    if (endExclusive <= 0) {
      return const <_ChatMessage>[];
    }
    final start = (endExclusive - safeLimit).clamp(0, endExclusive);
    return messages.sublist(start, endExclusive);
  }

  int countByRoom(String roomId) {
    return _messagesByRoom[roomId]?.length ?? 0;
  }

  Future<void> addMessage(String roomId, _ChatMessage message) async {
    final messages = _messagesByRoom.putIfAbsent(roomId, () => []);
    messages.add(message);
    if (messages.length > 500) {
      messages.removeRange(0, messages.length - 500);
    }
    await save();
  }

  Future<void> save() async {
    if (!await file.parent.exists()) {
      await file.parent.create(recursive: true);
    }

    final payload = <String, dynamic>{
      'rooms': _messagesByRoom.map(
        (roomId, messages) => MapEntry(
          roomId,
          messages.map((message) => message.toJson()).toList(),
        ),
      ),
    };

    await file.writeAsString(
      const JsonEncoder.withIndent('  ').convert(payload),
    );
  }
}

/// 房间聊天管理器
class _RoomChatManager {
  _RoomChatManager(this._store);

  final _RoomChatStore _store;
  final Map<String, Set<_ChatConnection>> _roomConnections = {};

  Future<void> load() async {
    await _store.load();
  }

  /// 加入房间
  void joinRoom(String roomId, _ChatConnection connection) {
    _roomConnections.putIfAbsent(roomId, () => {});
    _roomConnections[roomId]!.add(connection);
    stdout.writeln(
      '用户 ${connection.userName} 加入房间 $roomId，当前连接数: ${_roomConnections[roomId]!.length}',
    );
  }

  /// 离开房间
  void leaveRoom(String roomId, _ChatConnection connection) {
    _roomConnections[roomId]?.remove(connection);
    stdout.writeln(
      '用户 ${connection.userName} 离开房间 $roomId，当前连接数: ${_roomConnections[roomId]?.length ?? 0}',
    );
  }

  /// 广播消息到房间内所有连接
  Future<void> broadcastMessage(String roomId, _ChatMessage message) async {
    await _store.addMessage(roomId, message);

    // 广播给所有连接
    final json = jsonEncode(message.toJson());
    final connections = _roomConnections[roomId] ?? {};
    final deadConnections = <_ChatConnection>[];

    for (final connection in connections) {
      try {
        connection.webSocket.sink.add(json);
      } catch (e) {
        // 连接已断开
        deadConnections.add(connection);
      }
    }

    // 清理断开的连接
    for (final dead in deadConnections) {
      _roomConnections[roomId]?.remove(dead);
    }

    stdout.writeln(
      '房间 $roomId 广播消息: ${message.senderName}: ${message.content.length > 20 ? message.content.substring(0, 20) + "..." : message.content}',
    );
  }

  /// 获取房间消息历史
  List<_ChatMessage> getMessageHistory(
    String roomId, {
    int limit = 50,
    int offset = 0,
  }) {
    return _store.listByRoom(roomId, limit: limit, offset: offset);
  }

  int getMessageTotal(String roomId) {
    return _store.countByRoom(roomId);
  }

  /// 获取房间在线用户数
  int getOnlineCount(String roomId) {
    return _roomConnections[roomId]?.length ?? 0;
  }

  /// 清理房间（当房间完成/解散时调用）
  void cleanupRoom(String roomId) {
    for (final connection in _roomConnections[roomId] ?? {}) {
      try {
        connection.webSocket.sink.close(1000, 'Room closed');
      } catch (_) {}
    }
    _roomConnections.remove(roomId);
    stdout.writeln('房间 $roomId 已清理');
  }
}
