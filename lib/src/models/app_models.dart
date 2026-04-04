enum UserRole { boss, companion }

class AuthSession {
  const AuthSession({
    required this.accessToken,
    required this.refreshToken,
    required this.userId,
    required this.role,
  });

  final String accessToken;
  final String refreshToken;
  final String userId;
  final UserRole role;

  factory AuthSession.fromJson(Map<String, dynamic> json) {
    return AuthSession(
      accessToken: _requiredString(json, 'access_token'),
      refreshToken: _requiredString(json, 'refresh_token'),
      userId: _requiredString(json, 'user_id'),
      role: _parseUserRole(json['user_role']),
    );
  }
}

class UserProfile {
  const UserProfile({
    required this.userId,
    required this.displayName,
    required this.phone,
  });

  final String userId;
  final String displayName;
  final String phone;

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      userId: _requiredString(json, 'user_id'),
      displayName: _requiredString(json, 'display_name'),
      phone: _requiredString(json, 'phone'),
    );
  }

  Map<String, dynamic> toJson() {
    return {'user_id': userId, 'display_name': displayName, 'phone': phone};
  }
}

class RoomItem {
  const RoomItem({
    required this.id,
    required this.title,
    required this.owner,
    required this.price,
    required this.status,
    required this.seatsLeft,
    required this.contribution,
    required this.note,
    required this.commission,
    required this.tags,
  });

  final String id;
  final String title;
  final String owner;
  final int price;
  final String status;
  final int seatsLeft;
  final String contribution;
  final String note;
  final int commission;
  final List<String> tags;

  factory RoomItem.fromJson(Map<String, dynamic> json) {
    return RoomItem(
      id: _requiredString(json, 'room_id'),
      title: _requiredString(json, 'title'),
      owner: _requiredString(json, 'owner_name'),
      price: _requiredInt(json, 'unit_price'),
      status: _requiredString(json, 'status'),
      seatsLeft: _requiredInt(json, 'seats_left'),
      contribution: _requiredString(json, 'contribution_ratio'),
      note: _stringOrEmpty(json, 'note'),
      commission: _requiredInt(json, 'commission'),
      tags: _stringList(json, 'tags'),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'owner': owner,
      'price': price,
      'status': status,
      'seatsLeft': seatsLeft,
      'contribution': contribution,
      'note': note,
      'commission': commission,
      'tags': tags,
    };
  }
}

class WalletFlowItem {
  const WalletFlowItem({
    required this.type,
    required this.amount,
    required this.status,
    required this.time,
  });

  final String type;
  final String amount;
  final String status;
  final String time;

  factory WalletFlowItem.fromJson(Map<String, dynamic> json) {
    return WalletFlowItem(
      type: _requiredString(json, 'type'),
      amount: _requiredString(json, 'amount'),
      status: _requiredString(json, 'status'),
      time: _requiredString(json, 'created_at'),
    );
  }
}

class OrderItem {
  const OrderItem({
    required this.id,
    required this.partner,
    required this.unitPrice,
    required this.ratio,
    required this.progress,
    required this.room,
  });

  final String id;
  final String partner;
  final int unitPrice;
  final String ratio;
  final String progress;
  final String room;

  factory OrderItem.fromJson(Map<String, dynamic> json) {
    return OrderItem(
      id: _requiredString(json, 'order_id'),
      partner: _requiredString(json, 'partner_name'),
      unitPrice: _requiredInt(json, 'unit_price'),
      ratio: _requiredString(json, 'contribution_ratio'),
      progress: _requiredString(json, 'status'),
      room: _requiredString(json, 'room_title'),
    );
  }
}

class RoomMemberItem {
  const RoomMemberItem({
    required this.userId,
    required this.userName,
    required this.role,
    required this.status,
  });

  final String userId;
  final String userName;
  final String role;
  final String status;

  factory RoomMemberItem.fromJson(Map<String, dynamic> json) {
    return RoomMemberItem(
      userId: _requiredString(json, 'user_id'),
      userName: _requiredString(json, 'user_name'),
      role: _requiredString(json, 'role'),
      status: _requiredString(json, 'status'),
    );
  }
}

class CompanionItem {
  const CompanionItem({
    required this.id,
    required this.name,
    required this.rank,
    required this.pricePerGame,
    required this.online,
    required this.serviceCount,
    required this.rating,
    required this.tags,
  });

  final String id;
  final String name;
  final String rank;
  final int pricePerGame;
  final bool online;
  final int serviceCount;
  final double rating;
  final List<String> tags;

  factory CompanionItem.fromJson(Map<String, dynamic> json) {
    return CompanionItem(
      id: _requiredString(json, 'companion_id'),
      name: _requiredString(json, 'name'),
      rank: _requiredString(json, 'rank'),
      pricePerGame: _requiredInt(json, 'price_per_game'),
      online: _requiredBool(json, 'online'),
      serviceCount: _requiredInt(json, 'service_count'),
      rating: _requiredDouble(json, 'rating'),
      tags: _stringList(json, 'tags'),
    );
  }
}

String _requiredString(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value == null) {
    throw FormatException('Missing required field: $key');
  }
  final text = value.toString();
  if (text.isEmpty) {
    throw FormatException('Empty required field: $key');
  }
  return text;
}

String _stringOrEmpty(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value == null) {
    return '';
  }
  return value.toString();
}

int _requiredInt(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value == null) {
    throw FormatException('Missing required field: $key');
  }
  if (value is int) {
    return value;
  }
  if (value is num) {
    return value.toInt();
  }
  final parsed = int.tryParse(value.toString());
  if (parsed == null) {
    throw FormatException('Invalid integer field: $key');
  }
  return parsed;
}

List<String> _stringList(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value == null) {
    return const [];
  }
  if (value is! List) {
    throw FormatException('Invalid list field: $key');
  }
  return value.map((e) => e.toString()).toList();
}

UserRole _parseUserRole(dynamic value) {
  final text = value?.toString().trim();
  if (text == 'companion') {
    return UserRole.companion;
  }
  return UserRole.boss;
}

bool _requiredBool(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is bool) {
    return value;
  }
  if (value is num) {
    return value != 0;
  }
  if (value is String) {
    if (value.toLowerCase() == 'true') {
      return true;
    }
    if (value.toLowerCase() == 'false') {
      return false;
    }
  }
  throw FormatException('Invalid bool field: $key');
}

double _requiredDouble(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value == null) {
    throw FormatException('Missing required field: $key');
  }
  if (value is double) {
    return value;
  }
  if (value is num) {
    return value.toDouble();
  }
  final parsed = double.tryParse(value.toString());
  if (parsed == null) {
    throw FormatException('Invalid double field: $key');
  }
  return parsed;
}
