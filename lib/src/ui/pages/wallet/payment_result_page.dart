import 'package:flutter/material.dart';

import '../../../utils/haptic_feedback.dart';

/// 支付结果状态枚举
enum PaymentResultStatus { success, failed, processing }

/// 支付结果页面 - 符合iOS设计规范
class PaymentResultPage extends StatefulWidget {
  const PaymentResultPage({
    super.key,
    required this.status,
    required this.amount,
    this.orderId,
    this.errorMessage,
    this.onRetry,
    this.onComplete,
  });

  final PaymentResultStatus status;
  final int amount;
  final String? orderId;
  final String? errorMessage;
  final VoidCallback? onRetry;
  final VoidCallback? onComplete;

  @override
  State<PaymentResultPage> createState() => _PaymentResultPageState();
}

class _PaymentResultPageState extends State<PaymentResultPage>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.elasticOut),
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.0, 0.5),
      ),
    );

    _animationController.forward();

    // 触觉反馈
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.status == PaymentResultStatus.success) {
        HapticFeedbackUtil.success();
      } else if (widget.status == PaymentResultStatus.failed) {
        HapticFeedbackUtil.error();
      }
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _getBackgroundColor(),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.close_rounded,
            color: widget.status == PaymentResultStatus.success
                ? Colors.white
                : const Color(0xFF1F2937),
          ),
          onPressed: () {
            HapticFeedbackUtil.lightImpact();
            widget.onComplete?.call();
            Navigator.of(context).pop();
          },
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const Spacer(),
              _buildResultIcon(),
              const SizedBox(height: 24),
              _buildResultTitle(),
              const SizedBox(height: 12),
              _buildResultDescription(),
              if (widget.orderId != null) ...[
                const SizedBox(height: 24),
                _buildOrderInfo(),
              ],
              const Spacer(),
              _buildActionButtons(),
            ],
          ),
        ),
      ),
    );
  }

  Color _getBackgroundColor() {
    switch (widget.status) {
      case PaymentResultStatus.success:
        return const Color(0xFF34C759);
      case PaymentResultStatus.failed:
        return Colors.white;
      case PaymentResultStatus.processing:
        return Colors.white;
    }
  }

  Widget _buildResultIcon() {
    return ScaleTransition(
      scale: _scaleAnimation,
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: Container(
          width: 120,
          height: 120,
          decoration: BoxDecoration(
            color: _getIconBackgroundColor(),
            shape: BoxShape.circle,
          ),
          child: Icon(_getResultIcon(), size: 60, color: _getIconColor()),
        ),
      ),
    );
  }

  Color _getIconBackgroundColor() {
    switch (widget.status) {
      case PaymentResultStatus.success:
        return Colors.white.withOpacity(0.2);
      case PaymentResultStatus.failed:
        return const Color(0xFFFEE2E2);
      case PaymentResultStatus.processing:
        return const Color(0xFFFEF3C7);
    }
  }

  Color _getIconColor() {
    switch (widget.status) {
      case PaymentResultStatus.success:
        return Colors.white;
      case PaymentResultStatus.failed:
        return const Color(0xFFEF4444);
      case PaymentResultStatus.processing:
        return const Color(0xFFF59E0B);
    }
  }

  IconData _getResultIcon() {
    switch (widget.status) {
      case PaymentResultStatus.success:
        return Icons.check_circle_rounded;
      case PaymentResultStatus.failed:
        return Icons.cancel_rounded;
      case PaymentResultStatus.processing:
        return Icons.hourglass_top_rounded;
    }
  }

  Widget _buildResultTitle() {
    final isLight = widget.status == PaymentResultStatus.success;

    return Text(
      _getResultTitle(),
      style: TextStyle(
        fontSize: 28,
        fontWeight: FontWeight.w700,
        color: isLight ? Colors.white : const Color(0xFF1F2937),
      ),
    );
  }

  String _getResultTitle() {
    switch (widget.status) {
      case PaymentResultStatus.success:
        return '支付成功';
      case PaymentResultStatus.failed:
        return '支付失败';
      case PaymentResultStatus.processing:
        return '处理中';
    }
  }

  Widget _buildResultDescription() {
    final isLight = widget.status == PaymentResultStatus.success;

    String description;
    switch (widget.status) {
      case PaymentResultStatus.success:
        description = '您已成功充值 ¥${widget.amount}';
        break;
      case PaymentResultStatus.failed:
        description = widget.errorMessage ?? '支付过程中出现问题，请重试';
        break;
      case PaymentResultStatus.processing:
        description = '您的支付正在处理中，请稍候...';
        break;
    }

    return Text(
      description,
      textAlign: TextAlign.center,
      style: TextStyle(
        fontSize: 16,
        color: isLight
            ? Colors.white.withOpacity(0.9)
            : const Color(0xFF6B7280),
        height: 1.5,
      ),
    );
  }

  Widget _buildOrderInfo() {
    final isLight = widget.status == PaymentResultStatus.success;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isLight
            ? Colors.white.withOpacity(0.15)
            : const Color(0xFFF3F4F6),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          _buildInfoRow('订单号', widget.orderId!, isLight: isLight),
          const SizedBox(height: 8),
          _buildInfoRow('充值金额', '¥${widget.amount}', isLight: isLight),
          const SizedBox(height: 8),
          _buildInfoRow(
            '支付时间',
            _formatDateTime(DateTime.now()),
            isLight: isLight,
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, {bool isLight = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            color: isLight
                ? Colors.white.withOpacity(0.7)
                : const Color(0xFF6B7280),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: isLight ? Colors.white : const Color(0xFF1F2937),
          ),
        ),
      ],
    );
  }

  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.year}-${dateTime.month.toString().padLeft(2, '0')}-${dateTime.day.toString().padLeft(2, '0')} '
        '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
  }

  Widget _buildActionButtons() {
    final isLight = widget.status == PaymentResultStatus.success;

    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: () {
              HapticFeedbackUtil.mediumImpact();
              widget.onComplete?.call();
              Navigator.of(context).pop();
            },
            style: FilledButton.styleFrom(
              backgroundColor: isLight ? Colors.white : const Color(0xFF0071E3),
              foregroundColor: isLight ? const Color(0xFF34C759) : Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            child: const Text(
              '完成',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
            ),
          ),
        ),
        if (widget.status == PaymentResultStatus.failed &&
            widget.onRetry != null) ...[
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: () {
                HapticFeedbackUtil.mediumImpact();
                Navigator.of(context).pop();
                widget.onRetry?.call();
              },
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: const Text(
                '重试',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

/// 支付确认对话框
class PaymentConfirmDialog extends StatefulWidget {
  const PaymentConfirmDialog({
    super.key,
    required this.amount,
    this.initialChannel = '支付宝',
    this.serviceFee = 0,
  });

  final int amount;
  final String initialChannel;
  final int serviceFee;

  @override
  State<PaymentConfirmDialog> createState() => _PaymentConfirmDialogState();
}

class _PaymentConfirmDialogState extends State<PaymentConfirmDialog> {
  late String _selectedChannel;

  @override
  void initState() {
    super.initState();
    _selectedChannel = widget.initialChannel;
  }

  @override
  Widget build(BuildContext context) {
    final totalAmount = widget.amount + widget.serviceFee;

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      contentPadding: const EdgeInsets.all(24),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: const Color(0xFFF0FDF4),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.payment_rounded,
              size: 32,
              color: Color(0xFF34C759),
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            '确认支付',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 24),
          _buildAmountRow('充值金额', '¥${widget.amount}'),
          if (widget.serviceFee > 0) ...[
            const SizedBox(height: 8),
            _buildAmountRow('服务费', '¥${widget.serviceFee}'),
          ],
          const Divider(height: 24),
          _buildAmountRow('实付金额', '¥$totalAmount', isTotal: true),
          const SizedBox(height: 16),
          _buildChannelOption('支付宝', Icons.account_balance_wallet),
          const SizedBox(height: 8),
          _buildChannelOption('微信支付', Icons.wechat),
        ],
      ),
      actions: [
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () {
                  HapticFeedbackUtil.lightImpact();
                  Navigator.of(context).pop();
                },
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: const Text('取消'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: FilledButton(
                onPressed: () {
                  HapticFeedbackUtil.mediumImpact();
                  Navigator.of(context).pop(_selectedChannel);
                },
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: const Text('确认支付'),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildChannelOption(String channel, IconData icon) {
    final isSelected = _selectedChannel == channel;
    return InkWell(
      onTap: () {
        HapticFeedbackUtil.selectionClick();
        setState(() {
          _selectedChannel = channel;
        });
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFEFF6FF) : const Color(0xFFF3F4F6),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? const Color(0xFF3B82F6) : Colors.transparent,
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: channel == '支付宝'
                  ? const Color(0xFF1677FF)
                  : const Color(0xFF07C160),
              size: 24,
            ),
            const SizedBox(width: 12),
            Text(
              channel,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
            ),
            const Spacer(),
            Icon(
              isSelected
                  ? Icons.check_circle_rounded
                  : Icons.radio_button_unchecked_rounded,
              color: isSelected
                  ? const Color(0xFF34C759)
                  : const Color(0xFF9CA3AF),
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAmountRow(String label, String value, {bool isTotal = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: isTotal ? 16 : 14,
            color: const Color(0xFF6B7280),
            fontWeight: isTotal ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: isTotal ? 22 : 16,
            fontWeight: isTotal ? FontWeight.w700 : FontWeight.w500,
            color: isTotal ? const Color(0xFF1F2937) : const Color(0xFF374151),
          ),
        ),
      ],
    );
  }
}
