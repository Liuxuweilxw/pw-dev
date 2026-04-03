/// 输入校验工具类
class Validators {
  /// 校验手机号（中国大陆）
  static String? validatePhone(String? value) {
    if (value == null || value.isEmpty) {
      return '请输入手机号';
    }
    final phoneRegex = RegExp(r'^1[3-9]\d{9}$');
    if (!phoneRegex.hasMatch(value)) {
      return '请输入正确的手机号';
    }
    return null;
  }

  /// 校验验证码（6位数字）
  static String? validateSmsCode(String? value) {
    if (value == null || value.isEmpty) {
      return '请输入验证码';
    }
    if (value.length != 6 || int.tryParse(value) == null) {
      return '验证码为6位数字';
    }
    return null;
  }

  /// 校验金额
  static String? validateAmount(
    String? value, {
    int minAmount = 1,
    int? maxAmount,
  }) {
    if (value == null || value.isEmpty) {
      return '请输入金额';
    }
    final amount = int.tryParse(value);
    if (amount == null) {
      return '请输入有效金额';
    }
    if (amount < minAmount) {
      return '最低金额为 $minAmount 元';
    }
    if (maxAmount != null && amount > maxAmount) {
      return '最高金额为 $maxAmount 元';
    }
    return null;
  }

  /// 校验房间名称
  static String? validateRoomTitle(String? value) {
    if (value == null || value.trim().isEmpty) {
      return '请输入房间名称';
    }
    if (value.trim().length < 2) {
      return '房间名称至少2个字符';
    }
    if (value.trim().length > 20) {
      return '房间名称最多20个字符';
    }
    return null;
  }

  /// 校验身份证号
  static String? validateIdCard(String? value) {
    if (value == null || value.isEmpty) {
      return '请输入身份证号';
    }
    // 18位身份证号校验
    final idCardRegex = RegExp(
      r'^[1-9]\d{5}(19|20)\d{2}(0[1-9]|1[0-2])(0[1-9]|[12]\d|3[01])\d{3}[\dXx]$',
    );
    if (!idCardRegex.hasMatch(value)) {
      return '请输入正确的身份证号';
    }
    return null;
  }

  /// 校验姓名
  static String? validateRealName(String? value) {
    if (value == null || value.trim().isEmpty) {
      return '请输入姓名';
    }
    if (value.trim().length < 2) {
      return '姓名至少2个字符';
    }
    if (value.trim().length > 20) {
      return '姓名最多20个字符';
    }
    // 只允许中文和少数民族点号
    final nameRegex = RegExp(r'^[\u4e00-\u9fa5·]+$');
    if (!nameRegex.hasMatch(value.trim())) {
      return '姓名只能包含中文';
    }
    return null;
  }

  /// 校验提现金额
  static String? validateWithdrawAmount(String? value, int availableBalance) {
    final baseError = validateAmount(value, minAmount: 100);
    if (baseError != null) {
      return baseError;
    }
    final amount = int.parse(value!);
    if (amount > availableBalance) {
      return '可用余额不足';
    }
    return null;
  }
}
