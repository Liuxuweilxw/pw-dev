import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';

import '../../../models/business_models.dart';
import '../../../services/platform_api.dart';

/// 等级权益信息
class LevelBenefit {
  const LevelBenefit({
    required this.level,
    required this.name,
    required this.color,
    required this.icon,
    required this.requiredPoints,
    required this.benefits,
  });

  final int level;
  final String name;
  final Color color;
  final IconData icon;
  final int requiredPoints;
  final List<String> benefits;
}

/// 预定义等级权益
const List<LevelBenefit> levelBenefits = [
  LevelBenefit(
    level: 1,
    name: '新手',
    color: Color(0xFF9CA3AF),
    icon: Icons.star_border_rounded,
    requiredPoints: 0,
    benefits: ['基础下单功能', '文字聊天', '标准客服响应'],
  ),
  LevelBenefit(
    level: 2,
    name: '青铜',
    color: Color(0xFFCD7F32),
    icon: Icons.star_half_rounded,
    requiredPoints: 500,
    benefits: ['所有Lv1权益', '语音聊天解锁', '优先匹配陪玩', '充值9.8折优惠'],
  ),
  LevelBenefit(
    level: 3,
    name: '白银',
    color: Color(0xFFC0C0C0),
    icon: Icons.star_rounded,
    requiredPoints: 2000,
    benefits: ['所有Lv2权益', '专属客服通道', '订单纠纷优先处理', '充值9.5折优惠', '专属等级徽章'],
  ),
  LevelBenefit(
    level: 4,
    name: '黄金',
    color: Color(0xFFFFD700),
    icon: Icons.workspace_premium_rounded,
    requiredPoints: 5000,
    benefits: ['所有Lv3权益', 'VIP专属陪玩推荐', '免服务费订单', '充值9折优惠', '定制头像框'],
  ),
  LevelBenefit(
    level: 5,
    name: '钻石',
    color: Color(0xFF00CED1),
    icon: Icons.diamond_rounded,
    requiredPoints: 10000,
    benefits: [
      '所有Lv4权益',
      '1对1专属客服',
      '线下活动优先参与',
      '充值8.5折优惠',
      '平台决策投票权',
      '年度礼品包',
    ],
  ),
];

/// 积分会员页面
class PointsMemberPage extends StatefulWidget {
  const PointsMemberPage({super.key, required this.api});

  final PlatformApi api;

  @override
  State<PointsMemberPage> createState() => _PointsMemberPageState();
}

