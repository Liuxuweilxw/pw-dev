import '../data/mock_data.dart';
import '../models/app_models.dart';
import '../models/business_models.dart';

abstract class PlatformApi {
  Future<AuthSession> loginWithSms({
    required String phone,
    required String smsCode,
  });

  Future<AuthSession> registerWithSms({
    required String phone,
    required String smsCode,
    required UserRole role,
    String? displayName,
  });

  Future<void> setAuthToken(String token);

  String get authToken;

  Future<void> updateUserRole(UserRole role);

  Future<UserProfile> fetchUserProfile();

  Future<UserProfile> updateUserProfile({
    required String displayName,
    required String phone,
    String? password,
  });

  Future<void> logout();

  Future<List<RoomItem>> fetchRooms({
    required UserRole role,
    String keyword,
    String filter,
  });

  Future<List<RoomItem>> fetchJoinedRooms();

  Future<List<CompanionItem>> fetchCompanions({bool onlineOnly = true});

  Future<RoomItem> createRoom({
    required String roomTitle,
    required int unitPrice,
    required String contribution,
    required int seats,
    required String note,
    required int serviceFeeRate,
    required UserRole creatorRole,
  });

  Future<RoomItem> joinRoom({required String roomId, required UserRole role});

  Future<RoomItem> confirmCompanionOrder({required String roomId});

  Future<RoomItem> rejectCompanionOrder({required String roomId});

  Future<void> inviteCompanion({
    required String roomId,
    required String companionId,
  });

  Future<void> cancelCompanionInvitation({
    required String roomId,
    required String companionId,
  });

  Future<void> dissolveRoom({required String roomId});

  Future<List<RoomMemberItem>> fetchRoomMembers({required String roomId});

  Future<List<InvitationItem>> fetchRoomInvitations({required String roomId});

  Future<List<InvitationItem>> fetchPendingInvitations();

  Future<void> confirmRoomCompleted({required String roomId});

  Future<void> reportByRoom({required String roomId, required String reason});

  Future<List<WalletFlowItem>> fetchWalletFlows();

  Future<void> recharge({required int amount, required String channel});

  Future<void> withdraw({required int amount});

  Future<List<OrderItem>> fetchOrders();

  Future<void> reportByOrder({required String orderId, required String reason});

  // ========== 新增的API方法 ==========

  /// 获取用户余额信息
  Future<UserBalance> fetchUserBalance();

  /// 获取实名认证状态
  Future<IdentityVerification> fetchVerificationStatus();

  /// 提交实名认证
  Future<void> submitVerification({
    required String realName,
    required String idCardNumber,
    required String idFrontUrl,
    required String idBackUrl,
    required String withHandUrl,
    required String smsCode,
  });

  /// 获取提现账户列表
  Future<List<WithdrawAccount>> fetchWithdrawAccounts();

  /// 绑定提现账户
  Future<void> bindWithdrawAccount({
    required String channel,
    required String accountNumber,
    required String accountName,
  });

  /// 提交提现申请
  Future<void> submitWithdraw({required int amount, required String accountId});

  /// 获取积分记录
  Future<List<PointRecord>> fetchPointRecords();

  /// 提交举报（详细版）
  Future<void> submitReport({
    required String targetType,
    required String targetId,
    required String reason,
    String? description,
    List<String>? evidenceUrls,
  });

  /// 获取我的举报列表
  Future<List<Report>> fetchMyReports();
}

