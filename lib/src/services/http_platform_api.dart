import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/app_models.dart';
import '../models/business_models.dart';
import 'api_exception.dart';
import 'platform_api.dart';

class HttpPlatformApi implements PlatformApi {
  HttpPlatformApi({
    required this.baseUrl,
    String? initialAccessToken,
    http.Client? client,
  }) : _accessToken = initialAccessToken ?? '',
       _client = client ?? http.Client();

  final String baseUrl;
  final http.Client _client;
  String _accessToken;

  @override
  Future<AuthSession> loginWithSms({
    required String phone,
    required String smsCode,
  }) async {
    final payload = await _request(
      method: 'POST',
      path: '/auth/login/sms',
      body: {'phone': phone, 'sms_code': smsCode},
      authRequired: false,
    );
    final session = AuthSession.fromJson(payload);
    _accessToken = session.accessToken;
    return session;
  }

  @override
  Future<AuthSession> registerWithSms({
    required String phone,
    required String smsCode,
    required UserRole role,
    String? displayName,
  }) async {
    final body = <String, dynamic>{
      'phone': phone,
      'sms_code': smsCode,
      'user_role': role.name,
    };
    if (displayName != null && displayName.trim().isNotEmpty) {
      body['display_name'] = displayName.trim();
    }
    final payload = await _request(
      method: 'POST',
      path: '/auth/register/sms',
      body: body,
      authRequired: false,
    );
    final session = AuthSession.fromJson(payload);
    _accessToken = session.accessToken;
    return session;
  }

  @override
  Future<void> logout() async {
    await _request(method: 'POST', path: '/auth/logout', body: const {});
    _accessToken = '';
  }

  @override
  Future<void> setAuthToken(String token) async {
    _accessToken = token;
  }

  @override
  Future<void> updateUserRole(UserRole role) async {
    await _request(
      method: 'POST',
      path: '/auth/role',
      body: {'user_role': role.name},
    );
  }

  @override
  Future<UserProfile> fetchUserProfile() async {
    final payload = await _request(method: 'GET', path: '/user/profile');
    return UserProfile.fromJson(payload as Map<String, dynamic>);
  }

  @override
  Future<UserProfile> updateUserProfile({
    required String displayName,
    required String phone,
    String? password,
  }) async {
    final body = <String, dynamic>{'display_name': displayName, 'phone': phone};
    if (password != null && password.trim().isNotEmpty) {
      body['password'] = password.trim();
    }

    final payload = await _request(
      method: 'POST',
      path: '/user/profile',
      body: body,
    );
    return UserProfile.fromJson(payload as Map<String, dynamic>);
  }

  @override
  Future<List<RoomItem>> fetchRooms({
    required UserRole role,
    String keyword = '',
    String filter = '全部',
  }) async {
    final payload = await _request(
      method: 'GET',
      path: '/rooms',
      query: {'role': role.name, 'keyword': keyword, 'filter': filter},
    );
    final list = _asList(payload);
    return list
        .whereType<Map<String, dynamic>>()
        .map(RoomItem.fromJson)
        .toList();
  }

  @override
  Future<List<RoomItem>> fetchJoinedRooms() async {
    final payload = await _request(method: 'GET', path: '/rooms/joined');
    final list = _asList(payload);
    return list
        .whereType<Map<String, dynamic>>()
        .map(RoomItem.fromJson)
        .toList();
  }

  @override
  Future<List<CompanionItem>> fetchCompanions({bool onlineOnly = true}) async {
    final payload = await _request(
      method: 'GET',
      path: '/companions',
      query: {'online_only': onlineOnly},
    );
    final list = _asList(payload);
    return list
        .whereType<Map<String, dynamic>>()
        .map(CompanionItem.fromJson)
        .toList();
  }

