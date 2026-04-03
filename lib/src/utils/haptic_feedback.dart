import 'package:flutter/services.dart';

/// iOS风格的触觉反馈工具类
class HapticFeedbackUtil {
  /// 轻触反馈 - 用于按钮点击
  static void lightImpact() {
    HapticFeedback.lightImpact();
  }

  /// 中等反馈 - 用于重要操作
  static void mediumImpact() {
    HapticFeedback.mediumImpact();
  }

  /// 重度反馈 - 用于关键确认
  static void heavyImpact() {
    HapticFeedback.heavyImpact();
  }

  /// 选择反馈 - 用于列表选择、开关切换
  static void selectionClick() {
    HapticFeedback.selectionClick();
  }

  /// 成功反馈 - 操作成功时
  static void success() {
    HapticFeedback.mediumImpact();
  }

  /// 错误反馈 - 操作失败时
  static void error() {
    HapticFeedback.heavyImpact();
  }

  /// 警告反馈 - 警告提示时
  static void warning() {
    HapticFeedback.lightImpact();
  }

  /// 通知成功反馈 - iOS通知风格成功反馈
  static void notificationSuccess() {
    HapticFeedback.mediumImpact();
  }

  /// 通知错误反馈 - iOS通知风格错误反馈
  static void notificationError() {
    HapticFeedback.heavyImpact();
  }

  /// 通知警告反馈 - iOS通知风格警告反馈
  static void notificationWarning() {
    HapticFeedback.lightImpact();
  }
}