class MockPlatformApi implements PlatformApi {
  String _token = '';
  String _mockUserId = 'mock-user';
  UserRole _mockRole = UserRole.boss;
  final Map<String, UserRole> _phoneRoles = {};
  final Map<String, String> _phoneDisplayNames = {};
  String _mockPhone = '13800000000';
  String _mockDisplayName = '风暴小刘';
  final List<RoomItem> _rooms = List<RoomItem>.from(mockRooms);
  final List<OrderItem> _orders = List<OrderItem>.from(mockOrders);
  final List<WalletFlowItem> _walletFlows = List<WalletFlowItem>.from(
    mockWalletFlows,
  );
  final Map<String, List<RoomMemberItem>> _roomMembers = {
    for (final room in mockRooms)
      room.id: [
        const RoomMemberItem(
          userId: 'mock-user',
          userName: '当前用户',
          role: 'boss',
          status: '房主',
        ),
      ],
  };
  final Map<String, List<InvitationItem>> _roomInvitations = {};
  final List<CompanionItem> _companions = const [
    CompanionItem(
      id: 'cp_001',
      name: '孤狼Ace',
      rank: '宗师',
      pricePerGame: 260,
      online: true,
      serviceCount: 328,
      rating: 4.9,
      tags: ['突击位', '麦克风清晰'],
    ),
    CompanionItem(
      id: 'cp_002',
      name: '北境狙神',
      rank: '大师',
      pricePerGame: 220,
      online: true,
      serviceCount: 211,
      rating: 4.8,
      tags: ['狙击位', '教学向'],
    ),
    CompanionItem(
      id: 'cp_003',
      name: '阿泽冲分',
      rank: '王者',
      pricePerGame: 300,
      online: false,
      serviceCount: 402,
      rating: 4.95,
      tags: ['高分局', '控图'],
    ),
  ];

  @override
  Future<List<CompanionItem>> fetchCompanions({bool onlineOnly = true}) async {
    if (!onlineOnly) {
      return _companions;
    }
    return _companions.where((item) => item.online).toList();
  }

  int _roomSeq = 13017;
  int _orderSeq = 20260401002;

  @override
  Future<AuthSession> loginWithSms({
    required String phone,
    required String smsCode,
  }) async {
    _token = 'mock-token-$phone';
    _mockUserId = 'u_$phone';
    _mockPhone = phone;
    final suffix = phone.length >= 4
        ? phone.substring(phone.length - 4)
        : phone;
    _mockDisplayName = _phoneDisplayNames[phone] ?? '玩家$suffix';
    _mockRole = _phoneRoles[phone] ?? UserRole.boss;
    return AuthSession(
      accessToken: _token,
      refreshToken: 'mock-refresh-token',
      userId: _mockUserId,
      role: _mockRole,
      verificationStatus: _verification.status.name,
    );
  }

  @override
  Future<AuthSession> registerWithSms({
    required String phone,
    required String smsCode,
    required UserRole role,
    String? displayName,
  }) async {
    _phoneRoles[phone] = role;
    final resolvedDisplayName = (displayName ?? '').trim();
    final suffix = phone.length >= 4
        ? phone.substring(phone.length - 4)
        : phone;
    _phoneDisplayNames[phone] = resolvedDisplayName.isEmpty
        ? '玩家$suffix'
        : resolvedDisplayName;
    _mockRole = role;
    return loginWithSms(phone: phone, smsCode: smsCode);
  }

  @override
  Future<void> logout() async {
    _token = '';
  }

  @override
  Future<void> setAuthToken(String token) async {
    _token = token;
  }

  @override
  String get authToken => _token;

  @override
  Future<void> updateUserRole(UserRole role) async {
    _mockRole = role;
    if (_token.isNotEmpty) {
      final phone = _mockUserId.startsWith('u_')
          ? _mockUserId.substring(2)
          : '';
      if (phone.isNotEmpty) {
        _phoneRoles[phone] = role;
      }
    }
  }

  @override
  Future<UserProfile> fetchUserProfile() async {
    return UserProfile(
      userId: _mockUserId,
      displayName: _mockDisplayName,
      phone: _mockPhone,
    );
  }

