/// 实名认证状态枚举
enum VerificationStatus {
  notStarted, // 未开始
  pending, // 审核中
  approved, // 已通过
  rejected, // 已拒绝
}

/// 实名认证信息模型
class IdentityVerification {
  final String? userId;
  final VerificationStatus status;
  final String? realName;
  final String? idCardNumber;
  final String? idFrontUrl;
  final String? idBackUrl;
  final String? withHandUrl;
  final String? rejectReason;
  final DateTime? submittedAt;
  final DateTime? verifiedAt;

  const IdentityVerification({
    this.userId,
    this.status = VerificationStatus.notStarted,
    this.realName,
    this.idCardNumber,
    this.idFrontUrl,
    this.idBackUrl,
    this.withHandUrl,
    this.rejectReason,
    this.submittedAt,
    this.verifiedAt,
  });

  bool get isVerified => status == VerificationStatus.approved;
  bool get isPending => status == VerificationStatus.pending;
  bool get isRejected => status == VerificationStatus.rejected;
  bool get needsVerification =>
      status == VerificationStatus.notStarted ||
      status == VerificationStatus.rejected;

  factory IdentityVerification.fromJson(Map<String, dynamic> json) {
    return IdentityVerification(
      userId: json['user_id'] as String?,
      status: _parseStatus(json['status']),
      realName: json['real_name'] as String?,
      idCardNumber: json['id_card_number'] as String?,
      idFrontUrl: json['id_front_url'] as String?,
      idBackUrl: json['id_back_url'] as String?,
      withHandUrl: json['with_hand_url'] as String?,
      rejectReason: json['reject_reason'] as String?,
      submittedAt: json['submitted_at'] != null
          ? DateTime.tryParse(json['submitted_at'] as String)
          : null,
      verifiedAt: json['verified_at'] != null
          ? DateTime.tryParse(json['verified_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'user_id': userId,
      'status': status.name,
      'real_name': realName,
      'id_card_number': idCardNumber,
      'id_front_url': idFrontUrl,
      'id_back_url': idBackUrl,
      'with_hand_url': withHandUrl,
      'reject_reason': rejectReason,
      'submitted_at': submittedAt?.toIso8601String(),
      'verified_at': verifiedAt?.toIso8601String(),
    };
  }

  IdentityVerification copyWith({
    String? userId,
    VerificationStatus? status,
    String? realName,
    String? idCardNumber,
    String? idFrontUrl,
    String? idBackUrl,
    String? withHandUrl,
    String? rejectReason,
    DateTime? submittedAt,
    DateTime? verifiedAt,
  }) {
    return IdentityVerification(
      userId: userId ?? this.userId,
      status: status ?? this.status,
      realName: realName ?? this.realName,
      idCardNumber: idCardNumber ?? this.idCardNumber,
      idFrontUrl: idFrontUrl ?? this.idFrontUrl,
      idBackUrl: idBackUrl ?? this.idBackUrl,
      withHandUrl: withHandUrl ?? this.withHandUrl,
      rejectReason: rejectReason ?? this.rejectReason,
      submittedAt: submittedAt ?? this.submittedAt,
      verifiedAt: verifiedAt ?? this.verifiedAt,
    );
  }

  static VerificationStatus _parseStatus(dynamic value) {
    final statusStr = value?.toString().toLowerCase();
    switch (statusStr) {
      case 'pending':
        return VerificationStatus.pending;
      case 'approved':
        return VerificationStatus.approved;
      case 'rejected':
        return VerificationStatus.rejected;
      default:
        return VerificationStatus.notStarted;
    }
  }
}

/// 用户余额模型
class UserBalance {
  final int totalBalance; // 总余额
  final int availableBalance; // 可用余额
  final int frozenBalance; // 冻结余额
  final int points; // 积分
  final int level; // 等级
  final DateTime? updatedAt;

  const UserBalance({
    this.totalBalance = 0,
    this.availableBalance = 0,
    this.frozenBalance = 0,
    this.points = 0,
    this.level = 1,
    this.updatedAt,
  });

  factory UserBalance.fromJson(Map<String, dynamic> json) {
    return UserBalance(
      totalBalance: json['total_balance'] as int? ?? 0,
      availableBalance: json['available_balance'] as int? ?? 0,
      frozenBalance: json['frozen_balance'] as int? ?? 0,
      points: json['points'] as int? ?? 0,
      level: json['level'] as int? ?? 1,
      updatedAt: json['updated_at'] != null
          ? DateTime.tryParse(json['updated_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'total_balance': totalBalance,
      'available_balance': availableBalance,
      'frozen_balance': frozenBalance,
      'points': points,
      'level': level,
      'updated_at': updatedAt?.toIso8601String(),
    };
  }

  /// 获取下一等级所需积分
  int get nextLevelPoints {
    switch (level) {
      case 1:
        return 500;
      case 2:
        return 2000;
      default:
        return 5000;
    }
  }

  /// 等级进度百分比
  double get levelProgress {
    final required = nextLevelPoints;
    final previousRequired = level == 1 ? 0 : (level == 2 ? 500 : 2000);
    final current = points - previousRequired;
    final range = required - previousRequired;
    return (current / range).clamp(0.0, 1.0);
  }

  /// 等级名称
  String get levelName {
    switch (level) {
      case 1:
        return 'Lv1 新手';
      case 2:
        return 'Lv2 进阶';
      case 3:
        return 'Lv3 高手';
      default:
        return 'Lv$level';
    }
  }
}

/// 提现账户模型
class WithdrawAccount {
  final String accountId;
  final String channel; // 'alipay' | 'wechat'
  final String accountNumber;
  final String accountName;
  final bool isDefault;
  final DateTime? createdAt;

  const WithdrawAccount({
    required this.accountId,
    required this.channel,
    required this.accountNumber,
    required this.accountName,
    this.isDefault = false,
    this.createdAt,
  });

  String get channelName => channel == 'alipay' ? '支付宝' : '微信';

  String get maskedAccountNumber {
    if (accountNumber.length <= 4) return accountNumber;
    final visible = accountNumber.substring(accountNumber.length - 4);
    return '****$visible';
  }

  factory WithdrawAccount.fromJson(Map<String, dynamic> json) {
    return WithdrawAccount(
      accountId: json['account_id'] as String,
      channel: json['channel'] as String,
      accountNumber: json['account_number'] as String,
      accountName: json['account_name'] as String,
      isDefault: json['is_default'] as bool? ?? false,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'account_id': accountId,
      'channel': channel,
      'account_number': accountNumber,
      'account_name': accountName,
      'is_default': isDefault,
      'created_at': createdAt?.toIso8601String(),
    };
  }
}

/// 提现订单模型
class WithdrawOrder {
  final String withdrawId;
  final int amount;
  final int fee;
  final String accountId;
  final String
  status; // 'pending_review' | 'approved' | 'transferred' | 'rejected'
  final String? rejectReason;
  final DateTime createdAt;
  final DateTime? completedAt;

  const WithdrawOrder({
    required this.withdrawId,
    required this.amount,
    this.fee = 0,
    required this.accountId,
    required this.status,
    this.rejectReason,
    required this.createdAt,
    this.completedAt,
  });

  int get actualAmount => amount - fee;

  String get statusText {
    switch (status) {
      case 'pending_review':
        return '审核中';
      case 'approved':
        return '审核通过';
      case 'transferred':
        return '已到账';
      case 'rejected':
        return '已拒绝';
      default:
        return status;
    }
  }

  factory WithdrawOrder.fromJson(Map<String, dynamic> json) {
    return WithdrawOrder(
      withdrawId: json['withdraw_id'] as String,
      amount: json['amount'] as int,
      fee: json['fee'] as int? ?? 0,
      accountId: json['account_id'] as String,
      status: json['status'] as String,
      rejectReason: json['reject_reason'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      completedAt: json['completed_at'] != null
          ? DateTime.tryParse(json['completed_at'] as String)
          : null,
    );
  }
}

/// 举报模型
class Report {
  final String reportId;
  final String reporterId;
  final String targetType; // 'room' | 'order' | 'user'
  final String targetId;
  final String reason;
  final String? description;
  final List<String> evidenceUrls;
  final String status; // 'pending' | 'under_review' | 'approved' | 'rejected'
  final String? adminNotes;
  final DateTime createdAt;
  final DateTime? resolvedAt;

  const Report({
    required this.reportId,
    required this.reporterId,
    required this.targetType,
    required this.targetId,
    required this.reason,
    this.description,
    this.evidenceUrls = const [],
    required this.status,
    this.adminNotes,
    required this.createdAt,
    this.resolvedAt,
  });

  String get statusText {
    switch (status) {
      case 'pending':
        return '待审核';
      case 'under_review':
        return '审核中';
      case 'approved':
        return '举报成功';
      case 'rejected':
        return '举报驳回';
      default:
        return status;
    }
  }

  factory Report.fromJson(Map<String, dynamic> json) {
    return Report(
      reportId: json['report_id'] as String,
      reporterId: json['reporter_id'] as String,
      targetType: json['target_type'] as String,
      targetId: json['target_id'] as String,
      reason: json['reason'] as String,
      description: json['description'] as String?,
      evidenceUrls:
          (json['evidence_urls'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
      status: json['status'] as String,
      adminNotes: json['admin_notes'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      resolvedAt: json['resolved_at'] != null
          ? DateTime.tryParse(json['resolved_at'] as String)
          : null,
    );
  }
}

/// 积分记录模型
class PointRecord {
  final String recordId;
  final int points;
  final String reason; // 'consumption' | 'activity' | 'bonus' | 'redemption'
  final String? relatedOrderId;
  final DateTime createdAt;

  const PointRecord({
    required this.recordId,
    required this.points,
    required this.reason,
    this.relatedOrderId,
    required this.createdAt,
  });

  String get reasonText {
    switch (reason) {
      case 'consumption':
        return '消费获得';
      case 'activity':
        return '活动奖励';
      case 'bonus':
        return '系统赠送';
      case 'redemption':
        return '积分兑换';
      default:
        return reason;
    }
  }

  bool get isPositive => points > 0;

  factory PointRecord.fromJson(Map<String, dynamic> json) {
    return PointRecord(
      recordId: json['record_id'] as String,
      points: json['points'] as int,
      reason: json['reason'] as String,
      relatedOrderId: json['related_order_id'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}
