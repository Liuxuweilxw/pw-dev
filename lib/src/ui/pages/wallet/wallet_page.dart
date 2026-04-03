import 'package:flutter/material.dart';

import '../../../models/business_models.dart';
import '../../../services/platform_api.dart';
import '../../../utils/haptic_feedback.dart';
import '../../components/loading_skeleton.dart';
import '../points/points_member_page.dart';
import 'payment_result_page.dart';

/// 完整的钱包页面 - 符合iOS设计规范
class WalletPage extends StatefulWidget {
  const WalletPage({super.key, required this.api});

  final PlatformApi api;

  @override
  State<WalletPage> createState() => _WalletPageState();
}

class _WalletPageState extends State<WalletPage> {
  UserBalance? _balance;
  List<PointRecord> _pointRecords = const [];
  bool _isLoading = true;
  String? _error;
  String _selectedChannel = '支付宝';

  @override
  void initState() {
    super.initState();
    _loadBalance();
  }

  Future<void> _loadBalance() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final results = await Future.wait<dynamic>([
        widget.api.fetchUserBalance(),
        widget.api.fetchPointRecords().catchError((_) => <PointRecord>[]),
      ]);

      final balance = results[0] as UserBalance;
      final records = results[1] as List<PointRecord>;
      if (mounted) {
        setState(() {
          _balance = balance;
          _pointRecords = records;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  PointRecord? get _latestPointRecord {
    if (_pointRecords.isEmpty) {
      return null;
    }
    return _pointRecords.first;
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _handleRecharge(int amount) async {
    HapticFeedbackUtil.mediumImpact();

    // 显示支付确认对话框
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) =>
          PaymentConfirmDialog(amount: amount, channel: _selectedChannel),
    );

    if (confirmed != true) return;

    // 显示加载状态
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      await widget.api.recharge(amount: amount, channel: _selectedChannel);
      await _loadBalance();

      if (mounted) {
        Navigator.of(context).pop(); // 关闭加载

        // 显示支付结果页
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => PaymentResultPage(
              status: PaymentResultStatus.success,
              amount: amount,
              orderId: 'RC${DateTime.now().millisecondsSinceEpoch}',
              onComplete: () {},
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.of(context).pop(); // 关闭加载

        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => PaymentResultPage(
              status: PaymentResultStatus.failed,
              amount: amount,
              errorMessage: e.toString(),
              onRetry: () => _handleRecharge(amount),
            ),
          ),
        );
      }
    }
  }