  @override
  Future<UserProfile> updateUserProfile({
    required String displayName,
    required String phone,
    String? password,
  }) async {
    final normalizedPhone = phone.trim();
    if (normalizedPhone.isEmpty) {
      throw Exception('手机号不能为空');
    }

    final oldPhone = _mockPhone;
    _mockPhone = normalizedPhone;
    _mockDisplayName = displayName.trim().isEmpty
        ? _mockDisplayName
        : displayName.trim();
    _phoneDisplayNames[_mockPhone] = _mockDisplayName;

    if (oldPhone != _mockPhone) {
      final role = _phoneRoles.remove(oldPhone);
      if (role != null) {
        _phoneRoles[_mockPhone] = role;
      }
    }

    _mockUserId = 'u_$_mockPhone';
    if (_token.isNotEmpty) {
      _token = 'mock-token-$_mockPhone';
    }

    return UserProfile(
      userId: _mockUserId,
      displayName: _mockDisplayName,
      phone: _mockPhone,
    );
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
    _roomSeq += 1;
    final room = RoomItem(
      id: 'R-$_roomSeq',
      title: roomTitle,
      owner: '当前用户',
      price: unitPrice,
      status: '待加入',
      seatsLeft: seats,
      contribution: contribution,
      note: note,
      commission: ((100 - serviceFeeRate) * unitPrice ~/ 100),
      tags: const ['新建'],
    );
    _rooms.insert(0, room);
    _roomMembers[room.id] = [
      RoomMemberItem(
        userId: _mockUserId,
        userName: '当前用户',
        role: creatorRole.name,
        status: '房主',
      ),
    ];
    _roomInvitations[room.id] = [];
    return room;
  }

  @override
  Future<List<RoomItem>> fetchJoinedRooms() async {
    final joinedRoomIds = _roomMembers.entries
        .where(
          (entry) => entry.value.any(
            (member) =>
                member.userId == _mockUserId &&
                (member.status == '房主' ||
                    member.status == '已加入' ||
                    member.status == '已接单'),
          ),
        )
        .map((entry) => entry.key)
        .toSet();
    return _rooms.where((room) => joinedRoomIds.contains(room.id)).toList();
  }

  @override
  Future<List<OrderItem>> fetchOrders() async {
    return _orders;
  }

  @override
  Future<List<RoomMemberItem>> fetchRoomMembers({
    required String roomId,
  }) async {
    return List<RoomMemberItem>.from(_roomMembers[roomId] ?? const []);
  }

  @override
  Future<List<InvitationItem>> fetchRoomInvitations({
    required String roomId,
  }) async {
    final now = DateTime.now();
    final current = List<InvitationItem>.from(
      _roomInvitations[roomId] ?? const [],
    );
    var changed = false;
    final next = <InvitationItem>[];
    final members = List<RoomMemberItem>.from(_roomMembers[roomId] ?? const []);

    for (final item in current) {
      if (item.isPending && item.expiresAt != null && now.isAfter(item.expiresAt!)) {
        changed = true;
        members.removeWhere(
          (member) =>
              member.userId == item.inviteeUserId && member.status == '待确认接单',
        );
        next.add(
          InvitationItem(
            inviteId: item.inviteId,
            roomId: item.roomId,
            roomTitle: item.roomTitle,
            inviterUserId: item.inviterUserId,
            inviterUserName: item.inviterUserName,
            inviteeUserId: item.inviteeUserId,
            inviteeUserName: item.inviteeUserName,
            status: 'expired',
            createdAt: item.createdAt,
            expiresAt: item.expiresAt,
            decidedAt: now,
            rejectReason: item.rejectReason,
          ),
        );
      } else {
        next.add(item);
      }
    }

    if (changed) {
      _roomMembers[roomId] = members;
      _roomInvitations[roomId] = next;
    }

    next.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return next;
  }

  @override
  Future<List<InvitationItem>> fetchPendingInvitations() async {
    final result = <InvitationItem>[];
    for (final roomId in _roomInvitations.keys) {
      final list = await fetchRoomInvitations(roomId: roomId);
      result.addAll(
        list.where(
          (item) => item.isPending && item.inviteeUserId == _mockUserId,
        ),
      );
    }
    result.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return result;
  }

