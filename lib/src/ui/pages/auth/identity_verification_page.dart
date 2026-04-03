import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';

import '../../../models/business_models.dart';
import '../../../services/platform_api.dart';
import '../../../utils/haptic_feedback.dart';
import '../../../utils/validators.dart';

/// 实名认证页面 - 符合iOS Human Interface Guidelines
class IdentityVerificationPage extends StatefulWidget {
  const IdentityVerificationPage({
    super.key,
    required this.api,
    this.initialVerification,
    this.onVerificationComplete,
  });

  final PlatformApi api;
  final IdentityVerification? initialVerification;

  final ValueChanged<IdentityVerification>? onVerificationComplete;

  @override
  State<IdentityVerificationPage> createState() =>
      _IdentityVerificationPageState();
}

class _IdentityVerificationPageState extends State<IdentityVerificationPage> {
  int _currentStep = 0;
  bool _isSubmitting = false;
  VerificationStatus _currentStatus = VerificationStatus.notStarted;

  // 表单数据
  final _formKey = GlobalKey<FormState>();
  final _realNameController = TextEditingController();
  final _idCardController = TextEditingController();
  final _smsCodeController = TextEditingController();

  // 图片数据 (模拟，实际需要 image_picker)
  String? _idFrontImage;
  String? _idBackImage;
  String? _withHandImage;

  // 验证码倒计时
  int _smsCountdown = 0;
  Timer? _smsTimer;

  @override
  void initState() {
    super.initState();
    _currentStatus =
        widget.initialVerification?.status ?? VerificationStatus.notStarted;
  }

  @override
  void dispose() {
    _realNameController.dispose();
    _idCardController.dispose();
    _smsCodeController.dispose();
    _smsTimer?.cancel();
    super.dispose();
  }

  Future<void> _pickIdFrontImage() async {
    HapticFeedbackUtil.lightImpact();
    // TODO: 集成 image_picker
    // final image = await ImagePicker().pickImage(source: ImageSource.camera);
    // if (image != null) {
    //   setState(() => _idFrontImage = image.path);
    // }

    // 模拟选择
    await Future.delayed(const Duration(milliseconds: 500));
    setState(() => _idFrontImage = 'mock_id_front.jpg');
    _showSnackBar('身份证正面已选择（模拟）');
  }

  Future<void> _pickIdBackImage() async {
    HapticFeedbackUtil.lightImpact();
    await Future.delayed(const Duration(milliseconds: 500));
    setState(() => _idBackImage = 'mock_id_back.jpg');
    _showSnackBar('身份证反面已选择（模拟）');
  }

  Future<void> _pickWithHandImage() async {
    HapticFeedbackUtil.lightImpact();
    await Future.delayed(const Duration(milliseconds: 500));
    setState(() => _withHandImage = 'mock_with_hand.jpg');
    _showSnackBar('手持身份证照片已选择（模拟）');
  }