class _PointsMemberPageState extends State<PointsMemberPage> {
  bool _isLoading = true;
  bool _isRefreshing = false;
  String? _error;
  UserBalance? _balance;
  List<PointRecord> _records = const [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData({
    bool showLoading = true,
    bool showSuccessHint = false,
  }) async {
    if (showLoading) {
      setState(() {
        _isLoading = true;
        _error = null;
      });
    } else {
      setState(() {
        _isRefreshing = true;
      });
    }

    try {
      final results = await Future.wait<dynamic>([
        widget.api.fetchUserBalance(),
        widget.api.fetchPointRecords(),
      ]);

      if (!mounted) {
        return;
      }

      setState(() {
        _balance = results[0] as UserBalance;
        _records = results[1] as List<PointRecord>;
        _error = null;
        _isLoading = false;
        _isRefreshing = false;
      });
      if (!showLoading && showSuccessHint) {
        ScaffoldMessenger.of(context)
          ..clearSnackBars()
          ..showSnackBar(
            const SnackBar(
              content: Text('已更新'),
              duration: Duration(milliseconds: 900),
            ),
          );
      }
    } catch (e) {
      if (!mounted) {
        return;
      }
      if (showLoading) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
          _isRefreshing = false;
        });
      } else {
        setState(() {
          _isRefreshing = false;
        });
        ScaffoldMessenger.of(context)
          ..clearSnackBars()
          ..showSnackBar(SnackBar(content: Text('刷新失败：$e')));
      }
    }
  }

  LevelBenefit get _currentLevelBenefit {
    final level = _balance?.level ?? 1;
    return levelBenefits.firstWhere(
      (b) => b.level == level,
      orElse: () => levelBenefits.first,
    );
  }

  LevelBenefit? get _nextLevelBenefit {
    final level = _balance?.level ?? 1;
    if (level >= levelBenefits.length) {
      return null;
    }
    return levelBenefits.firstWhere(
      (b) => b.level == level + 1,
      orElse: () => levelBenefits.last,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('积分会员'),
        centerTitle: true,
        actions: [
          IconButton(
            onPressed: _isRefreshing
                ? null
                : () => _loadData(showLoading: false, showSuccessHint: true),
            icon: _isRefreshing
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.refresh_rounded),
            tooltip: '刷新',
          ),
        ],
      ),
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
            ? _ErrorView(error: _error!, onRetry: _loadData)
            : _buildContent(),
      ),
    );
  }

  Widget _buildContent() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildLevelHeroCard(),
        const SizedBox(height: 20),
        _buildProgressCard(),
        const SizedBox(height: 20),
        _buildSectionTitle('等级权益'),
        const SizedBox(height: 10),
        _buildBenefitsHorizontalList(),
      ],
    );
  }

  Widget _buildBenefitsHorizontalList() {
    return SizedBox(
      height: 300,
      child: ScrollConfiguration(
        behavior: ScrollConfiguration.of(context).copyWith(
          dragDevices: {
            PointerDeviceKind.touch,
            PointerDeviceKind.mouse,
            PointerDeviceKind.trackpad,
            PointerDeviceKind.stylus,
            PointerDeviceKind.unknown,
          },
        ),
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: levelBenefits.length,
          separatorBuilder: (_, __) => const SizedBox(width: 12),
          itemBuilder: (context, index) {
            final benefit = levelBenefits[index];
            return SizedBox(width: 320, child: _buildBenefitCard(benefit));
          },
        ),
      ),
    );
  }

  Widget _buildLevelHeroCard() {
    final levelBenefit = _currentLevelBenefit;
    final nextLevel = _nextLevelBenefit;

    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF0071E3), Color(0xFF00C7BE)],
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0071E3).withAlpha(51),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white.withAlpha(46),
                  shape: BoxShape.circle,
                ),
                child: Icon(levelBenefit.icon, size: 32, color: Colors.white),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Lv.${levelBenefit.level} ${levelBenefit.name}',
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '当前积分：${_balance?.points ?? 0}',
                      style: TextStyle(
                        color: Colors.white.withAlpha(220),
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          if (nextLevel != null)
            Text(
              '距离 Lv.${nextLevel.level} ${nextLevel.name} 还需 ${_remainingToNextLevel(nextLevel)} 积分',
              style: TextStyle(
                color: Colors.white.withAlpha(220),
                fontSize: 13,
              ),
            )
          else
            Text(
              '🎉 已达最高等级',
              style: TextStyle(
                color: Colors.white.withAlpha(220),
                fontSize: 13,
              ),
            ),
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.bottomRight,
            child: TextButton.icon(
              onPressed: _openRecordsPage,
              icon: const Icon(
                Icons.receipt_long_rounded,
                size: 16,
                color: Colors.white,
              ),
              label: const Text('积分明细', style: TextStyle(color: Colors.white)),
              style: TextButton.styleFrom(
                visualDensity: VisualDensity.compact,
                backgroundColor: Colors.white.withAlpha(28),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openRecordsPage() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => _PointRecordsPage(records: _records),
      ),
    );
  }

  Widget _buildProgressCard() {
    final nextLevel = _nextLevelBenefit;

    return _surfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '升级进度',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 10),
          if (nextLevel == null)
            const Text('您已达到最高会员等级')
          else ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Lv.${_currentLevelBenefit.level} → Lv.${nextLevel.level}',
                  style: const TextStyle(
                    color: Color(0xFF6B7280),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  '${_balance?.points ?? 0}/${nextLevel.requiredPoints}',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                value: (_balance?.levelProgress ?? 0).clamp(0.0, 1.0),
                minHeight: 8,
                backgroundColor: const Color(0xFFE5E7EB),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildBenefitCard(LevelBenefit benefit) {
    final isCurrentLevel = benefit.level == (_balance?.level ?? 1);
    final isUnlocked = benefit.level <= (_balance?.level ?? 1);

    return _surfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: isUnlocked
                      ? benefit.color.withAlpha(38)
                      : const Color(0xFFF3F4F6),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  benefit.icon,
                  color: isUnlocked ? benefit.color : const Color(0xFF9CA3AF),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          'Lv.${benefit.level} ${benefit.name}',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: isUnlocked
                                ? const Color(0xFF111827)
                                : const Color(0xFF9CA3AF),
                          ),
                        ),
                        if (isCurrentLevel)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFF0071E3),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: const Text(
                              '当前',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '需要 ${benefit.requiredPoints} 积分',
                      style: const TextStyle(
                        color: Color(0xFF6B7280),
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...benefit.benefits.map(
            (item) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    isUnlocked
                        ? Icons.check_circle_rounded
                        : Icons.circle_outlined,
                    size: 18,
                    color: isUnlocked
                        ? const Color(0xFF16A34A)
                        : const Color(0xFF9CA3AF),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      item,
                      style: TextStyle(
                        color: isUnlocked
                            ? const Color(0xFF111827)
                            : const Color(0xFF9CA3AF),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.2,
      ),
    );
  }

  Widget _surfaceCard({required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFEAEAF0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(10),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: child,
    );
  }

  int _remainingToNextLevel(LevelBenefit nextLevel) {
    final current = _balance?.points ?? 0;
    final remaining = nextLevel.requiredPoints - current;
    return remaining < 0 ? 0 : remaining;
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.error, required this.onRetry});

  final String error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline_rounded, size: 44),
            const SizedBox(height: 12),
            const Text('积分信息加载失败'),
            const SizedBox(height: 8),
            Text(
              error,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Color(0xFF6B7280)),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('重试'),
            ),
          ],
        ),
      ),
    );
  }
}