  @override
  Future<List<RoomItem>> fetchRooms({
    required UserRole role,
    String keyword = '',
    String filter = '全部',
  }) async {
    if (role == UserRole.companion) {
      for (final roomId in _roomInvitations.keys) {
        await fetchRoomInvitations(roomId: roomId);
      }
    }

    return _rooms.where((room) {
      final hitKeyword =
          keyword.isEmpty ||
          room.title.contains(keyword) ||
          room.owner.contains(keyword) ||
          room.tags.join(' ').contains(keyword);
      final hitFilter =
          filter == '全部' || room.status == filter || room.tags.contains(filter);

      var hitRole = true;
      if (role == UserRole.companion) {
        final members = _roomMembers[room.id] ?? const <RoomMemberItem>[];
        hitRole = members.any(
          (member) =>
              member.userId == _mockUserId &&
              (member.status == '房主' ||
                  member.status == '待确认接单' ||
                  member.status == '已加入' ||
                  member.status == '已接单'),
        );
      } else if (role == UserRole.boss) {
        final members = _roomMembers[room.id] ?? const <RoomMemberItem>[];
        final owner = members.firstWhere(
          (member) => member.status == '房主',
          orElse: () => const RoomMemberItem(
            userId: '',
            userName: '',
            role: '',
            status: '',
          ),
        );
        if (owner.userId.isNotEmpty && owner.role == UserRole.boss.name) {
          hitRole = owner.userId == _mockUserId;
        }
      }

      return hitKeyword && hitFilter && hitRole;
    }).toList();
  }

  @override
  Future<List<WalletFlowItem>> fetchWalletFlows() async {
    return _walletFlows;
  }

  @override
  Future<RoomItem> joinRoom({
    required String roomId,
    required UserRole role,
  }) async {
    final index = _rooms.indexWhere((room) => room.id == roomId);
    if (index < 0) {
      throw Exception('房间不存在');
    }

    final currentRoom = _rooms[index];
    if (currentRoom.seatsLeft <= 0) {
      throw Exception('房间已满');
    }

    final members = _roomMembers[roomId] ?? <RoomMemberItem>[];
    if (members.any((member) => member.userId == _mockUserId)) {
      throw Exception('你已在房间内');
    }

    final updatedRoom = RoomItem(
      id: currentRoom.id,
      title: currentRoom.title,
      owner: currentRoom.owner,
      price: currentRoom.price,
      status: currentRoom.seatsLeft - 1 == 0 ? '进行中' : '待加入',
      seatsLeft: currentRoom.seatsLeft - 1,
      contribution: currentRoom.contribution,
      note: currentRoom.note,
      commission: currentRoom.commission,
      tags: currentRoom.tags,
    );
    _rooms[index] = updatedRoom;

    final updatedMembers = List<RoomMemberItem>.from(members)
      ..add(
        RoomMemberItem(
          userId: _mockUserId,
          userName: role == UserRole.boss ? '老板用户' : '陪玩用户',
          role: role.name,
          status: role == UserRole.companion ? '已接单' : '已加入',
        ),
      );
    _roomMembers[roomId] = updatedMembers;

    _orderSeq += 1;
    _orders.insert(
      0,
      OrderItem(
        id: 'O-$_orderSeq',
        partner: role == UserRole.companion ? '陪玩用户' : '老板用户',
        unitPrice: updatedRoom.price,
        ratio: updatedRoom.contribution,
        progress: updatedRoom.status == '进行中' ? '进行中' : '待开始',
        room: updatedRoom.title,
      ),
    );

    return updatedRoom;
  }

