import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'haptic_feedback.dart';

/// 权限类型枚举
enum PermissionType {
  camera('相机', Icons.camera_alt_rounded, '用于拍摄证件照片、上传举报证据'),
  photos('相册', Icons.photo_library_rounded, '用于选择证件照片、上传头像'),
  microphone('麦克风', Icons.mic_rounded, '用于语音通话、语音消息'),
  notifications('通知', Icons.notifications_rounded, '用于订单提醒、消息通知'),
  location('位置', Icons.location_on_rounded, '用于附近陪玩推荐');

  const PermissionType(this.label, this.icon, this.description);
  final String label;
  final IconData icon;
  final String description;
}

/// 权限状态
enum PermissionStatus {
  granted,
  denied,
  permanentlyDenied,
  notDetermined,
}

/// 权限请求工具类
/// 遵循iOS人机界面指南：在需要时请求权限，并清晰说明用途
class PermissionUtil {
  /// 显示权限请求对话框（iOS风格）
  /// 在实际请求系统权限前先展示说明
  static Future<bool> requestPermissionWithExplanation(
    BuildContext context,
    PermissionType permission,
  ) async {
    HapticFeedbackUtil.lightImpact();

    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _PermissionRequestSheet(permission: permission),
    );

    return result ?? false;
  }

  /// 显示权限被拒绝后的引导对话框
  static Future<void> showPermissionDeniedDialog(
    BuildContext context,
    PermissionType permission,
  ) async {
    HapticFeedbackUtil.warning();

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        icon: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.orange.shade50,
            shape: BoxShape.circle,
          ),
          child: Icon(
            permission.icon,
            color: Colors.orange.shade700,
            size: 32,
          ),
        ),
        title: Text('需要${permission.label}权限'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              permission.description,
              style: const TextStyle(fontSize: 14),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.settings_rounded,
                    size: 20,
                    color: Colors.grey.shade600,
                  ),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      '请前往系统设置开启权限',
                      style: TextStyle(fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('稍后再说'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              // TODO: 实际项目中使用 app_settings 包打开设置
              // AppSettings.openAppSettings();
            },
            child: const Text('前往设置'),
          ),
        ],
      ),
    );
  }

  /// 检查多个权限状态
  static Future<Map<PermissionType, PermissionStatus>> checkPermissions(
    List<PermissionType> permissions,
  ) async {
    // TODO: 实际项目中使用 permission_handler 包
    // 这里返回模拟数据
    return {
      for (var p in permissions) p: PermissionStatus.notDetermined,
    };
  }
}

/// 权限请求底部弹窗
class _PermissionRequestSheet extends StatelessWidget {
  const _PermissionRequestSheet({required this.permission});

  final PermissionType permission;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 拖动条
              Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 24),
              // 图标
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Theme.of(context).primaryColor.withAlpha(26),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  permission.icon,
                  size: 48,
                  color: Theme.of(context).primaryColor,
                ),
              ),
              const SizedBox(height: 20),
              // 标题
              Text(
                '请求${permission.label}权限',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              // 描述
              Text(
                permission.description,
                style: TextStyle(
                  fontSize: 15,
                  color: Colors.grey.shade700,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              // 隐私说明
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.shield_rounded,
                      color: Colors.green.shade600,
                      size: 24,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            '隐私保护',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '您的数据安全是我们的首要任务，所有信息均加密存储',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              // 按钮
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        HapticFeedbackUtil.lightImpact();
                        Navigator.pop(context, false);
                      },
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text('暂不允许'),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    flex: 2,
                    child: FilledButton(
                      onPressed: () {
                        HapticFeedbackUtil.mediumImpact();
                        Navigator.pop(context, true);
                        // TODO: 实际项目中请求系统权限
                      },
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text('允许访问'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 隐私政策与用户协议对话框
class PrivacyAgreementDialog extends StatefulWidget {
  const PrivacyAgreementDialog({super.key});

  @override
  State<PrivacyAgreementDialog> createState() => _PrivacyAgreementDialogState();
}

class _PrivacyAgreementDialogState extends State<PrivacyAgreementDialog> {
  bool _agreed = false;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      title: const Text('服务协议与隐私政策'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '欢迎使用三角洲陪玩平台！',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            Text(
              '在使用我们的服务前，请仔细阅读并同意以下协议：',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade700,
              ),
            ),
            const SizedBox(height: 16),
            _buildAgreementItem(
              '《用户服务协议》',
              '规定您使用本平台服务的权利和义务',
              onTap: () {
                // TODO: 打开用户协议页面
              },
            ),
            const SizedBox(height: 8),
            _buildAgreementItem(
              '《隐私政策》',
              '说明我们如何收集、使用和保护您的个人信息',
              onTap: () {
                // TODO: 打开隐私政策页面
              },
            ),
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 8),
            _buildInfoRow(Icons.verified_user_rounded, '实名认证信息仅用于身份核验'),
            const SizedBox(height: 8),
            _buildInfoRow(Icons.lock_rounded, '支付信息采用银行级加密'),
            const SizedBox(height: 8),
            _buildInfoRow(Icons.delete_outline_rounded, '您可随时申请删除个人数据'),
            const SizedBox(height: 16),
            GestureDetector(
              onTap: () {
                HapticFeedbackUtil.selectionClick();
                setState(() => _agreed = !_agreed);
              },
              child: Row(
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(4),
                      color: _agreed
                          ? Theme.of(context).primaryColor
                          : Colors.transparent,
                      border: Border.all(
                        color: _agreed
                            ? Theme.of(context).primaryColor
                            : Colors.grey.shade400,
                        width: 2,
                      ),
                    ),
                    child: _agreed
                        ? const Icon(Icons.check, size: 16, color: Colors.white)
                        : null,
                  ),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      '我已阅读并同意上述协议',
                      style: TextStyle(fontSize: 14),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('不同意'),
        ),
        FilledButton(
          onPressed: _agreed
              ? () {
                  HapticFeedbackUtil.mediumImpact();
                  Navigator.pop(context, true);
                }
              : null,
          child: const Text('同意并继续'),
        ),
      ],
    );
  }

  Widget _buildAgreementItem(
    String title,
    String subtitle, {
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.grey.shade50,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(
              Icons.description_outlined,
              color: Theme.of(context).primaryColor,
              size: 24,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Theme.of(context).primaryColor,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              color: Colors.grey.shade400,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 18, color: Colors.green.shade600),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey.shade700,
            ),
          ),
        ),
      ],
    );
  }
}