  Future<void> _showCustomAmountDialog() async {
    final controller = TextEditingController();

    final amount = await showDialog<int>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('自定义充值金额'),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: '输入金额',
            hintText: '最低100元',
            prefixText: '¥ ',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              HapticFeedbackUtil.lightImpact();
              Navigator.of(context).pop();
            },
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () {
              HapticFeedbackUtil.mediumImpact();
              final value = int.tryParse(controller.text.trim());
              if (value == null || value < 100) {
                _showSnackBar('请输入100元以上的金额');
                return;
              }
              Navigator.of(context).pop(value);
            },
            child: const Text('确定'),
          ),
        ],
      ),
    );

    controller.dispose();

    if (amount != null) {
      await _handleRecharge(amount);
    }
  }

  Future<void> _showWithdrawDialog() async {
    if (_balance == null || _balance!.availableBalance < 100) {
      _showSnackBar('可用余额不足100元，无法提现');
      return;
    }

    final controller = TextEditingController();

    final amount = await showDialog<int>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('申请提现'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF3F4F6),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Text(
                    '可提现余额：',
                    style: TextStyle(color: Color(0xFF6B7280)),
                  ),
                  Text(
                    '¥${_balance!.availableBalance}',
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 18,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              autofocus: true,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: '提现金额',
                hintText: '最低100元',
                prefixText: '¥ ',
              ),
            ),
            const SizedBox(height: 12),
            Text(
              '• 提现将在1-3个工作日内到账\n• 提现至原充值账户',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
                height: 1.5,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              HapticFeedbackUtil.lightImpact();
              Navigator.of(context).pop();
            },
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () {
              HapticFeedbackUtil.mediumImpact();
              final value = int.tryParse(controller.text.trim());
              if (value == null || value < 100) {
                _showSnackBar('请输入100元以上的金额');
                return;
              }
              if (value > _balance!.availableBalance) {
                _showSnackBar('提现金额不能超过可用余额');
                return;
              }
              Navigator.of(context).pop(value);
            },
            child: const Text('申请提现'),
          ),
        ],
      ),
    );

    controller.dispose();

    if (amount != null) {
      try {
        await widget.api.withdraw(amount: amount);
        await _loadBalance();
        HapticFeedbackUtil.success();
        _showSnackBar('提现申请已提交，预计1-3个工作日到账');
      } catch (e) {
        HapticFeedbackUtil.error();
        _showSnackBar('提现失败：$e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('我的钱包'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _loadBalance,
            tooltip: '刷新',
          ),
        ],
      ),
      body: SafeArea(
        child: _isLoading
            ? const _LoadingView()
            : _error != null
            ? _ErrorView(error: _error!, onRetry: _loadBalance)
            : _buildContent(),
      ),
    );
  }

  Widget _buildContent() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // 余额卡片
        _buildBalanceCard(),
        const SizedBox(height: 20),

        // 充值档位
        _buildRechargeSection(),
        const SizedBox(height: 20),

        // 提现入口
        _buildWithdrawSection(),
        const SizedBox(height: 20),

        // 积分信息
        _buildPointsSection(),
      ],
    );
  }

  Widget _buildBalanceCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF0071E3), Color(0xFF00C7BE)],
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0071E3).withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                '总余额',
                style: TextStyle(color: Colors.white70, fontSize: 14),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _balance?.levelName ?? 'Lv1',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '¥ ${_formatNumber(_balance?.totalBalance ?? 0)}',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 36,
              fontWeight: FontWeight.w700,
              letterSpacing: -1,
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: _buildBalanceItem(
                  '可用余额',
                  _balance?.availableBalance ?? 0,
                ),
              ),
              Container(width: 1, height: 40, color: Colors.white24),
              Expanded(
                child: _buildBalanceItem('冻结金额', _balance?.frozenBalance ?? 0),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBalanceItem(String label, int amount) {
    return Column(
      children: [
        Text(
          label,
          style: const TextStyle(color: Colors.white70, fontSize: 12),
        ),
        const SizedBox(height: 4),
        Text(
          '¥${_formatNumber(amount)}',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildRechargeSection() {
    final amounts = [500, 1000, 2000, 5000, 10000, 20000];

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '充值',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 16),

          // 支付渠道选择
          Row(
            children: [
              _buildChannelChip('支付宝', Icons.account_balance_wallet),
              const SizedBox(width: 12),
              _buildChannelChip('微信支付', Icons.wechat),
            ],
          ),
          const SizedBox(height: 16),

          // 金额选择
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              ...amounts.map((amount) => _buildAmountChip(amount)),
              _buildCustomAmountChip(),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildChannelChip(String label, IconData icon) {
    final isSelected = _selectedChannel == label;

    return GestureDetector(
      onTap: () {
        HapticFeedbackUtil.selectionClick();
        setState(() => _selectedChannel = label);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF0071E3) : const Color(0xFFF3F4F6),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 18,
              color: isSelected ? Colors.white : const Color(0xFF6B7280),
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : const Color(0xFF374151),
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAmountChip(int amount) {
    return GestureDetector(
      onTap: () => _handleRecharge(amount),
      child: Container(
        width: 100,
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: const Color(0xFFF3F4F6),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Text(
              '¥$amount',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCustomAmountChip() {
    return GestureDetector(
      onTap: _showCustomAmountDialog,
      child: Container(
        width: 100,
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFF0071E3)),
        ),
        child: const Column(
          children: [
            Text(
              '自定义',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Color(0xFF0071E3),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWithdrawSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: const Color(0xFFFEF3C7),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.account_balance_rounded,
              color: Color(0xFFF59E0B),
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '申请提现',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
                SizedBox(height: 4),
                Text(
                  '提现至原充值账户，1-3个工作日到账',
                  style: TextStyle(fontSize: 13, color: Color(0xFF6B7280)),
                ),
              ],
            ),
          ),
          FilledButton(onPressed: _showWithdrawDialog, child: const Text('提现')),
        ],
      ),
    );
  }

  Widget _buildPointsSection() {
    final latestRecord = _latestPointRecord;
    final latestDeltaText = latestRecord == null
        ? '暂无积分变动记录'
        : '最近变动：${latestRecord.isPositive ? '+' : ''}${latestRecord.points}（${latestRecord.reasonText}）';
    final latestTimeText = latestRecord == null
        ? ''
        : '变动时间：${_formatPointRecordTime(latestRecord.createdAt)}';

    return Material(
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: Color(0xFFE5E7EB)),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () {
          HapticFeedbackUtil.lightImpact();
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => PointsMemberPage(api: widget.api),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Text(
                    '我的积分',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                  ),
                  const Spacer(),
                  Text(
                    '${_balance?.points ?? 0} 积分',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFFF59E0B),
                    ),
                  ),
                  const SizedBox(width: 6),
                  const Icon(
                    Icons.chevron_right_rounded,
                    color: Color(0xFF9CA3AF),
                    size: 20,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                latestDeltaText,
                style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
              ),
              if (latestTimeText.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  latestTimeText,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF9CA3AF),
                  ),
                ),
              ],
              const SizedBox(height: 16),

              // 等级进度
              Row(
                children: [
                  Text(
                    _balance?.levelName ?? 'Lv1',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: _balance?.levelProgress ?? 0,
                        backgroundColor: const Color(0xFFE5E7EB),
                        color: const Color(0xFFF59E0B),
                        minHeight: 8,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Lv${(_balance?.level ?? 1) + 1}',
                    style: const TextStyle(
                      fontSize: 13,
                      color: Color(0xFF6B7280),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                '还需 ${(_balance?.nextLevelPoints ?? 500) - (_balance?.points ?? 0)} 积分升级',
                style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatNumber(int number) {
    if (number >= 10000) {
      return '${(number / 10000).toStringAsFixed(1)}万';
    }
    return number.toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (match) => '${match[1]},',
    );
  }

  String _formatPointRecordTime(DateTime dateTime) {
    final now = DateTime.now();
    final diff = now.difference(dateTime);

    if (diff.inSeconds < 60) {
      return '刚刚';
    }
    if (diff.inMinutes < 60) {
      return '${diff.inMinutes} 分钟前';
    }
    if (diff.inHours < 24 && now.day == dateTime.day) {
      return '${diff.inHours} 小时前';
    }

    final hh = dateTime.hour.toString().padLeft(2, '0');
    final min = dateTime.minute.toString().padLeft(2, '0');

    final yesterday = DateTime(now.year, now.month, now.day - 1);
    final dateOnly = DateTime(dateTime.year, dateTime.month, dateTime.day);
    if (dateOnly == DateTime(now.year, now.month, now.day)) {
      return '今天 $hh:$min';
    }
    if (dateOnly == yesterday) {
      return '昨天 $hh:$min';
    }

    final mm = dateTime.month.toString().padLeft(2, '0');
    final dd = dateTime.day.toString().padLeft(2, '0');
    return '$mm-$dd $hh:$min';
  }
}

class _LoadingView extends StatelessWidget {
  const _LoadingView();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.all(16),
      child: Column(
        children: [
          BalanceCardSkeleton(),
          SizedBox(height: 20),
          LoadingSkeleton(
            width: double.infinity,
            height: 160,
            borderRadius: 20,
          ),
        ],
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.error, required this.onRetry});

  final String error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.error_outline_rounded,
            size: 64,
            color: Color(0xFFEF4444),
          ),
          const SizedBox(height: 16),
          const Text(
            '加载失败',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Text(
            error,
            style: const TextStyle(color: Color(0xFF6B7280)),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('重试'),
          ),
        ],
      ),
    );
  }
}