  @override
  Future<RoomItem> confirmCompanionOrder({required String roomId}) async {
    final roomIndex = _rooms.indexWhere((room) => room.id == roomId);
    if (roomIndex < 0) {
      throw Exception('房间不存在');
    }

    final room = _rooms[roomIndex];
    final members = List<RoomMemberItem>.from(_roomMembers[roomId] ?? const []);
    final pendingIndex = members.indexWhere(
      (member) =>
          member.userId == _mockUserId &&
          member.role == UserRole.companion.name &&
          member.status == '待确认接单',
    );
    if (pendingIndex < 0) {
      throw Exception('当前房间没有待确认接单记录');
    }

    if (room.seatsLeft <= 0) {
      final invitations = List<InvitationItem>.from(
        _roomInvitations[roomId] ?? const [],
      );
      final inviteIndex = invitations.indexWhere(
        (item) => item.inviteeUserId == _mockUserId && item.isPending,
      );
      if (inviteIndex >= 0) {
        final current = invitations[inviteIndex];
        invitations[inviteIndex] = InvitationItem(
          inviteId: current.inviteId,
          roomId: current.roomId,
          roomTitle: current.roomTitle,
          inviterUserId: current.inviterUserId,
          inviterUserName: current.inviterUserName,
          inviteeUserId: current.inviteeUserId,
          inviteeUserName: current.inviteeUserName,
          status: 'failed',
          createdAt: current.createdAt,
          expiresAt: current.expiresAt,
          decidedAt: DateTime.now(),
          rejectReason: '房间已满',
        );
        _roomInvitations[roomId] = invitations;
      }
      members.removeAt(pendingIndex);
      _roomMembers[roomId] = members;
      throw Exception('房间已满，无法确认接单');
    }

    members[pendingIndex] = RoomMemberItem(
      userId: members[pendingIndex].userId,
      userName: members[pendingIndex].userName,
      role: members[pendingIndex].role,
      status: '已接单',
    );
    _roomMembers[roomId] = members;

    final invitations = List<InvitationItem>.from(
      _roomInvitations[roomId] ?? const [],
    );
    final inviteIndex = invitations.indexWhere(
      (item) => item.inviteeUserId == _mockUserId && item.isPending,
    );
    if (inviteIndex >= 0) {
      final current = invitations[inviteIndex];
      invitations[inviteIndex] = InvitationItem(
        inviteId: current.inviteId,
        roomId: current.roomId,
        roomTitle: current.roomTitle,
        inviterUserId: current.inviterUserId,
        inviterUserName: current.inviterUserName,
        inviteeUserId: current.inviteeUserId,
        inviteeUserName: current.inviteeUserName,
        status: 'accepted',
        createdAt: current.createdAt,
        expiresAt: current.expiresAt,
        decidedAt: DateTime.now(),
        rejectReason: current.rejectReason,
      );
      _roomInvitations[roomId] = invitations;
    }

    final updatedRoom = RoomItem(
      id: room.id,
      title: room.title,
      owner: room.owner,
      price: room.price,
      status: room.seatsLeft - 1 == 0 ? '进行中' : '待加入',
      seatsLeft: room.seatsLeft - 1,
      contribution: room.contribution,
      note: room.note,
      commission: room.commission,
      tags: room.tags,
    );
    _rooms[roomIndex] = updatedRoom;

    _orderSeq += 1;
    _orders.insert(
      0,
      OrderItem(
        id: 'O-$_orderSeq',
        partner: members[pendingIndex].userName,
        unitPrice: updatedRoom.price,
        ratio: updatedRoom.contribution,
        progress: updatedRoom.status == '进行中' ? '进行中' : '待开始',
        room: updatedRoom.title,
      ),
    );

    return updatedRoom;
  }