  @override
  Future<RoomItem> createRoom({
    required String roomTitle,
    required int unitPrice,
    required String contribution,
    required int seats,
    required String note,
    required int serviceFeeRate,
    required UserRole creatorRole,
  }) async {
    final payload = await _request(
      method: 'POST',
      path: '/rooms',
      body: {
        'room_title': roomTitle,
        'unit_price': unitPrice,
        'contribution_ratio': contribution,
        'seats': seats,
        'note': note,
        'service_fee_rate': serviceFeeRate,
        'creator_role': creatorRole.name,
      },
    );
    return RoomItem.fromJson(payload as Map<String, dynamic>);
  }

  @override
  Future<RoomItem> joinRoom({
    required String roomId,
    required UserRole role,
  }) async {
    final payload = await _request(
      method: 'POST',
      path: '/rooms/$roomId/join',
      body: {'role': role.name},
    );
    return RoomItem.fromJson(payload as Map<String, dynamic>);
  }

  @override
  Future<RoomItem> confirmCompanionOrder({required String roomId}) async {
    final payload = await _request(
      method: 'POST',
      path: '/rooms/$roomId/accept-order',
      body: const {},
    );
    return RoomItem.fromJson(payload as Map<String, dynamic>);
  }

  @override
  Future<List<RoomMemberItem>> fetchRoomMembers({
    required String roomId,
  }) async {
    final payload = await _request(
      method: 'GET',
      path: '/rooms/$roomId/members',
    );
    final list = _asList(payload);
    return list
        .whereType<Map<String, dynamic>>()
        .map(RoomMemberItem.fromJson)
        .toList();
  }

  @override
  Future<void> inviteCompanion({
    required String roomId,
    required String companionId,
  }) async {
    await _request(
      method: 'POST',
      path: '/rooms/$roomId/invite',
      body: {'companion_id': companionId},
    );
  }

  @override
  Future<void> dissolveRoom({required String roomId}) async {
    await _request(
      method: 'POST',
      path: '/rooms/$roomId/dissolve',
      body: const {},
    );
  }

  @override
  Future<void> confirmRoomCompleted({required String roomId}) async {
    await _request(
      method: 'POST',
      path: '/rooms/$roomId/complete',
      body: const {},
    );
  }

  @override
  Future<void> reportByRoom({
    required String roomId,
    required String reason,
  }) async {
    await _request(
      method: 'POST',
      path: '/reports/rooms',
      body: {'room_id': roomId, 'reason': reason},
    );
  }

  @override
  Future<List<WalletFlowItem>> fetchWalletFlows() async {
    final payload = await _request(method: 'GET', path: '/wallet/flows');
    final list = _asList(payload);
    return list
        .whereType<Map<String, dynamic>>()
        .map(WalletFlowItem.fromJson)
        .toList();
  }

  @override
  Future<void> recharge({required int amount, required String channel}) async {
    await _request(
      method: 'POST',
      path: '/wallet/recharge',
      body: {'amount': amount, 'channel': channel},
    );
  }

  @override
  Future<void> withdraw({required int amount}) async {
    await _request(
      method: 'POST',
      path: '/wallet/withdraw',
      body: {'amount': amount},
    );
  }

  @override
  Future<List<OrderItem>> fetchOrders() async {
    final payload = await _request(method: 'GET', path: '/orders');
    final list = _asList(payload);
    return list
        .whereType<Map<String, dynamic>>()
        .map(OrderItem.fromJson)
        .toList();
  }

  @override
  Future<void> reportByOrder({
    required String orderId,
    required String reason,
  }) async {
    await _request(
      method: 'POST',
      path: '/reports/orders',
      body: {'order_id': orderId, 'reason': reason},
    );
  }

  // ========== 新增的API方法实现 ==========

  @override
  Future<UserBalance> fetchUserBalance() async {
    try {
      final payload = await _request(method: 'GET', path: '/wallet/balance');
      return UserBalance.fromJson(payload as Map<String, dynamic>);
    } on ApiException catch (error) {
      if (error.statusCode != 404) {
        rethrow;
      }
      final flowPayload = await _request(method: 'GET', path: '/wallet/flows');
      final flows = _asList(
        flowPayload,
      ).whereType<Map<String, dynamic>>().map(WalletFlowItem.fromJson).toList();
      return _buildBalanceFromFlows(flows);
    }
  }

