import 'package:flutter/material.dart';

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

class _PointsMemberPageState extends State<PointsMemberPage>
    with SingleTickerProviderStateMixin {
  bool _isLoading = true;
  UserBalance? _balance;
  List<PointRecord> _records = [];
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    try {
      final results = await Future.wait([
        widget.api.fetchUserBalance(),
        widget.api.fetchPointRecords(),
      ]);

      if (mounted) {
        setState(() {
          _balance = results[0] as UserBalance;
          _records = results[1] as List<PointRecord>;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('加载失败: $e')));
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
    if (level >= levelBenefits.length) return null;
    return levelBenefits.firstWhere(
      (b) => b.level == level + 1,
      orElse: () => levelBenefits.last,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : CustomScrollView(
              slivers: [
                // 顶部渐变AppBar
                SliverAppBar(
                  expandedHeight: 280,
                  pinned: true,
                  flexibleSpace: FlexibleSpaceBar(
                    background: _buildHeaderBackground(theme),
                  ),
                  title: const Text('会员中心'),
                ),
                // TabBar
                SliverPersistentHeader(
                  pinned: true,
                  delegate: _StickyTabBarDelegate(
                    TabBar(
                      controller: _tabController,
                      tabs: const [
                        Tab(text: '等级权益'),
                        Tab(text: '积分明细'),
                      ],
                    ),
                  ),
                ),
                // Tab内容
                SliverFillRemaining(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _buildBenefitsTab(theme),
                      _buildRecordsTab(theme),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildHeaderBackground(ThemeData theme) {
    final levelBenefit = _currentLevelBenefit;
    final nextLevel = _nextLevelBenefit;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            levelBenefit.color.withAlpha(230),
            levelBenefit.color.withAlpha(180),
            theme.primaryColor.withAlpha(150),
          ],
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 60, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 等级图标和名称
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white.withAlpha(51),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      levelBenefit.icon,
                      size: 40,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Lv.${levelBenefit.level} ${levelBenefit.name}',
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '当前积分: ${_balance?.points ?? 0}',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.white.withAlpha(204),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 24),
              // 升级进度
              if (nextLevel != null) ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '距离 Lv.${nextLevel.level} ${nextLevel.name}',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.white.withAlpha(204),
                      ),
                    ),
                    Text(
                      '${_balance?.points ?? 0}/${nextLevel.requiredPoints}',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: _balance?.levelProgress ?? 0,
                    backgroundColor: Colors.white.withAlpha(51),
                    valueColor: const AlwaysStoppedAnimation(Colors.white),
                    minHeight: 8,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '还需 ${nextLevel.requiredPoints - (_balance?.points ?? 0)} 积分升级',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.white.withAlpha(179),
                  ),
                ),
              ] else
                Text(
                  '🎉 已达最高等级',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.white.withAlpha(230),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBenefitsTab(ThemeData theme) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: levelBenefits.length,
      itemBuilder: (context, index) {
        final benefit = levelBenefits[index];
        final isCurrentLevel = benefit.level == (_balance?.level ?? 1);
        final isUnlocked = benefit.level <= (_balance?.level ?? 1);

        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: isCurrentLevel
                ? Border.all(color: benefit.color, width: 2)
                : null,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha(13),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            children: [
              // 等级头部
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isUnlocked
                      ? benefit.color.withAlpha(26)
                      : Colors.grey.shade50,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(14),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: isUnlocked
                            ? benefit.color
                            : Colors.grey.shade400,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(benefit.icon, size: 24, color: Colors.white),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                'Lv.${benefit.level} ${benefit.name}',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: isUnlocked
                                      ? benefit.color
                                      : Colors.grey.shade500,
                                ),
                              ),
                              if (isCurrentLevel) ...[
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: benefit.color,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: const Text(
                                    '当前',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w500,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '需要 ${benefit.requiredPoints} 积分',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (!isUnlocked)
                      Icon(
                        Icons.lock_outline_rounded,
                        color: Colors.grey.shade400,
                      ),
                  ],
                ),
              ),
              // 权益列表
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: benefit.benefits.map((b) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Row(
                        children: [
                          Icon(
                            isUnlocked
                                ? Icons.check_circle_rounded
                                : Icons.circle_outlined,
                            size: 18,
                            color: isUnlocked
                                ? Colors.green.shade500
                                : Colors.grey.shade400,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              b,
                              style: TextStyle(
                                fontSize: 14,
                                color: isUnlocked
                                    ? Colors.black87
                                    : Colors.grey.shade500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildRecordsTab(ThemeData theme) {
    if (_records.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.stars_rounded, size: 64, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text(
              '暂无积分记录',
              style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 8),
            Text(
              '完成订单即可获得积分',
              style: TextStyle(fontSize: 14, color: Colors.grey.shade500),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: _records.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final record = _records[index];
        final isPositive = record.points > 0;

        return ListTile(
          contentPadding: const EdgeInsets.symmetric(vertical: 8),
          leading: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: isPositive ? Colors.green.shade50 : Colors.orange.shade50,
              shape: BoxShape.circle,
            ),
            child: Icon(
              isPositive
                  ? Icons.add_circle_outline_rounded
                  : Icons.remove_circle_outline_rounded,
              color: isPositive
                  ? Colors.green.shade600
                  : Colors.orange.shade600,
            ),
          ),
          title: Text(
            record.reasonText,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
          ),
          subtitle: Text(
            _formatDate(record.createdAt),
            style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
          ),
          trailing: Text(
            '${isPositive ? '+' : ''}${record.points}',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: isPositive
                  ? Colors.green.shade600
                  : Colors.orange.shade600,
            ),
          ),
        );
      },
    );
  }

  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }
}

/// 粘性TabBar委托
class _StickyTabBarDelegate extends SliverPersistentHeaderDelegate {
  _StickyTabBarDelegate(this.tabBar);

  final TabBar tabBar;

  @override
  double get minExtent => tabBar.preferredSize.height;

  @override
  double get maxExtent => tabBar.preferredSize.height;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return Container(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: tabBar,
    );
  }

  @override
  bool shouldRebuild(_StickyTabBarDelegate oldDelegate) {
    return tabBar != oldDelegate.tabBar;
  }
}