  @override
  Future<RoomItem> rejectCompanionOrder({required String roomId}) async {
    final roomIndex = _rooms.indexWhere((room) => room.id == roomId);
    if (roomIndex < 0) {
      throw Exception('房间不存在');
    }

    final room = _rooms[roomIndex];
    final members = List<RoomMemberItem>.from(_roomMembers[roomId] ?? const []);
    final pendingIndex = members.indexWhere(
      (member) =>
          member.userId == _mockUserId &&
          member.role == UserRole.companion.name &&
          member.status == '待确认接单',
    );
    if (pendingIndex < 0) {
      throw Exception('当前房间没有待确认接单记录');
    }

    members.removeAt(pendingIndex);
    _roomMembers[roomId] = members;

    final invitations = List<InvitationItem>.from(
      _roomInvitations[roomId] ?? const [],
    );
    final inviteIndex = invitations.indexWhere(
      (item) => item.inviteeUserId == _mockUserId && item.isPending,
    );
    if (inviteIndex >= 0) {
      final current = invitations[inviteIndex];
      invitations[inviteIndex] = InvitationItem(
        inviteId: current.inviteId,
        roomId: current.roomId,
        roomTitle: current.roomTitle,
        inviterUserId: current.inviterUserId,
        inviterUserName: current.inviterUserName,
        inviteeUserId: current.inviteeUserId,
        inviteeUserName: current.inviteeUserName,
        status: 'rejected',
        createdAt: current.createdAt,
        expiresAt: current.expiresAt,
        decidedAt: DateTime.now(),
        rejectReason: current.rejectReason,
      );
      _roomInvitations[roomId] = invitations;
    }

    return room;
  }

  @override
  Future<void> inviteCompanion({
    required String roomId,
    required String companionId,
  }) async {
    final roomIndex = _rooms.indexWhere((room) => room.id == roomId);
    if (roomIndex < 0) {
      throw Exception('房间不存在');
    }

    final room = _rooms[roomIndex];
    if (room.seatsLeft <= 0) {
      throw Exception('房间已满');
    }

    final companion = _companions.firstWhere(
      (item) => item.id == companionId,
      orElse: () => throw Exception('陪玩不存在'),
    );
    if (!companion.online) {
      throw Exception('该陪玩当前不在线');
    }

    final members = _roomMembers[roomId] ?? <RoomMemberItem>[];
    if (members.any((member) => member.userId == companionId)) {
      throw Exception('该陪玩已在房间中');
    }

    _roomMembers[roomId] = [
      ...members,
      RoomMemberItem(
        userId: companion.id,
        userName: companion.name,
        role: 'companion',
        status: '待确认接单',
      ),
    ];

    final invitations = List<InvitationItem>.from(
      _roomInvitations[roomId] ?? const [],
    );
    if (invitations.any(
      (item) => item.inviteeUserId == companion.id && item.isPending,
    )) {
      throw Exception('该陪玩已有待处理邀请');
    }

    final now = DateTime.now();
    invitations.insert(
      0,
      InvitationItem(
        inviteId: 'INV-${now.microsecondsSinceEpoch}',
        roomId: roomId,
        roomTitle: room.title,
        inviterUserId: _mockUserId,
        inviterUserName: _mockDisplayName,
        inviteeUserId: companion.id,
        inviteeUserName: companion.name,
        status: 'pending',
        createdAt: now,
        expiresAt: now.add(const Duration(minutes: 5)),
      ),
    );
    _roomInvitations[roomId] = invitations;
  }

  @override
  Future<void> cancelCompanionInvitation({
    required String roomId,
    required String companionId,
  }) async {
    final roomIndex = _rooms.indexWhere((room) => room.id == roomId);
    if (roomIndex < 0) {
      throw Exception('房间不存在');
    }

    final invitations = List<InvitationItem>.from(
      _roomInvitations[roomId] ?? const [],
    );
    final inviteIndex = invitations.indexWhere(
      (item) => item.inviteeUserId == companionId && item.isPending,
    );
    if (inviteIndex < 0) {
      throw Exception('未找到可取消的待处理邀请');
    }

    final current = invitations[inviteIndex];
    invitations[inviteIndex] = InvitationItem(
      inviteId: current.inviteId,
      roomId: current.roomId,
      roomTitle: current.roomTitle,
      inviterUserId: current.inviterUserId,
      inviterUserName: current.inviterUserName,
      inviteeUserId: current.inviteeUserId,
      inviteeUserName: current.inviteeUserName,
      status: 'cancelled',
      createdAt: current.createdAt,
      expiresAt: current.expiresAt,
      decidedAt: DateTime.now(),
      rejectReason: 'inviter_cancelled',
    );
    _roomInvitations[roomId] = invitations;

    final members = List<RoomMemberItem>.from(_roomMembers[roomId] ?? const []);
    members.removeWhere(
      (member) =>
          member.userId == companionId && member.status == '待确认接单',
    );
    _roomMembers[roomId] = members;
  }