  void _sendSmsCode() {
    if (_smsCountdown > 0) return;

    HapticFeedbackUtil.mediumImpact();

    _showSnackBar('验证码已发送，请注意查收');

    setState(() => _smsCountdown = 60);
    _smsTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_smsCountdown <= 0) {
        timer.cancel();
        return;
      }
      setState(() => _smsCountdown--);
    });
  }

  bool _canProceedToNextStep() {
    switch (_currentStep) {
      case 0: // 基本信息
        return _realNameController.text.trim().isNotEmpty &&
            _idCardController.text.trim().isNotEmpty &&
            Validators.validateRealName(_realNameController.text) == null &&
            Validators.validateIdCard(_idCardController.text) == null;
      case 1: // 身份证照片
        return _idFrontImage != null && _idBackImage != null;
      case 2: // 手持照片
        return _withHandImage != null;
      case 3: // 验证码确认
        return _smsCodeController.text.length == 6;
      default:
        return false;
    }
  }

  void _nextStep() {
    if (!_canProceedToNextStep()) {
      HapticFeedbackUtil.error();
      _showSnackBar('请完成当前步骤');
      return;
    }

    HapticFeedbackUtil.success();

    if (_currentStep < 3) {
      setState(() => _currentStep++);
    } else {
      _submitVerification();
    }
  }

  void _previousStep() {
    if (_currentStep > 0) {
      HapticFeedbackUtil.lightImpact();
      setState(() => _currentStep--);
    }
  }

  Future<void> _submitVerification() async {
    setState(() => _isSubmitting = true);

    try {
      await widget.api.submitVerification(
        realName: _realNameController.text.trim(),
        idCardNumber: _idCardController.text.trim().toUpperCase(),
        idFrontUrl: _idFrontImage ?? '',
        idBackUrl: _idBackImage ?? '',
        withHandUrl: _withHandImage ?? '',
        smsCode: _smsCodeController.text.trim(),
      );

      final latestStatus = await widget.api.fetchVerificationStatus();

      HapticFeedbackUtil.success();

      if (mounted) {
        setState(() => _currentStatus = latestStatus.status);
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (_) => AlertDialog(
            icon: const Icon(
              Icons.check_circle_rounded,
              color: Color(0xFF34C759),
              size: 48,
            ),
            title: const Text('认证已提交'),
            content: const Text(
              '您的实名认证信息已提交，预计1-3个工作日内完成审核。\n\n审核通过后您可以：\n• 创建房间\n• 使用资金功能\n• 申请提现',
            ),
            actions: [
              FilledButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  Navigator.of(context).pop();
                  widget.onVerificationComplete?.call(latestStatus);
                },
                child: const Text('我知道了'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      HapticFeedbackUtil.error();
      _showSnackBar('提交失败：$e');
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('实名认证'),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: () {
            HapticFeedbackUtil.lightImpact();
            Navigator.of(context).pop();
          },
        ),
      ),
      body: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: () => FocusScope.of(context).unfocus(),
        child: SafeArea(
          child: Column(
            children: [
              // 步骤指示器
              _buildStepIndicator(),

              // 内容区域
              Expanded(
                child: SingleChildScrollView(
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  padding: const EdgeInsets.all(20),
                  child: _buildStepContent(),
                ),
              ),

              // 底部按钮
              _buildBottomButtons(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStepIndicator() {
    final steps = ['基本信息', '身份证', '手持照', '验证'];

    return Container(
      padding: const EdgeInsets.all(20),
      child: Row(
        children: List.generate(steps.length, (index) {
          final isActive = index <= _currentStep;
          final isCurrent = index == _currentStep;

          return Expanded(
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    children: [
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: isActive
                              ? const Color(0xFF0071E3)
                              : const Color(0xFFE5E7EB),
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: isActive && index < _currentStep
                              ? const Icon(
                                  Icons.check_rounded,
                                  color: Colors.white,
                                  size: 18,
                                )
                              : Text(
                                  '${index + 1}',
                                  style: TextStyle(
                                    color: isActive
                                        ? Colors.white
                                        : const Color(0xFF9CA3AF),
                                    fontWeight: FontWeight.w600,
                                    fontSize: 14,
                                  ),
                                ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        steps[index],
                        style: TextStyle(
                          fontSize: 12,
                          color: isCurrent
                              ? const Color(0xFF0071E3)
                              : const Color(0xFF6B7280),
                          fontWeight: isCurrent
                              ? FontWeight.w600
                              : FontWeight.normal,
                        ),
                      ),
                    ],
                  ),
                ),
                if (index < steps.length - 1)
                  Container(
                    width: 24,
                    height: 2,
                    color: index < _currentStep
                        ? const Color(0xFF0071E3)
                        : const Color(0xFFE5E7EB),
                  ),
              ],
            ),
          );
        }),
      ),
    );
  }

  Widget _buildStepContent() {
    switch (_currentStep) {
      case 0:
        return _buildBasicInfoStep();
      case 1:
        return _buildIdCardStep();
      case 2:
        return _buildWithHandStep();
      case 3:
        return _buildSmsVerifyStep();
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildBasicInfoStep() {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_currentStatus == VerificationStatus.rejected) ...[
            _buildInfoCard(
              icon: Icons.error_outline_rounded,
              title: '认证被驳回，请重新提交',
              content: '请核对姓名、身份证号及照片清晰度后再次提交。',
            ),
            const SizedBox(height: 16),
          ],
          const Text(
            '填写基本信息',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          const Text(
            '请确保填写的信息与身份证上的信息一致',
            style: TextStyle(color: Color(0xFF6B7280), fontSize: 14),
          ),
          const SizedBox(height: 24),

          TextFormField(
            controller: _realNameController,
            decoration: const InputDecoration(
              labelText: '真实姓名',
              hintText: '请输入身份证上的姓名',
              prefixIcon: Icon(Icons.person_outline_rounded),
            ),
            validator: Validators.validateRealName,
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 16),

          TextFormField(
            controller: _idCardController,
            decoration: const InputDecoration(
              labelText: '身份证号',
              hintText: '请输入18位身份证号码',
              prefixIcon: Icon(Icons.credit_card_rounded),
            ),
            keyboardType: TextInputType.text,
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[\dXx]')),
              LengthLimitingTextInputFormatter(18),
            ],
            validator: Validators.validateIdCard,
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 24),

          _buildInfoCard(
            icon: Icons.shield_outlined,
            title: '信息安全保障',
            content: '您的身份信息将被加密存储，仅用于实名认证，不会泄露给第三方。',
          ),
        ],
      ),
    );
  }

  Widget _buildIdCardStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '上传身份证照片',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        const Text(
          '请确保照片清晰、完整、无遮挡',
          style: TextStyle(color: Color(0xFF6B7280), fontSize: 14),
        ),
        const SizedBox(height: 24),

        _buildImagePicker(
          label: '身份证正面（人像面）',
          imageUrl: _idFrontImage,
          onTap: _pickIdFrontImage,
          placeholder: Icons.badge_outlined,
        ),
        const SizedBox(height: 16),

        _buildImagePicker(
          label: '身份证反面（国徽面）',
          imageUrl: _idBackImage,
          onTap: _pickIdBackImage,
          placeholder: Icons.article_outlined,
        ),
        const SizedBox(height: 24),

        _buildInfoCard(
          icon: Icons.lightbulb_outline_rounded,
          title: '拍摄提示',
          content: '• 请在光线充足处拍摄\n• 保持身份证水平放置\n• 确保四角完整可见\n• 避免反光和阴影',
        ),
      ],
    );
  }

  Widget _buildWithHandStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '上传手持身份证照片',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        const Text(
          '请手持身份证正面，确保面部和证件信息清晰可见',
          style: TextStyle(color: Color(0xFF6B7280), fontSize: 14),
        ),
        const SizedBox(height: 24),

        _buildImagePicker(
          label: '手持身份证照片',
          imageUrl: _withHandImage,
          onTap: _pickWithHandImage,
          placeholder: Icons.person_search_rounded,
          aspectRatio: 4 / 3,
        ),
        const SizedBox(height: 24),

        _buildInfoCard(
          icon: Icons.lightbulb_outline_rounded,
          title: '拍摄要求',
          content: '• 本人手持身份证正面\n• 面部清晰无遮挡\n• 身份证信息完整可读\n• 与本人照片一致',
        ),
      ],
    );
  }

  Widget _buildSmsVerifyStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '手机号验证',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        const Text(
          '请输入您收到的验证码完成最后一步认证',
          style: TextStyle(color: Color(0xFF6B7280), fontSize: 14),
        ),
        const SizedBox(height: 24),

        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: _smsCodeController,
                decoration: const InputDecoration(
                  labelText: '验证码',
                  hintText: '请输入6位验证码',
                  prefixIcon: Icon(Icons.sms_outlined),
                ),
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(6),
                ],
                onChanged: (_) => setState(() {}),
              ),
            ),
            const SizedBox(width: 12),
            FilledButton(
              onPressed: _smsCountdown > 0 ? null : _sendSmsCode,
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 16,
                ),
              ),
              child: Text(_smsCountdown > 0 ? '${_smsCountdown}s' : '获取验证码'),
            ),
          ],
        ),
        const SizedBox(height: 24),

        _buildInfoCard(
          icon: Icons.verified_user_outlined,
          title: '认证须知',
          content:
              '• 实名认证通过后，您将获得完整的平台功能\n• 认证信息不可修改，请确保填写正确\n• 预计1-3个工作日内完成审核',
        ),
      ],
    );
  }

  Widget _buildImagePicker({
    required String label,
    required String? imageUrl,
    required VoidCallback onTap,
    required IconData placeholder,
    double aspectRatio = 16 / 10,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: onTap,
          child: AspectRatio(
            aspectRatio: aspectRatio,
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFFF5F5F7),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: imageUrl != null
                      ? const Color(0xFF34C759)
                      : const Color(0xFFE5E7EB),
                  width: 2,
                ),
              ),
              child: imageUrl != null
                  ? Stack(
                      children: [
                        Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.check_circle_rounded,
                                color: const Color(0xFF34C759),
                                size: 48,
                              ),
                              const SizedBox(height: 8),
                              const Text(
                                '已选择',
                                style: TextStyle(
                                  color: Color(0xFF34C759),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Positioned(
                          top: 8,
                          right: 8,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Text(
                              '点击重新选择',
                              style: TextStyle(
                                fontSize: 12,
                                color: Color(0xFF6B7280),
                              ),
                            ),
                          ),
                        ),
                      ],
                    )
                  : Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          placeholder,
                          size: 48,
                          color: const Color(0xFF9CA3AF),
                        ),
                        const SizedBox(height: 12),
                        const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.add_a_photo_rounded,
                              size: 18,
                              color: Color(0xFF0071E3),
                            ),
                            SizedBox(width: 6),
                            Text(
                              '点击上传照片',
                              style: TextStyle(
                                color: Color(0xFF0071E3),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildInfoCard({
    required IconData icon,
    required String title,
    required String content,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF0F9FF),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFBAE6FD)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: const Color(0xFF0284C7)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF0284C7),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  content,
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFF0369A1),
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomButtons() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            if (_currentStep > 0)
              Expanded(
                child: OutlinedButton(
                  onPressed: _isSubmitting ? null : _previousStep,
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: const Text('上一步'),
                ),
              ),
            if (_currentStep > 0) const SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: FilledButton(
                onPressed: _isSubmitting ? null : _nextStep,
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: _isSubmitting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Text(_currentStep == 3 ? '提交认证' : '下一步'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