  @override
  Future<IdentityVerification> fetchVerificationStatus() async {
    dynamic payload;
    try {
      payload = await _request(method: 'GET', path: '/auth/verify/status');
    } on ApiException catch (error) {
      if (error.statusCode != 404) {
        rethrow;
      }
      payload = await _request(method: 'GET', path: '/auth/verification');
    }
    return IdentityVerification.fromJson(payload as Map<String, dynamic>);
  }

  @override
  Future<void> submitVerification({
    required String realName,
    required String idCardNumber,
    required String idFrontUrl,
    required String idBackUrl,
    required String withHandUrl,
    required String smsCode,
  }) async {
    final body = {
      'real_name': realName,
      'id_card_number': idCardNumber,
      'id_front_url': idFrontUrl,
      'id_back_url': idBackUrl,
      'with_hand_url': withHandUrl,
      'sms_code': smsCode,
    };

    try {
      await _request(method: 'POST', path: '/auth/verify/id-card', body: body);
    } on ApiException catch (error) {
      if (error.statusCode != 404) {
        rethrow;
      }
      await _request(method: 'POST', path: '/auth/verification', body: body);
    }
  }

  @override
  Future<List<WithdrawAccount>> fetchWithdrawAccounts() async {
    final payload = await _request(
      method: 'GET',
      path: '/wallet/withdraw-accounts',
    );
    final list = _asList(payload);
    return list
        .whereType<Map<String, dynamic>>()
        .map(WithdrawAccount.fromJson)
        .toList();
  }

  @override
  Future<void> bindWithdrawAccount({
    required String channel,
    required String accountNumber,
    required String accountName,
  }) async {
    await _request(
      method: 'POST',
      path: '/wallet/withdraw-accounts',
      body: {
        'channel': channel,
        'account_number': accountNumber,
        'account_name': accountName,
      },
    );
  }

  @override
  Future<void> submitWithdraw({
    required int amount,
    required String accountId,
  }) async {
    await _request(
      method: 'POST',
      path: '/wallet/withdraw',
      body: {'amount': amount, 'account_id': accountId},
    );
  }

  @override
  Future<List<PointRecord>> fetchPointRecords() async {
    final payload = await _request(method: 'GET', path: '/points/records');
    final list = _asList(payload);
    return list
        .whereType<Map<String, dynamic>>()
        .map(PointRecord.fromJson)
        .toList();
  }

  @override
  Future<void> submitReport({
    required String targetType,
    required String targetId,
    required String reason,
    String? description,
    List<String>? evidenceUrls,
  }) async {
    await _request(
      method: 'POST',
      path: '/reports',
      body: {
        'target_type': targetType,
        'target_id': targetId,
        'reason': reason,
        if (description != null) 'description': description,
        if (evidenceUrls != null) 'evidence_urls': evidenceUrls,
      },
    );
  }

  @override
  Future<List<Report>> fetchMyReports() async {
    final payload = await _request(method: 'GET', path: '/reports/mine');
    final list = _asList(payload);
    return list.whereType<Map<String, dynamic>>().map(Report.fromJson).toList();
  }

  Future<dynamic> _request({
    required String method,
    required String path,
    Map<String, dynamic>? query,
    Map<String, dynamic>? body,
    bool authRequired = true,
  }) async {
    if (authRequired) {
      if (_accessToken.isEmpty) {
        throw const ApiException('未登录', statusCode: 401);
      }
    }

    final response = await _sendRequest(
      method: method,
      path: path,
      query: query,
      body: body,
      authRequired: authRequired,
    );

    if (response.statusCode == 401 && authRequired) {
      _accessToken = '';
      throw const ApiException('登录已失效，请重新登录', statusCode: 401);
    }

    final decoded = _decodeBody(response.body);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final message = _readErrorMessage(decoded);
      throw ApiException(message, statusCode: response.statusCode);
    }