class _PointRecordsPage extends StatefulWidget {
  const _PointRecordsPage({required this.records});

  final List<PointRecord> records;

  @override
  State<_PointRecordsPage> createState() => _PointRecordsPageState();
}

class _PointRecordsPageState extends State<_PointRecordsPage> {
  late DateTimeRange _selectedRange;
  late final TextEditingController _startDateController;
  late final TextEditingController _endDateController;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selectedRange = DateTimeRange(
      start: DateTime(now.year - 1, now.month, now.day),
      end: now,
    );
    _startDateController = TextEditingController(
      text: _formatDateCompact(_selectedRange.start),
    );
    _endDateController = TextEditingController(
      text: _formatDateCompact(_selectedRange.end),
    );
  }

  @override
  void dispose() {
    _startDateController.dispose();
    _endDateController.dispose();
    super.dispose();
  }

  List<PointRecord> get _filteredRecords {
    final start = DateTime(
      _selectedRange.start.year,
      _selectedRange.start.month,
      _selectedRange.start.day,
    );
    final endExclusive = DateTime(
      _selectedRange.end.year,
      _selectedRange.end.month,
      _selectedRange.end.day,
    ).add(const Duration(days: 1));

    return widget.records.where((record) {
      return !record.createdAt.isBefore(start) &&
          record.createdAt.isBefore(endExclusive);
    }).toList();
  }

  void _applyInputRange() {
    final start = _parseInputDate(_startDateController.text);
    final end = _parseInputDate(_endDateController.text);

    if (start == null || end == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('日期格式错误，请输入 YYYYMMDD 或 YYYY-MM-DD')),
      );
      return;
    }
    if (start.isAfter(end)) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('开始日期不能晚于结束日期')));
      return;
    }

    setState(() {
      _selectedRange = DateTimeRange(start: start, end: end);
    });
  }

  DateTime? _parseInputDate(String input) {
    final normalized = input.trim().replaceAll('-', '');
    if (normalized.length != 8) {
      return null;
    }
    final year = int.tryParse(normalized.substring(0, 4));
    final month = int.tryParse(normalized.substring(4, 6));
    final day = int.tryParse(normalized.substring(6, 8));
    if (year == null || month == null || day == null) {
      return null;
    }
    if (month < 1 || month > 12 || day < 1 || day > 31) {
      return null;
    }

    final date = DateTime(year, month, day);
    if (date.year != year || date.month != month || date.day != day) {
      return null;
    }
    return date;
  }

  @override
  Widget build(BuildContext context) {
    final records = _filteredRecords;

    return Scaffold(
      appBar: AppBar(title: const Text('积分明细'), centerTitle: true),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: const Color(0xFFEAEAF0)),
            ),
            child: Row(
              children: [
                const Icon(Icons.date_range_rounded, color: Color(0xFF6B7280)),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: _startDateController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      hintText: '开始日期',
                      isDense: true,
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 10,
                      ),
                    ),
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _endDateController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      hintText: '结束日期',
                      isDense: true,
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 10,
                      ),
                    ),
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: _applyInputRange,
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(56, 38),
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                  ),
                  child: const Text('应用'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          if (records.isEmpty)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: const Color(0xFFEAEAF0)),
              ),
              child: const Column(
                children: [
                  Icon(Icons.stars_rounded, size: 40, color: Color(0xFF9CA3AF)),
                  SizedBox(height: 8),
                  Text('该时间范围暂无积分记录'),
                ],
              ),
            )
          else
            ...records.map((record) {
              final isPositive = record.points > 0;
              final accent = isPositive
                  ? const Color(0xFF16A34A)
                  : const Color(0xFFD97706);
              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFEAEAF0)),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: accent.withAlpha(24),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        isPositive
                            ? Icons.add_circle_outline_rounded
                            : Icons.remove_circle_outline_rounded,
                        color: accent,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            record.reasonText,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _formatDateTime(record.createdAt),
                            style: const TextStyle(
                              color: Color(0xFF6B7280),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      '${isPositive ? '+' : ''}${record.points}',
                      style: TextStyle(
                        color: accent,
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }

  String _formatDateCompact(DateTime date) {
    return '${date.year.toString().padLeft(4, '0')}${date.month.toString().padLeft(2, '0')}${date.day.toString().padLeft(2, '0')}';
  }

  String _formatDateTime(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')} '
        '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }
}