  @override
  Future<void> dissolveRoom({required String roomId}) async {
    final roomIndex = _rooms.indexWhere((room) => room.id == roomId);
    if (roomIndex < 0) {
      throw Exception('房间不存在');
    }

    final room = _rooms[roomIndex];
    final members = List<RoomMemberItem>.from(_roomMembers[roomId] ?? const []);
    final ownerIndex = members.indexWhere((member) => member.status == '房主');
    if (ownerIndex < 0 || members[ownerIndex].userId != _mockUserId) {
      throw Exception('仅房主可解散房间');
    }

    _rooms.removeAt(roomIndex);
    _roomMembers.remove(roomId);
    _roomInvitations.remove(roomId);

    for (var i = 0; i < _orders.length; i++) {
      final order = _orders[i];
      if (order.room == room.title && order.progress != '已结算给陪玩') {
        _orders[i] = OrderItem(
          id: order.id,
          partner: order.partner,
          unitPrice: order.unitPrice,
          ratio: order.ratio,
          progress: '已解散',
          room: order.room,
        );
      }
    }
  }

  @override
  Future<void> confirmRoomCompleted({required String roomId}) async {
    final roomIndex = _rooms.indexWhere((room) => room.id == roomId);
    if (roomIndex < 0) {
      throw Exception('房间不存在');
    }

    final room = _rooms[roomIndex];
    _rooms[roomIndex] = RoomItem(
      id: room.id,
      title: room.title,
      owner: room.owner,
      price: room.price,
      status: '已完成',
      seatsLeft: room.seatsLeft,
      contribution: room.contribution,
      note: room.note,
      commission: room.commission,
      tags: room.tags,
    );

    for (var i = 0; i < _orders.length; i++) {
      final order = _orders[i];
      if (order.room == room.title && order.progress != '已完成待结算') {
        _orders[i] = OrderItem(
          id: order.id,
          partner: order.partner,
          unitPrice: order.unitPrice,
          ratio: order.ratio,
          progress: '已结算给陪玩',
          room: order.room,
        );
      }
    }

    _walletFlows.insert(
      0,
      const WalletFlowItem(
        type: '陪玩结算',
        amount: '-240',
        status: '成功',
        time: '04-02 20:18',
      ),
    );
  }

  @override
  Future<void> recharge({required int amount, required String channel}) async {
    // 模拟充值逻辑
    _userBalance = UserBalance(
      totalBalance: _userBalance.totalBalance + amount,
      availableBalance: _userBalance.availableBalance + amount,
      frozenBalance: _userBalance.frozenBalance,
      points: _userBalance.points + (amount ~/ 10), // 每10元1积分
      level: _calculateLevel(_userBalance.points + (amount ~/ 10)),
      updatedAt: DateTime.now(),
    );

    _walletFlows.insert(
      0,
      WalletFlowItem(
        type: '充值',
        amount: '+$amount',
        status: '成功',
        time: _formatTime(DateTime.now()),
      ),
    );
  }

  @override
  Future<void> reportByOrder({
    required String orderId,
    required String reason,
  }) async {}

  @override
  Future<void> reportByRoom({
    required String roomId,
    required String reason,
  }) async {}