    return _extractPayload(decoded);
  }

  Future<http.Response> _sendRequest({
    required String method,
    required String path,
    Map<String, dynamic>? query,
    Map<String, dynamic>? body,
    required bool authRequired,
  }) async {
    final uri = Uri.parse(baseUrl).replace(
      path: _joinPath(Uri.parse(baseUrl).path, path),
      queryParameters: _normalizeQuery(query),
    );

    final headers = <String, String>{
      'Content-Type': 'application/json',
      if (_accessToken.isNotEmpty && authRequired)
        'Authorization': 'Bearer $_accessToken',
    };

    if (method == 'GET') {
      return _client.get(uri, headers: headers);
    }
    if (method == 'POST') {
      return _client.post(
        uri,
        headers: headers,
        body: jsonEncode(body ?? const {}),
      );
    }

    throw ApiException('Unsupported method: $method');
  }

  dynamic _decodeBody(String body) {
    if (body.isEmpty) {
      return const {};
    }
    try {
      return jsonDecode(body);
    } catch (_) {
      return {'raw': body};
    }
  }

  dynamic _extractPayload(dynamic decoded) {
    if (decoded is! Map<String, dynamic>) {
      return decoded;
    }

    if (decoded.containsKey('data')) {
      return decoded['data'];
    }
    if (decoded.containsKey('result')) {
      return decoded['result'];
    }
    return decoded;
  }

  String _readErrorMessage(dynamic decoded) {
    if (decoded is Map<String, dynamic>) {
      final message = decoded['message'] ?? decoded['msg'] ?? decoded['error'];
      if (message != null) {
        return message.toString();
      }
    }
    return '请求失败';
  }

  List<dynamic> _asList(dynamic payload) {
    if (payload is List<dynamic>) {
      return payload;
    }
    if (payload is Map<String, dynamic>) {
      final data = payload['items'] ?? payload['list'];
      if (data is List<dynamic>) {
        return data;
      }
    }
    return const [];
  }

  Map<String, String>? _normalizeQuery(Map<String, dynamic>? query) {
    if (query == null || query.isEmpty) {
      return null;
    }

    final normalized = <String, String>{};
    query.forEach((key, value) {
      if (value == null) {
        return;
      }
      final text = value.toString();
      if (text.isEmpty) {
        return;
      }
      normalized[key] = text;
    });
    return normalized.isEmpty ? null : normalized;
  }

  String _joinPath(String basePath, String path) {
    final left = basePath.endsWith('/')
        ? basePath.substring(0, basePath.length - 1)
        : basePath;
    final right = path.startsWith('/') ? path : '/$path';
    return '$left$right';
  }

  UserBalance _buildBalanceFromFlows(List<WalletFlowItem> flows) {
    var availableBalance = 0;
    var points = 0;

    for (final flow in flows) {
      final amount = _parseSignedAmount(flow.amount);
      availableBalance += amount;
      if (flow.type == '充值' && amount > 0) {
        points += amount ~/ 10;
      }
    }

    if (availableBalance < 0) {
      availableBalance = 0;
    }

    return UserBalance(
      totalBalance: availableBalance,
      availableBalance: availableBalance,
      frozenBalance: 0,
      points: points,
      level: _calculateLevel(points),
      updatedAt: DateTime.now(),
    );
  }

  int _parseSignedAmount(String amountText) {
    final text = amountText.trim();
    if (text.isEmpty) {
      return 0;
    }

    final isNegative = text.startsWith('-');
    final digits = text.replaceAll(RegExp(r'[^0-9]'), '');
    final amount = int.tryParse(digits) ?? 0;
    return isNegative ? -amount : amount;
  }

  int _calculateLevel(int points) {
    if (points >= 2000) {
      return 3;
    }
    if (points >= 500) {
      return 2;
    }
    return 1;
  }
}