  @override
  Future<void> withdraw({required int amount}) async {
    if (amount > _userBalance.availableBalance) {
      throw Exception('可用余额不足');
    }

    _userBalance = UserBalance(
      totalBalance: _userBalance.totalBalance - amount,
      availableBalance: _userBalance.availableBalance - amount,
      frozenBalance: _userBalance.frozenBalance,
      points: _userBalance.points,
      level: _userBalance.level,
      updatedAt: DateTime.now(),
    );

    _walletFlows.insert(
      0,
      WalletFlowItem(
        type: '提现',
        amount: '-$amount',
        status: '处理中',
        time: _formatTime(DateTime.now()),
      ),
    );
  }

  // ========== 新增API实现 ==========

  // 模拟用户余额
  UserBalance _userBalance = const UserBalance(
    totalBalance: 12560,
    availableBalance: 10560,
    frozenBalance: 2000,
    points: 2340,
    level: 2,
  );

  // 模拟认证状态
  IdentityVerification _verification = const IdentityVerification(
    status: VerificationStatus.notStarted,
  );

  // 模拟提现账户
  final List<WithdrawAccount> _withdrawAccounts = [];

  // 模拟举报列表
  final List<Report> _reports = [];

  // 模拟积分记录
  final List<PointRecord> _pointRecords = [
    PointRecord(
      recordId: 'pr_001',
      points: 100,
      reason: 'consumption',
      relatedOrderId: 'O-20260401001',
      createdAt: DateTime.now().subtract(const Duration(days: 1)),
    ),
    PointRecord(
      recordId: 'pr_002',
      points: 50,
      reason: 'activity',
      createdAt: DateTime.now().subtract(const Duration(days: 3)),
    ),
  ];

  @override
  Future<UserBalance> fetchUserBalance() async {
    return _userBalance;
  }

  @override
  Future<IdentityVerification> fetchVerificationStatus() async {
    return _verification;
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
    // 模拟提交认证
    await Future.delayed(const Duration(seconds: 1));
    _verification = IdentityVerification(
      userId: _mockUserId,
      status: VerificationStatus.pending,
      realName: realName,
      idCardNumber: idCardNumber,
      idFrontUrl: idFrontUrl,
      idBackUrl: idBackUrl,
      withHandUrl: withHandUrl,
      submittedAt: DateTime.now(),
    );
  }

  @override
  Future<List<WithdrawAccount>> fetchWithdrawAccounts() async {
    return _withdrawAccounts;
  }

  @override
  Future<void> bindWithdrawAccount({
    required String channel,
    required String accountNumber,
    required String accountName,
  }) async {
    final account = WithdrawAccount(
      accountId: 'wa_${DateTime.now().millisecondsSinceEpoch}',
      channel: channel,
      accountNumber: accountNumber,
      accountName: accountName,
      isDefault: _withdrawAccounts.isEmpty,
      createdAt: DateTime.now(),
    );
    _withdrawAccounts.add(account);
  }

  @override
  Future<void> submitWithdraw({
    required int amount,
    required String accountId,
  }) async {
    await withdraw(amount: amount);
  }

  @override
  Future<List<PointRecord>> fetchPointRecords() async {
    return _pointRecords;
  }

  @override
  Future<void> submitReport({
    required String targetType,
    required String targetId,
    required String reason,
    String? description,
    List<String>? evidenceUrls,
  }) async {
    final report = Report(
      reportId: 'rp_${DateTime.now().millisecondsSinceEpoch}',
      reporterId: _mockUserId,
      targetType: targetType,
      targetId: targetId,
      reason: reason,
      description: description,
      evidenceUrls: evidenceUrls ?? const [],
      status: 'pending',
      createdAt: DateTime.now(),
    );
    _reports.add(report);
  }

  @override
  Future<List<Report>> fetchMyReports() async {
    return _reports;
  }

  // 工具方法
  String _formatTime(DateTime dateTime) {
    return '${dateTime.month.toString().padLeft(2, '0')}-${dateTime.day.toString().padLeft(2, '0')} '
        '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
  }

  int _calculateLevel(int points) {
    if (points >= 2000) return 3;
    if (points >= 500) return 2;
    return 1;
  }
}
