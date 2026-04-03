import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';

import '../models/app_models.dart';
import '../models/business_models.dart';
import '../services/platform_api.dart';
import '../services/chat_service.dart';
import '../utils/haptic_feedback.dart';
import 'pages/auth/identity_verification_page.dart';
import 'pages/wallet/wallet_page.dart';
import 'pages/report/report_form_page.dart';
import 'pages/points/points_member_page.dart';

class PlatformShell extends StatefulWidget {
  const PlatformShell({
    super.key,
    required this.api,
    this.initialRole = UserRole.boss,
  });

  final PlatformApi api;
  final UserRole initialRole;

  @override
  State<PlatformShell> createState() => _PlatformShellState();
}

class _PlatformShellState extends State<PlatformShell> {
  int navIndex = 0;
  late UserRole role;
  IdentityVerification verification = const IdentityVerification();
  String roomKeyword = '';
  String roomFilter = '全部';
  bool isLoading = true;
  String? loadError;

  // 高级筛选参数
  RangeValues priceRange = const RangeValues(0, 1000);
  int? minSeats;
  List<String> selectedTags = [];
  bool onlyAvailable = false;

  List<RoomItem> rooms = const [];
  List<RoomItem> joinedRooms = const [];
  List<CompanionItem> companions = const [];
  List<WalletFlowItem> walletFlows = const [];
  List<OrderItem> orders = const [];
  UserBalance? userBalance;
  final Map<String, List<String>> roomChats = {};
  Timer? companionRefreshTimer;

  bool get isVerified => verification.isVerified;

  String get verificationStatusLabel {
    if (verification.isVerified) {
      return '已完成';
    }
    if (verification.isPending) {
      return '审核中';
    }
    if (verification.isRejected) {
      return '已拒绝';
    }
    return '未完成';
  }

  String get verificationSummary {
    if (verification.isVerified) {
      return '已完成实名认证，可创建房间与使用资金功能';
    }
    if (verification.isPending) {
      return '实名认证审核中，审核通过后将自动解锁资金交易与创建房间';
    }
    if (verification.isRejected) {
      return '实名认证未通过，请重新提交资料后再创建房间';
    }
    return '手机号登录，实名认证后解锁资金交易与创建房间';
  }

  String get walletBalanceLabel {
    final available = userBalance?.availableBalance;
    if (available == null) {
      return '余额加载中';
    }
    return '余额 ¥${_formatAmount(available)}';
  }

  String get walletBalanceDetailLabel {
    final balance = userBalance;
    if (balance == null) {
      return '可用 / 冻结 余额加载中';
    }
    return '可用 ¥${_formatAmount(balance.availableBalance)} · 冻结 ¥${_formatAmount(balance.frozenBalance)}';
  }

  @override
  void initState() {
    super.initState();
    role = widget.initialRole;
    _loadDashboard();
    _startCompanionAutoRefresh();
  }

  @override
  void dispose() {
    companionRefreshTimer?.cancel();
    super.dispose();
  }

  void _startCompanionAutoRefresh() {
    companionRefreshTimer?.cancel();
    if (role != UserRole.boss) {
      return;
    }

    companionRefreshTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      if (!mounted || navIndex != 1) {
        return;
      }
      _loadRooms();
    });
  }

  Future<void> _loadDashboard() async {
    setState(() {
      isLoading = true;
      loadError = null;
    });
    try {
      final result = await Future.wait<dynamic>([
        widget.api.fetchRooms(
          role: role,
          keyword: roomKeyword,
          filter: roomFilter,
        ),
        widget.api.fetchJoinedRooms(),
        widget.api.fetchCompanions(),
        widget.api.fetchWalletFlows(),
        widget.api.fetchOrders(),
        widget.api.fetchVerificationStatus().catchError(
          (_) => const IdentityVerification(),
        ),
        widget.api
            .fetchUserBalance()
            .then<UserBalance?>((value) => value)
            .catchError((_) => null),
      ]);
      if (!mounted) {
        return;
      }
      setState(() {
        rooms = result[0] as List<RoomItem>;
        joinedRooms = result[1] as List<RoomItem>;
        companions = result[2] as List<CompanionItem>;
        walletFlows = result[3] as List<WalletFlowItem>;
        orders = result[4] as List<OrderItem>;
        verification = result[5] as IdentityVerification;
        userBalance = result[6] as UserBalance?;
        isLoading = false;
      });
    } catch (e) {
      if (!mounted) {
        return;
      }
      setState(() {
        loadError = e.toString();
        isLoading = false;
      });
    }
  }

  Future<void> _loadRooms() async {
    try {
      final roomFuture = widget.api.fetchRooms(
        role: role,
        keyword: roomKeyword,
        filter: roomFilter,
      );
      final joinedRoomsFuture = widget.api.fetchJoinedRooms();
      final companionsFuture = role == UserRole.boss
          ? widget.api.fetchCompanions()
          : Future.value(const <CompanionItem>[]);
      final result = await Future.wait<dynamic>([
        roomFuture,
        joinedRoomsFuture,
        companionsFuture,
      ]);
      if (!mounted) {
        return;
      }
      setState(() {
        rooms = result[0] as List<RoomItem>;
        joinedRooms = result[1] as List<RoomItem>;
        companions = result[2] as List<CompanionItem>;
      });
    } catch (e) {
      _showSnackBar('刷新房间失败：$e');
    }
  }

  Future<void> _refreshWalletBalance() async {
    try {
      final latestBalance = await widget.api.fetchUserBalance();
      if (!mounted) {
        return;
      }
      setState(() {
        userBalance = latestBalance;
      });
      HapticFeedbackUtil.selectionClick();
    } catch (_) {
      // 余额刷新失败时保留当前展示，避免打断用户流程
    }
  }

  Future<void> _refreshCurrentPage() async {
    if (navIndex == 0 || (role == UserRole.boss && navIndex == 1)) {
      await _loadRooms();
      return;
    }
    await _loadDashboard();
  }

  /// 检查是否有启用的高级筛选
  bool get _hasActiveFilters {
    return priceRange.start > 0 ||
        priceRange.end < 1000 ||
        minSeats != null ||
        selectedTags.isNotEmpty ||
        onlyAvailable;
  }

  /// 应用高级筛选后的房间列表
  List<RoomItem> get filteredRooms {
    var result = rooms;

    // 价格区间筛选
    if (priceRange.start > 0 || priceRange.end < 1000) {
      result = result.where((room) {
        return room.price >= priceRange.start && room.price <= priceRange.end;
      }).toList();
    }

    // 仅显示有空位
    if (onlyAvailable) {
      result = result.where((room) => room.seatsLeft > 0).toList();
    }

    // 标签筛选
    if (selectedTags.isNotEmpty) {
      result = result.where((room) {
        return selectedTags.any((tag) => room.tags.contains(tag));
      }).toList();
    }

    return result;
  }

  /// 显示高级筛选底部弹窗
  void _showAdvancedFilterSheet() {
    HapticFeedbackUtil.lightImpact();

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Container(
              height: MediaQuery.of(context).size.height * 0.7,
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Column(
                children: [
                  // 顶部拖动条
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Container(
                      width: 36,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  // 标题行
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          '高级筛选',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        TextButton(
                          onPressed: () {
                            HapticFeedbackUtil.lightImpact();
                            setSheetState(() {
                              priceRange = const RangeValues(0, 1000);
                              minSeats = null;
                              selectedTags = [];
                              onlyAvailable = false;
                            });
                          },
                          child: const Text('重置'),
                        ),
                      ],
                    ),
                  ),
                  const Divider(),
                  // 筛选内容
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // 价格区间
                          const Text(
                            '价格区间',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Text(
                                '¥${priceRange.start.toInt()}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              Expanded(
                                child: RangeSlider(
                                  values: priceRange,
                                  min: 0,
                                  max: 1000,
                                  divisions: 20,
                                  labels: RangeLabels(
                                    '¥${priceRange.start.toInt()}',
                                    '¥${priceRange.end.toInt()}',
                                  ),
                                  onChanged: (values) {
                                    HapticFeedbackUtil.selectionClick();
                                    setSheetState(() {
                                      priceRange = values;
                                    });
                                  },
                                ),
                              ),
                              Text(
                                '¥${priceRange.end.toInt()}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 24),

                          // 快捷筛选
                          const Text(
                            '快捷筛选',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 12),
                          SwitchListTile(
                            contentPadding: EdgeInsets.zero,
                            title: const Text('仅显示有空位房间'),
                            subtitle: const Text('隐藏已满员的房间'),
                            value: onlyAvailable,
                            onChanged: (value) {
                              HapticFeedbackUtil.selectionClick();
                              setSheetState(() {
                                onlyAvailable = value;
                              });
                            },
                          ),
                          const SizedBox(height: 16),

                          // 标签筛选
                          const Text(
                            '房间标签',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children:
                                [
                                  '新手友好',
                                  '高分段',
                                  '语音开黑',
                                  '女陪玩',
                                  '技术流',
                                  '轻松娱乐',
                                  '竞技上分',
                                  '紧急需求',
                                ].map((tag) {
                                  final isSelected = selectedTags.contains(tag);
                                  return FilterChip(
                                    label: Text(tag),
                                    selected: isSelected,
                                    onSelected: (selected) {
                                      HapticFeedbackUtil.selectionClick();
                                      setSheetState(() {
                                        if (selected) {
                                          selectedTags.add(tag);
                                        } else {
                                          selectedTags.remove(tag);
                                        }
                                      });
                                    },
                                  );
                                }).toList(),
                          ),
                          const SizedBox(height: 24),

                          // 筛选结果预览
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade50,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.info_outline_rounded,
                                  size: 20,
                                  color: Colors.grey.shade600,
                                ),
                                const SizedBox(width: 12),
                                Text(
                                  '当前筛选条件下有 ${_getPreviewCount()} 个房间',
                                  style: TextStyle(color: Colors.grey.shade700),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  // 底部按钮
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withAlpha(13),
                          blurRadius: 8,
                          offset: const Offset(0, -2),
                        ),
                      ],
                    ),
                    child: SafeArea(
                      child: Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => Navigator.pop(context),
                              child: const Text('取消'),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            flex: 2,
                            child: FilledButton(
                              onPressed: () {
                                HapticFeedbackUtil.mediumImpact();
                                setState(() {}); // 触发重建以应用筛选
                                Navigator.pop(context);
                              },
                              child: const Text('应用筛选'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  /// 获取当前筛选条件下的房间数量预览
  int _getPreviewCount() {
    return filteredRooms.length;
  }

  void openNeedConfirmSheet() {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (_) {
        return ListView(
          padding: const EdgeInsets.all(16),
          children: const [
            Text(
              '待确认需求清单',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 12),
            Text('1. 出资比例定义：显示的是用户需出资比例，还是房主出资比例。'),
            Text('2. 加入房间排队逻辑：是否支持直接排队、发起排队、自动排队。'),
            Text('3. 提现规则：手续费、到账时效、单日限额。'),
            Text('4. 举报审核流程：审核时效、处理条件、资金释放触发点。'),
            Text('5. 大额需求判定标准：金额阈值与订单类型。'),
            Text('6. 手机号免验证码登录上线节奏。'),
            SizedBox(height: 12),
            Text('说明：该版本为前端原型，后端接口与规则引擎待产品和服务端确认后接入。'),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (loadError != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('三角洲行动陪玩拼单平台')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline, size: 36),
                const SizedBox(height: 12),
                const Text('数据加载失败，请检查网络或接口状态。'),
                const SizedBox(height: 8),
                Text(
                  loadError!,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.black54),
                ),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: _loadDashboard,
                  child: const Text('重试加载'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final isWide = MediaQuery.of(context).size.width >= 900;
    final showCompanionTab = role == UserRole.boss;
    final pages = <Widget>[
      _buildRoomLobbyPage(context),
      if (showCompanionTab) _buildCompanionPage(),
      _buildOrdersPage(),
      _buildProfilePage(),
    ];
    final tabTitles = <String>['大厅', if (showCompanionTab) '陪玩', '订单', '我的'];
    final selectedNavIndex = navIndex.clamp(0, pages.length - 1);

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.white.withValues(alpha: 0.92),
        surfaceTintColor: Colors.transparent,
        leading: showCompanionTab && selectedNavIndex == 1
            ? const SizedBox.shrink()
            : IconButton(
                onPressed: _refreshCurrentPage,
                tooltip: '刷新',
                icon: const Icon(Icons.refresh_rounded),
              ),
        title: Text(
          tabTitles[selectedNavIndex],
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 17),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            onPressed: openNeedConfirmSheet,
            icon: const Icon(Icons.pending_actions_rounded),
            tooltip: '待确认项',
          ),
          if (role == UserRole.boss)
            IconButton(
              onPressed: _showCreateRoomDialog,
              icon: const Icon(Icons.add_circle_outline_rounded),
              tooltip: '创建房间',
            ),
          const SizedBox(width: 8),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFFDFDFE), Color(0xFFF3F4F8)],
          ),
        ),
        child: SafeArea(
          bottom: false,
          child: Row(
            children: [
              if (isWide)
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.78),
                      borderRadius: BorderRadius.circular(28),
                      border: Border.all(color: const Color(0xFFEAEAF0)),
                    ),
                    child: NavigationRail(
                      selectedIndex: selectedNavIndex,
                      onDestinationSelected: (index) {
                        HapticFeedbackUtil.selectionClick();
                        setState(() => navIndex = index);
                        if (showCompanionTab && index == 1) {
                          _loadRooms();
                        }
                      },
                      labelType: NavigationRailLabelType.all,
                      backgroundColor: Colors.transparent,
                      destinations: [
                        const NavigationRailDestination(
                          icon: Icon(Icons.meeting_room_outlined),
                          selectedIcon: Icon(Icons.meeting_room),
                          label: Text('大厅'),
                        ),
                        if (showCompanionTab)
                          const NavigationRailDestination(
                            icon: Icon(Icons.groups_outlined),
                            selectedIcon: Icon(Icons.groups),
                            label: Text('陪玩'),
                          ),
                        const NavigationRailDestination(
                          icon: Icon(Icons.receipt_long_outlined),
                          selectedIcon: Icon(Icons.receipt_long),
                          label: Text('订单'),
                        ),
                        const NavigationRailDestination(
                          icon: Icon(Icons.person_outline),
                          selectedIcon: Icon(Icons.person),
                          label: Text('我的'),
                        ),
                      ],
                    ),
                  ),
                ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: pages[selectedNavIndex],
                ),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: isWide
          ? null
          : Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.92),
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(color: const Color(0xFFEAEAF0)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 24,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: NavigationBar(
                  selectedIndex: selectedNavIndex,
                  onDestinationSelected: (index) {
                    HapticFeedbackUtil.selectionClick();
                    setState(() => navIndex = index);
                    if (showCompanionTab && index == 1) {
                      _loadRooms();
                    }
                  },
                  backgroundColor: Colors.transparent,
                  destinations: [
                    const NavigationDestination(
                      icon: Icon(Icons.meeting_room_outlined),
                      selectedIcon: Icon(Icons.meeting_room),
                      label: '大厅',
                    ),
                    if (showCompanionTab)
                      const NavigationDestination(
                        icon: Icon(Icons.groups_outlined),
                        selectedIcon: Icon(Icons.groups),
                        label: '陪玩',
                      ),
                    const NavigationDestination(
                      icon: Icon(Icons.receipt_long_outlined),
                      selectedIcon: Icon(Icons.receipt_long),
                      label: '订单',
                    ),
                    const NavigationDestination(
                      icon: Icon(Icons.person_outline),
                      selectedIcon: Icon(Icons.person),
                      label: '我的',
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildRoomLobbyPage(BuildContext context) {
    return ListView(
      children: [
        _pageHero(
          title: '大厅',
          subtitle: '用更少的信息噪声，快速找到合适的房间。',
          trailing: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _statBadge('在线房间', '${filteredRooms.length}'),
              _statBadge('当前身份', role == UserRole.boss ? '找陪玩' : '接单'),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: TextField(
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.search_rounded),
                  hintText: '搜索昵称、关键词、段位',
                ),
                onChanged: (value) {
                  setState(() => roomKeyword = value);
                  _loadRooms();
                },
              ),
            ),
            const SizedBox(width: 12),
            PopupMenuButton<String>(
              initialValue: roomFilter,
              onSelected: (value) {
                setState(() => roomFilter = value);
                _loadRooms();
              },
              itemBuilder: (context) => const [
                PopupMenuItem(value: '全部', child: Text('全部')),
                PopupMenuItem(value: '待加入', child: Text('待加入')),
                PopupMenuItem(value: '进行中', child: Text('进行中')),
                PopupMenuItem(value: '新手房间', child: Text('新手房间')),
                PopupMenuItem(value: '高分段', child: Text('高分段')),
                PopupMenuItem(value: '紧急', child: Text('紧急需求')),
              ],
              child: FilledButton.tonalIcon(
                onPressed: null,
                icon: const Icon(Icons.tune_rounded),
                label: Text(roomFilter),
              ),
            ),
            const SizedBox(width: 8),
            // 高级筛选按钮
            IconButton.filledTonal(
              onPressed: _showAdvancedFilterSheet,
              icon: Badge(
                isLabelVisible: _hasActiveFilters,
                smallSize: 8,
                child: const Icon(Icons.filter_list_rounded),
              ),
              tooltip: '高级筛选',
            ),
          ],
        ),
        const SizedBox(height: 12),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: ['全部', '待加入', '进行中', '新手房间', '高分段', '紧急']
                .map(
                  (item) => Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(item),
                      selected:
                          roomFilter == item ||
                          (item == '紧急' && roomFilter == '紧急需求'),
                      onSelected: (_) {
                        setState(
                          () => roomFilter = item == '紧急' ? '紧急需求' : item,
                        );
                        _loadRooms();
                      },
                    ),
                  ),
                )
                .toList(),
          ),
        ),
        if (joinedRooms.isNotEmpty) ...[
          const SizedBox(height: 16),
          _surfaceCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '当前账号已加入房间',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: joinedRooms
                      .map(
                        (room) => FilledButton.tonal(
                          onPressed: () => _openRoomDetail(room),
                          child: Text('查看详情: ${room.title}'),
                        ),
                      )
                      .toList(),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
        ],
        ...filteredRooms.map((room) {
          final statusColor = room.status == '进行中'
              ? const Color(0xFF34C759)
              : room.status == '紧急'
              ? const Color(0xFFFF3B30)
              : const Color(0xFF0071E3);

          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(28),
                border: Border.all(color: const Color(0xFFEAEAF0)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 24,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: InkWell(
                borderRadius: BorderRadius.circular(28),
                onTap: () => _openRoomDetail(room),
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  room.title,
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: -0.2,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '${room.id} · ${room.owner}',
                                  style: const TextStyle(
                                    color: Color(0xFF6B7280),
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          _statusBadge(room.status, statusColor),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _miniMetric('单价', '${room.price}'),
                          _miniMetric('剩余座位', '${room.seatsLeft}'),
                          _miniMetric('出资比例', room.contribution),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        room.note,
                        style: const TextStyle(
                          color: Color(0xFF3A3A3C),
                          height: 1.45,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: room.tags.map((e) => _tagPill(e)).toList(),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Text(
                            '服务费 ${room.commission}',
                            style: const TextStyle(
                              color: Color(0xFF6B7280),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const Spacer(),
                          FilledButton(
                            onPressed: () => _openRoomDetail(room),
                            child: Text(
                              role == UserRole.boss ? '查看房间' : '查看接单',
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildCompanionPage() {
    return ListView(
      children: [
        _pageHero(
          title: '陪玩',
          subtitle: '查看在线陪玩并邀请进入你已创建的房间。',
          trailing: _statBadge('在线人数', '${companions.length}'),
        ),
        const SizedBox(height: 16),
        if (role != UserRole.boss)
          _surfaceCard(child: const Text('当前为接单身份，仅找陪玩身份可发起邀请。'))
        else if (companions.isEmpty)
          _surfaceCard(child: const Text('当前没有其他在线账号，无法发起邀请。'))
        else
          ...companions.map(
            (companion) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _surfaceCard(
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            companion.name,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${companion.rank} · ${companion.pricePerGame}/局 · 评分 ${companion.rating.toStringAsFixed(1)}',
                            style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFF6B7280),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: companion.tags
                                .map((tag) => _tagPill(tag))
                                .toList(),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    FilledButton.tonal(
                      onPressed: () => _inviteCompanionFromLobby(companion),
                      child: const Text('邀请进房'),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildWalletPage() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 720;

        return ListView(
          children: [
            _pageHero(
              title: '钱包',
              subtitle: '统一查看余额、充值、提现和资金流向。',
              trailing: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _statBadge('可用余额', '12,560'),
                  _statBadge('积分余额', '2,340'),
                ],
              ),
            ),
            const SizedBox(height: 16),
            _surfaceCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '充值中心',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: ['5000', '8000', '12000', '32000', '自定义金额']
                        .map(
                          (amount) => FilledButton.tonal(
                            onPressed: () => _handleRechargeTap(amount),
                            child: Text(amount),
                          ),
                        )
                        .toList(),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      const Expanded(
                        child: Text(
                          '渠道：支付宝 / 微信支付',
                          style: TextStyle(color: Color(0xFF6B7280)),
                        ),
                      ),
                      TextButton(
                        onPressed: _showWithdrawDialog,
                        child: const Text('申请提现'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            _surfaceCard(
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '提现中心',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
                  ),
                  SizedBox(height: 8),
                  Text('支持原路提现至微信/支付宝账户。'),
                  SizedBox(height: 4),
                  Text('手续费、到账时效、单日限额待产品规则确认。'),
                ],
              ),
            ),
            const SizedBox(height: 12),
            _surfaceCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '资金明细',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 12),
                  if (compact)
                    Column(
                      children: walletFlows
                          .map(
                            (flow) => Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: _flowTile(flow),
                            ),
                          )
                          .toList(),
                    )
                  else
                    DataTable(
                      columns: const [
                        DataColumn(label: Text('类型')),
                        DataColumn(label: Text('金额')),
                        DataColumn(label: Text('状态')),
                        DataColumn(label: Text('时间')),
                      ],
                      rows: walletFlows
                          .map(
                            (flow) => DataRow(
                              cells: [
                                DataCell(Text(flow.type)),
                                DataCell(Text(flow.amount)),
                                DataCell(Text(flow.status)),
                                DataCell(Text(flow.time)),
                              ],
                            ),
                          )
                          .toList(),
                    ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildOrdersPage() {
    const reportTypes = ['骚扰与低俗内容', '实物送货等违规行为', '超时欠单', '平台不受理的其他违规订单'];

    return ListView(
      children: [
        _pageHero(
          title: '订单',
          subtitle: '用统一结构呈现每个订单的状态、进度和风控入口。',
          trailing: _statBadge('订单总数', '${orders.length}'),
        ),
        const SizedBox(height: 16),
        ...orders.map((order) {
          final progressColor = order.progress.contains('完成')
              ? const Color(0xFF34C759)
              : const Color(0xFFFF9500);

          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _surfaceCard(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    radius: 24,
                    backgroundColor: const Color(0x1A0071E3),
                    foregroundColor: const Color(0xFF0071E3),
                    child: const Icon(Icons.receipt_long_rounded),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          order.id,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '成交人员：${order.partner}',
                          style: const TextStyle(color: Color(0xFF3A3A3C)),
                        ),
                        Text(
                          '单价：${order.unitPrice} · 出资比例：${order.ratio}',
                          style: const TextStyle(color: Color(0xFF3A3A3C)),
                        ),
                        Text(
                          '房间：${order.room}',
                          style: const TextStyle(color: Color(0xFF3A3A3C)),
                        ),
                        const SizedBox(height: 10),
                        _statusBadge(order.progress, progressColor),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: '发起举报',
                    icon: const Icon(Icons.report_gmailerrorred_rounded),
                    onPressed: () {
                      HapticFeedbackUtil.lightImpact();
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ReportFormPage(
                            api: widget.api,
                            targetType: ReportType.order,
                            targetId: order.id,
                            targetName: '订单 ${order.id}',
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildProfilePage() {
    return ListView(
      children: [
        _pageHero(
          title: '我的',
          subtitle: '角色切换、等级体系和治理入口集中在这里。',
          trailing: _statBadge('实名认证', verificationStatusLabel),
        ),
        const SizedBox(height: 16),
        _surfaceCard(
          child: Row(
            children: [
              const CircleAvatar(
                radius: 26,
                backgroundColor: Color(0x1A0071E3),
                foregroundColor: Color(0xFF0071E3),
                child: Icon(Icons.person_rounded),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '玩家：风暴小刘',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      verificationSummary,
                      style: const TextStyle(color: Color(0xFF6B7280)),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _surfaceCard(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                '当前身份',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
              ),
              SegmentedButton<UserRole>(
                segments: const [
                  ButtonSegment<UserRole>(
                    value: UserRole.boss,
                    label: Text('找陪玩'),
                    icon: Icon(Icons.group_rounded),
                  ),
                  ButtonSegment<UserRole>(
                    value: UserRole.companion,
                    label: Text('接单'),
                    icon: Icon(Icons.sports_esports_rounded),
                  ),
                ],
                selected: <UserRole>{role},
                onSelectionChanged: (Set<UserRole> newSelection) async {
                  HapticFeedbackUtil.mediumImpact();
                  final nextRole = newSelection.first;
                  setState(() {
                    if (role != nextRole) {
                      if (nextRole == UserRole.companion) {
                        if (navIndex == 1) {
                          navIndex = 0;
                        } else if (navIndex == 2) {
                          navIndex = 1;
                        } else if (navIndex == 3) {
                          navIndex = 2;
                        }
                      } else {
                        if (navIndex == 1) {
                          navIndex = 2;
                        } else if (navIndex == 2) {
                          navIndex = 3;
                        }
                      }
                    }
                    role = nextRole;
                  });
                  await widget.api.updateUserRole(nextRole);
                  _startCompanionAutoRefresh();
                  await _loadRooms();
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        // 会员等级卡片 - 可点击进入详情
        GestureDetector(
          onTap: () {
            HapticFeedbackUtil.lightImpact();
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => PointsMemberPage(api: widget.api),
              ),
            );
          },
          child: _surfaceCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text(
                      '会员等级',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const Spacer(),
                    Icon(
                      Icons.chevron_right_rounded,
                      color: Colors.grey.shade400,
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFD700).withAlpha(51),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.star_rounded,
                        color: Color(0xFFFFD700),
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Lv.1 新手',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          '点击查看等级权益和积分明细',
                          style: TextStyle(
                            fontSize: 13,
                            color: Color(0xFF6B7280),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        _surfaceCard(
          child: Column(
            children: [
              ListTile(
                leading: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: const Color(0x1A0071E3),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.account_balance_wallet_rounded,
                    color: Color(0xFF0071E3),
                    size: 22,
                  ),
                ),
                title: const Text('我的钱包'),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(height: 2),
                    Text(
                      walletBalanceDetailLabel,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF9CA3AF),
                      ),
                    ),
                  ],
                ),
                trailing: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      walletBalanceLabel,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFFF59E0B),
                      ),
                    ),
                    const SizedBox(height: 2),
                    const Icon(
                      Icons.chevron_right_rounded,
                      color: Color(0xFF9CA3AF),
                      size: 20,
                    ),
                  ],
                ),
                onTap: () async {
                  HapticFeedbackUtil.lightImpact();
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => WalletPage(api: widget.api),
                    ),
                  );
                  await _refreshWalletBalance();
                },
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.gavel_rounded),
                title: const Text('信用体系与治理'),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () {
                  HapticFeedbackUtil.lightImpact();
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => Scaffold(
                        appBar: AppBar(title: const Text('信用体系与治理')),
                        body: Padding(
                          padding: const EdgeInsets.all(16),
                          child: _buildGovernancePage(),
                        ),
                      ),
                    ),
                  );
                },
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.verified_user_rounded),
                title: const Text('实名认证'),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () {
                  if (verification.isVerified) {
                    _showSnackBar('您已完成实名认证');
                    return;
                  }
                  _showIdentityRequiredDialog();
                },
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildGovernancePage() {
    return ListView(
      children: [
        _pageHero(
          title: '治理',
          subtitle: '把资金、审核和通知机制放在同一个规则框架里。',
          trailing: _statBadge('风险等级', '受控'),
        ),
        const SizedBox(height: 16),
        _surfaceCard(
          child: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '资金托管与结算',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
              ),
              SizedBox(height: 8),
              Text('老板支付 -> 平台冻结 -> 订单完成 -> 平台扣服务费(10%/20%) -> 陪玩到账'),
              SizedBox(height: 4),
              Text('异常场景：订单取消 / 举报通过后，资金原路退回老板账户。'),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _surfaceCard(
          child: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '举报与审核系统',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
              ),
              SizedBox(height: 8),
              Text('举报入口覆盖：房间、订单、个人主页。'),
              SizedBox(height: 4),
              Text('审核机制：人工 + AI 审核。'),
              SizedBox(height: 4),
              Text('聊天内容支持 AI 风控拦截，详情由服务端策略接入。'),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _surfaceCard(
          child: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '消息通知',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
              ),
              SizedBox(height: 8),
              Text('订单状态通知、资金到账通知、举报处理通知。'),
              SizedBox(height: 4),
              Text('移动端可接入推送，Web / 桌面端可接入站内通知。'),
            ],
          ),
        ),
      ],
    );
  }

  Widget _pageHero({
    required String title,
    required String subtitle,
    Widget? trailing,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.88),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: const Color(0xFFEAEAF0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.6,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: Color(0xFF6B7280),
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),
          if (trailing != null) ...[const SizedBox(width: 12), trailing],
        ],
      ),
    );
  }

  Widget _surfaceCard({required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: const Color(0xFFEAEAF0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _statBadge(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F5F7),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }

  Widget _statusBadge(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w700,
          fontSize: 12,
        ),
      ),
    );
  }

  Widget _miniMetric(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F5F7),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
          ),
          const SizedBox(height: 2),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }

  Widget _tagPill(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F5F7),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: Color(0xFF3A3A3C),
        ),
      ),
    );
  }

  Widget _flowTile(WalletFlowItem flow) {
    final isPositive = flow.amount.startsWith('+');
    final accent = isPositive
        ? const Color(0xFF34C759)
        : const Color(0xFFFF9500);

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF9F9FB),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFEAEAF0)),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        title: Text(
          flow.type,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(flow.time),
        trailing: SizedBox(
          width: 90,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                flow.amount,
                style: TextStyle(fontWeight: FontWeight.w700, color: accent),
              ),
              const SizedBox(height: 2),
              Text(
                flow.status,
                style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showIdentityRequiredDialog() {
    HapticFeedbackUtil.warning();
    final actionText = verification.isPending
        ? '查看进度'
        : verification.isVerified
        ? '我知道了'
        : '立即认证';
    final contentText = verification.isPending
        ? '您的实名认证资料已提交，当前状态为“审核中”。\n\n审核通过后，将自动解锁创建房间、资金交易和提现能力。'
        : verification.isVerified
        ? '当前账号已完成实名认证，您可以正常使用创建房间与资金相关功能。'
        : verification.isRejected
        ? '您的实名认证未通过，请根据驳回原因重新提交。\n\n认证流程：\n1. 填写真实姓名和身份证号\n2. 上传身份证正反面照片\n3. 上传手持身份证照片\n4. 手机号验证码确认'
        : '实名认证可保证资金安全，创建房间时必须先进行实名认证。\n\n认证流程：\n1. 填写真实姓名和身份证号\n2. 上传身份证正反面照片\n3. 上传手持身份证照片\n4. 手机号验证码确认';

    showDialog<void>(
      context: context,
      builder: (_) {
        return AlertDialog(
          icon: const Icon(
            Icons.verified_user_outlined,
            size: 48,
            color: Color(0xFF0071E3),
          ),
          title: const Text('需要实名认证'),
          content: Text(contentText),
          actions: [
            TextButton(
              onPressed: () {
                HapticFeedbackUtil.lightImpact();
                Navigator.pop(context);
              },
              child: const Text('稍后处理'),
            ),
            FilledButton(
              onPressed: () {
                HapticFeedbackUtil.mediumImpact();
                Navigator.pop(context);
                if (!verification.isVerified) {
                  _navigateToVerificationPage();
                }
              },
              child: Text(actionText),
            ),
          ],
        );
      },
    );
  }

  void _navigateToVerificationPage() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => IdentityVerificationPage(
          api: widget.api,
          initialVerification: verification,
          onVerificationComplete: (latest) {
            setState(() => verification = latest);
            HapticFeedbackUtil.success();
            _showSnackBar('实名认证已提交，等待审核');
          },
        ),
      ),
    );
  }

  Future<void> _showCreateRoomDialog() async {
    if (!isVerified) {
      _showIdentityRequiredDialog();
      return;
    }

    final titleController = TextEditingController();
    final priceController = TextEditingController(text: '320');
    final contributionController = TextEditingController(text: '老板60% / 陪玩40%');
    final seatsController = TextEditingController(text: '4');
    final noteController = TextEditingController();
    var serviceFeeRate = 10;

    try {
      final payload =
          await showDialog<
            ({
              String title,
              int unitPrice,
              String contribution,
              int seats,
              String note,
              int serviceFeeRate,
            })
          >(
            context: context,
            builder: (_) {
              return StatefulBuilder(
                builder: (context, setLocalState) {
                  return AlertDialog(
                    title: const Text('创建房间'),
                    content: SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          TextField(
                            controller: titleController,
                            decoration: const InputDecoration(
                              labelText: '房间名称',
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: priceController,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(labelText: '单价'),
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: contributionController,
                            decoration: const InputDecoration(
                              labelText: '出资比例',
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: seatsController,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: '人数上限',
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: noteController,
                            maxLines: 2,
                            decoration: const InputDecoration(labelText: '备注'),
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            '平台服务费率',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF6B7280),
                            ),
                          ),
                          const SizedBox(height: 8),
                          SegmentedButton<int>(
                            segments: const [
                              ButtonSegment<int>(value: 10, label: Text('10%')),
                              ButtonSegment<int>(value: 20, label: Text('20%')),
                            ],
                            selected: <int>{serviceFeeRate},
                            showSelectedIcon: false,
                            onSelectionChanged: (selection) {
                              setLocalState(
                                () => serviceFeeRate = selection.first,
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('取消'),
                      ),
                      FilledButton(
                        onPressed: () {
                          final title = titleController.text.trim();
                          final unitPrice = int.tryParse(
                            priceController.text.trim(),
                          );
                          final contribution = contributionController.text
                              .trim();
                          final seats = int.tryParse(
                            seatsController.text.trim(),
                          );
                          final note = noteController.text.trim();

                          if (title.isEmpty ||
                              contribution.isEmpty ||
                              unitPrice == null ||
                              unitPrice <= 0 ||
                              seats == null ||
                              seats <= 0) {
                            _showSnackBar('请完整填写房间信息');
                            return;
                          }

                          Navigator.pop(context, (
                            title: title,
                            unitPrice: unitPrice,
                            contribution: contribution,
                            seats: seats,
                            note: note,
                            serviceFeeRate: serviceFeeRate,
                          ));
                        },
                        child: const Text('确认创建'),
                      ),
                    ],
                  );
                },
              );
            },
          );

      if (payload == null) {
        return;
      }

      // 计算预估冻结金额
      final estimatedFrozen = payload.unitPrice * payload.seats;

      // 显示资金冻结确认对话框
      final confirmed = await _showFreezeConfirmDialog(
        unitPrice: payload.unitPrice,
        seats: payload.seats,
        estimatedFrozen: estimatedFrozen,
      );

      if (!confirmed) {
        return;
      }

      HapticFeedbackUtil.mediumImpact();

      final newRoom = await widget.api.createRoom(
        roomTitle: payload.title,
        unitPrice: payload.unitPrice,
        contribution: payload.contribution,
        seats: payload.seats,
        note: payload.note,
        serviceFeeRate: payload.serviceFeeRate,
        creatorRole: role,
      );
      setState(() {
        roomKeyword = '';
        roomFilter = '全部';
      });
      await _loadRooms();

      if (!mounted) {
        return;
      }

      // 自动打开新创建的房间详情
      _showSnackBar('房间已创建，即将进入房间...');
      await Future.delayed(const Duration(milliseconds: 500));
      if (mounted) {
        await _openRoomDetail(newRoom);
      }
    } catch (e) {
      _showSnackBar('创建房间失败：$e');
    } finally {
      titleController.dispose();
      priceController.dispose();
      contributionController.dispose();
      seatsController.dispose();
      noteController.dispose();
    }
  }

  /// 显示资金冻结确认对话框
  Future<bool> _showFreezeConfirmDialog({
    required int unitPrice,
    required int seats,
    required int estimatedFrozen,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
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
              Icons.account_balance_wallet_rounded,
              color: Colors.orange.shade700,
              size: 32,
            ),
          ),
          title: const Text('资金冻结确认'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '创建房间后，系统将预冻结部分资金用于订单结算保障：',
                style: TextStyle(fontSize: 14, color: Colors.black87),
              ),
              const SizedBox(height: 16),
              _buildFreezeInfoRow('单价', '¥$unitPrice'),
              _buildFreezeInfoRow('人数', '$seats 人'),
              const Divider(height: 24),
              _buildFreezeInfoRow(
                '预冻结金额',
                '¥$estimatedFrozen',
                isHighlight: true,
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.info_outline_rounded,
                      size: 18,
                      color: Colors.grey.shade600,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '冻结资金将在订单完成或取消后自动解冻。如余额不足，请先充值。',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                HapticFeedbackUtil.lightImpact();
                Navigator.pop(context, false);
              },
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () {
                HapticFeedbackUtil.mediumImpact();
                Navigator.pop(context, true);
              },
              child: const Text('确认冻结并创建'),
            ),
          ],
        );
      },
    );
    return result ?? false;
  }

  Widget _buildFreezeInfoRow(
    String label,
    String value, {
    bool isHighlight = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(fontSize: 14, color: Colors.grey.shade700),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: isHighlight ? 18 : 14,
              fontWeight: isHighlight ? FontWeight.bold : FontWeight.w500,
              color: isHighlight ? Colors.orange.shade700 : Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openRoomDetail(RoomItem room) async {
    List<RoomMemberItem> initialMembers = const [];
    try {
      initialMembers = await widget.api.fetchRoomMembers(roomId: room.id);
    } catch (_) {}
    if (!mounted) {
      return;
    }

    // 打开全屏聊天页面
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => _RoomChatPage(
          room: room,
          initialMembers: initialMembers,
          api: widget.api,
          currentUserRole: role,
          onRoomUpdated: () => _loadRooms(),
          showSnackBar: _showSnackBar,
        ),
      ),
    );
  }

  Future<void> _inviteCompanionFromLobby(CompanionItem companion) async {
    final candidateRooms = rooms
        .where((room) => room.status != '已完成' && room.seatsLeft > 0)
        .toList();

    if (candidateRooms.isEmpty) {
      _showSnackBar('请先创建可邀请的房间（未完成且有空位）');
      return;
    }

    String selectedRoomId = candidateRooms.first.id;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) {
        return StatefulBuilder(
          builder: (context, setLocalState) {
            return AlertDialog(
              title: Text('邀请 ${companion.name}'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('选择已创建房间后，陪玩会收到“待确认接单”邀请。'),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: selectedRoomId,
                    decoration: const InputDecoration(labelText: '目标房间'),
                    items: candidateRooms
                        .map(
                          (room) => DropdownMenuItem(
                            value: room.id,
                            child: Text('${room.title} (${room.id})'),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      if (value == null) {
                        return;
                      }
                      setLocalState(() => selectedRoomId = value);
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('取消'),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('确认邀请'),
                ),
              ],
            );
          },
        );
      },
    );

    if (confirm != true) {
      return;
    }

    try {
      await widget.api.inviteCompanion(
        roomId: selectedRoomId,
        companionId: companion.id,
      );
      await _loadDashboard();
      _showSnackBar('已邀请 ${companion.name} 加入房间');
    } catch (e) {
      _showSnackBar('邀请失败：$e');
    }
  }

  Future<void> _handleRechargeTap(String amountLabel) async {
    if (amountLabel == '自定义金额') {
      await _showRechargeDialog();
      return;
    }

    final amount = int.tryParse(amountLabel);
    if (amount == null) {
      _showSnackBar('无法识别充值金额：$amountLabel');
      return;
    }

    try {
      await widget.api.recharge(amount: amount, channel: '支付宝');
      await _loadDashboard();
      _showSnackBar('已提交 $amount 元充值申请');
    } catch (e) {
      _showSnackBar('充值失败：$e');
    }
  }

  Future<void> _showRechargeDialog() async {
    final controller = TextEditingController();
    try {
      final amount = await showDialog<int>(
        context: context,
        builder: (_) {
          return AlertDialog(
            title: const Text('自定义充值金额'),
            content: TextField(
              controller: controller,
              autofocus: true,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: '输入金额',
                hintText: '例如 1000',
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('取消'),
              ),
              FilledButton(
                onPressed: () {
                  final amount = int.tryParse(controller.text.trim());
                  if (amount == null || amount <= 0) {
                    _showSnackBar('请输入有效金额');
                    return;
                  }
                  Navigator.pop(context, amount);
                },
                child: const Text('提交充值'),
              ),
            ],
          );
        },
      );

      if (amount == null) {
        return;
      }

      await widget.api.recharge(amount: amount, channel: '支付宝');
      await _loadDashboard();
      _showSnackBar('已提交 $amount 元自定义充值申请');
    } catch (e) {
      _showSnackBar('充值失败：$e');
    } finally {
      controller.dispose();
    }
  }

  Future<void> _showWithdrawDialog() async {
    final controller = TextEditingController();
    try {
      final amount = await showDialog<int>(
        context: context,
        builder: (_) {
          return AlertDialog(
            title: const Text('申请提现'),
            content: TextField(
              controller: controller,
              autofocus: true,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: '提现金额',
                hintText: '例如 500',
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('取消'),
              ),
              FilledButton(
                onPressed: () {
                  final amount = int.tryParse(controller.text.trim());
                  if (amount == null || amount <= 0) {
                    _showSnackBar('请输入有效金额');
                    return;
                  }
                  Navigator.pop(context, amount);
                },
                child: const Text('提交申请'),
              ),
            ],
          );
        },
      );

      if (amount == null) {
        return;
      }

      await widget.api.withdraw(amount: amount);
      await _loadDashboard();
      _showSnackBar('已提交 $amount 元提现申请');
    } catch (e) {
      _showSnackBar('提现失败：$e');
    } finally {
      controller.dispose();
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  String _formatAmount(int amount) {
    if (amount >= 10000) {
      return '${(amount / 10000).toStringAsFixed(1)}万';
    }
    return amount.toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (match) => '${match[1]},',
    );
  }
}

/// 全屏聊天页面
class _RoomChatPage extends StatefulWidget {
  const _RoomChatPage({
    required this.room,
    required this.initialMembers,
    required this.api,
    required this.currentUserRole,
    required this.onRoomUpdated,
    required this.showSnackBar,
  });

  final RoomItem room;
  final List<RoomMemberItem> initialMembers;
  final PlatformApi api;
  final UserRole currentUserRole;
  final VoidCallback onRoomUpdated;
  final void Function(String) showSnackBar;

  @override
  State<_RoomChatPage> createState() => _RoomChatPageState();
}

class _RoomChatPageState extends State<_RoomChatPage> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final ChatService _chatService = ChatService();
  final List<ChatMessage> _messages = [];
  final Set<String> _messageIds = <String>{};
  Timer? _typingDebounce;

  late RoomItem _currentRoom;
  late List<RoomMemberItem> _members;
  bool _isProcessing = false;
  bool _isConnected = false;
  bool _isTyping = false;
  StreamSubscription<ChatMessage>? _messageSubscription;
  StreamSubscription<bool>? _connectionSubscription;

  @override
  void initState() {
    super.initState();
    _currentRoom = widget.room;
    _members = List<RoomMemberItem>.from(widget.initialMembers);
    _initChat();
  }

  Future<void> _initChat() async {
    // 监听消息流
    _messageSubscription = _chatService.messageStream.listen((message) {
      if (mounted) {
        setState(() {
          _mergeMessage(message);
        });
        _scrollToBottom();
      }
    });

    // 监听连接状态
    _connectionSubscription = _chatService.connectionStream.listen((connected) {
      if (mounted) {
        setState(() {
          _isConnected = connected;
        });
      }
    });

    // 连接聊天室
    try {
      await _chatService.connect(roomId: widget.room.id, token: 'mock-token');
      await _loadHistory();
      if (mounted) {
        setState(() {
          _isConnected = true;
        });
      }
    } catch (e) {
      print('聊天室连接失败: $e');
    }
  }

  Future<void> _loadHistory() async {
    try {
      final history = await _chatService.loadHistory(limit: 100);
      if (!mounted || history.isEmpty) {
        return;
      }

      setState(() {
        for (final message in history) {
          _mergeMessage(message);
        }
      });
      _scrollToBottom();
    } catch (e) {
      print('加载聊天历史失败: $e');
    }
  }

  void _mergeMessage(ChatMessage message) {
    final existingIndex = _messages.indexWhere(
      (item) => item.messageId == message.messageId,
    );
    if (existingIndex >= 0) {
      _messages[existingIndex] = message;
      return;
    }

    _messageIds.add(message.messageId);
    _messages.add(message);
    _messages.sort((a, b) => a.timestamp.compareTo(b.timestamp));
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  void dispose() {
    _typingDebounce?.cancel();
    _messageSubscription?.cancel();
    _connectionSubscription?.cancel();
    _chatService.dispose();
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    try {
      await _chatService.sendMessage(
        text,
        senderId: 'mock-user',
        senderName: widget.currentUserRole == UserRole.boss ? '老板' : '陪玩',
      );
      _messageController.clear();
      if (mounted) {
        setState(() {
          _isTyping = false;
        });
      }
    } catch (e) {
      widget.showSnackBar('发送失败: $e');
    }
  }

  void _onInputChanged(String value) {
    final hasText = value.trim().isNotEmpty;
    if (!mounted) {
      return;
    }

    setState(() {
      _isTyping = hasText;
    });

    _typingDebounce?.cancel();
    if (!hasText) {
      return;
    }

    _typingDebounce = Timer(const Duration(seconds: 2), () {
      if (!mounted) {
        return;
      }
      if (_messageController.text.trim().isEmpty) {
        setState(() {
          _isTyping = false;
        });
      }
    });
  }

  void _showRoomInfoDialog() {
    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Row(
            children: [
              const Icon(Icons.info_outline, color: Color(0xFF0071E3)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _currentRoom.title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildInfoRow('房间ID', _currentRoom.id),
                _buildInfoRow('房主', _currentRoom.owner),
                _buildInfoRow('状态', _currentRoom.status),
                _buildInfoRow('单价', '¥${_currentRoom.price}'),
                _buildInfoRow('剩余座位', '${_currentRoom.seatsLeft}'),
                _buildInfoRow('出资比例', _currentRoom.contribution),
                _buildInfoRow('服务费', '¥${_currentRoom.commission}'),
                if (_currentRoom.note.isNotEmpty)
                  _buildInfoRow('备注', _currentRoom.note),
                if (_currentRoom.tags.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: _currentRoom.tags
                          .map(
                            (tag) => Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFE5E7EB),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                tag,
                                style: const TextStyle(fontSize: 11),
                              ),
                            ),
                          )
                          .toList(),
                    ),
                  ),
                const Divider(height: 24),
                const Text(
                  '房间成员',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                if (_members.isEmpty)
                  const Text(
                    '暂无成员信息',
                    style: TextStyle(color: Color(0xFF6B7280), fontSize: 13),
                  )
                else
                  ..._members.map(
                    (member) => Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 14,
                            backgroundColor: member.role == 'boss'
                                ? const Color(0xFF0071E3)
                                : const Color(0xFF34C759),
                            child: Text(
                              member.userName.isNotEmpty
                                  ? member.userName[0]
                                  : '?',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  member.userName,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                Text(
                                  '${member.role == 'boss' ? '老板' : '陪玩'} · ${member.status}',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: Color(0xFF6B7280),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                const Divider(height: 24),
                const Text(
                  '操作',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    if (widget.currentUserRole == UserRole.companion)
                      _buildActionButton(
                        icon: Icons.verified_rounded,
                        label: '确认接单',
                        onPressed: _isProcessing ? null : _confirmOrder,
                        isPrimary: true,
                      ),
                    if (widget.currentUserRole == UserRole.boss)
                      _buildActionButton(
                        icon: Icons.delete_outline_rounded,
                        label: '解散房间',
                        onPressed: _isProcessing ? null : _dissolveRoom,
                        isDanger: true,
                      ),
                    _buildActionButton(
                      icon: Icons.link_rounded,
                      label: '复制链接',
                      onPressed: _copyRoomLink,
                    ),
                    _buildActionButton(
                      icon: Icons.group_add_rounded,
                      label: '邀请好友',
                      onPressed: _inviteFriend,
                    ),
                    _buildActionButton(
                      icon: Icons.task_alt_rounded,
                      label: '确认完成',
                      onPressed: _confirmComplete,
                      isPrimary: true,
                    ),
                    _buildActionButton(
                      icon: Icons.report_rounded,
                      label: '举报',
                      onPressed: _report,
                    ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('关闭'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 72,
            child: Text(
              label,
              style: const TextStyle(fontSize: 13, color: Color(0xFF6B7280)),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    VoidCallback? onPressed,
    bool isPrimary = false,
    bool isDanger = false,
  }) {
    if (isPrimary) {
      return FilledButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 16),
        label: Text(label, style: const TextStyle(fontSize: 12)),
        style: FilledButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        ),
      );
    }
    if (isDanger) {
      return FilledButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 16),
        label: Text(label, style: const TextStyle(fontSize: 12)),
        style: FilledButton.styleFrom(
          backgroundColor: Colors.red[400],
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        ),
      );
    }
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 16),
      label: Text(label, style: const TextStyle(fontSize: 12)),
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
    );
  }

  Future<void> _confirmOrder() async {
    try {
      setState(() => _isProcessing = true);
      final updatedRoom = await widget.api.confirmCompanionOrder(
        roomId: _currentRoom.id,
      );
      final updatedMembers = await widget.api.fetchRoomMembers(
        roomId: _currentRoom.id,
      );
      widget.onRoomUpdated();
      setState(() {
        _currentRoom = updatedRoom;
        _members = List<RoomMemberItem>.from(updatedMembers);
      });
      widget.showSnackBar('接单已确认');
      if (mounted) Navigator.of(context).pop(); // 关闭信息弹窗
    } catch (e) {
      widget.showSnackBar('确认接单失败：$e');
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _dissolveRoom() async {
    try {
      setState(() => _isProcessing = true);
      await widget.api.dissolveRoom(roomId: _currentRoom.id);
      widget.onRoomUpdated();
      widget.showSnackBar('房间已解散');
      if (mounted) {
        Navigator.of(context).pop(); // 关闭信息弹窗
        Navigator.of(context).pop(); // 返回上一页
      }
    } catch (e) {
      widget.showSnackBar('解散房间失败：$e');
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _copyRoomLink() async {
    final link = 'https://delta.example/rooms/${_currentRoom.id}';
    await Clipboard.setData(ClipboardData(text: link));
    widget.showSnackBar('邀请链接已复制：$link');
  }

  Future<void> _inviteFriend() async {
    final message =
        '邀请你加入房间「${_currentRoom.title}」，链接：https://delta.example/rooms/${_currentRoom.id}';
    await Clipboard.setData(ClipboardData(text: message));
    widget.showSnackBar('邀请文案已复制，可直接发送给好友');
  }

  /// 分享房间 - iOS系统分享Sheet
  Future<void> _shareRoom() async {
    HapticFeedbackUtil.lightImpact();

    // 计算总座位数
    final totalSeats = _currentRoom.seatsLeft + _members.length;

    final shareContent =
        '''
🎮 三角洲行动 - 陪玩拼单

📌 房间：${_currentRoom.title}
💰 单价：¥${_currentRoom.price}
👥 人数：${_members.length}/$totalSeats人
📊 状态：${_currentRoom.status}

👉 点击加入：https://delta.example/rooms/${_currentRoom.id}
''';

    // TODO: 实际项目中使用 share_plus 包
    // await Share.share(shareContent, subject: '邀请你加入陪玩房间');

    // 暂时使用复制到剪贴板
    await Clipboard.setData(ClipboardData(text: shareContent));

    if (!mounted) return;

    // 显示分享成功提示
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(20),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 20),
                Icon(
                  Icons.check_circle_rounded,
                  color: Colors.green.shade500,
                  size: 48,
                ),
                const SizedBox(height: 16),
                const Text(
                  '分享内容已复制',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                Text(
                  '可以粘贴到微信、QQ等应用分享给好友',
                  style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('知道了'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _confirmComplete() async {
    try {
      await widget.api.confirmRoomCompleted(roomId: _currentRoom.id);
      widget.onRoomUpdated();
      widget.showSnackBar('订单已确认完成，触发结算（原型）');
    } catch (e) {
      widget.showSnackBar('确认完成失败：$e');
    }
  }

  Future<void> _report() async {
    HapticFeedbackUtil.lightImpact();
    // 使用新的举报表单页面
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ReportFormPage(
          api: widget.api,
          targetType: ReportType.room,
          targetId: _currentRoom.id,
          targetName: _currentRoom.title,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isBoss = widget.currentUserRole == UserRole.boss;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _currentRoom.title,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            Text(
              '${_members.length}人 · ${_currentRoom.status}',
              style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.share_rounded),
            tooltip: '分享房间',
            onPressed: _shareRoom,
          ),
          IconButton(
            icon: const Icon(Icons.info_outline),
            tooltip: '房间信息',
            onPressed: _showRoomInfoDialog,
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // 连接状态提示
            if (!_isConnected)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                color: Colors.orange[100],
                child: Row(
                  children: [
                    SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.orange[800],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '聊天室连接中...（完整版需要后端WS服务支持）',
                      style: TextStyle(fontSize: 12, color: Colors.orange[800]),
                    ),
                  ],
                ),
              ),

            if (_isConnected)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 6,
                ),
                color: const Color(0xFFF2F8FF),
                child: Text(
                  _isTyping ? '正在输入消息…' : '已连接，可实时收发消息',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF2563EB),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),

            // 聊天消息列表
            Expanded(
              child: _messages.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.chat_bubble_outline,
                            size: 64,
                            color: Colors.grey[300],
                          ),
                          const SizedBox(height: 16),
                          Text(
                            '暂无消息',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[500],
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            isBoss ? '向陪玩发送消息开始沟通' : '向老板发送消息开始沟通',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[400],
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.all(16),
                      itemCount: _messages.length,
                      itemBuilder: (context, index) {
                        final message = _messages[index];
                        final isMe = message.senderId == 'mock-user';
                        final isSystem = message.isSystemMessage;

                        // 系统消息居中显示
                        if (isSystem) {
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            child: Center(
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.grey[200],
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  message.content,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey[600],
                                  ),
                                ),
                              ),
                            ),
                          );
                        }

                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Row(
                            mainAxisAlignment: isMe
                                ? MainAxisAlignment.end
                                : MainAxisAlignment.start,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (!isMe) ...[
                                CircleAvatar(
                                  radius: 16,
                                  backgroundColor: const Color(0xFF34C759),
                                  child: Text(
                                    message.senderName.isNotEmpty
                                        ? message.senderName[0]
                                        : '?',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                              ],
                              Flexible(
                                child: Column(
                                  crossAxisAlignment: isMe
                                      ? CrossAxisAlignment.end
                                      : CrossAxisAlignment.start,
                                  children: [
                                    if (!isMe)
                                      Padding(
                                        padding: const EdgeInsets.only(
                                          bottom: 4,
                                        ),
                                        child: Text(
                                          message.senderName,
                                          style: const TextStyle(
                                            fontSize: 11,
                                            color: Color(0xFF6B7280),
                                          ),
                                        ),
                                      ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 14,
                                        vertical: 10,
                                      ),
                                      decoration: BoxDecoration(
                                        color: isMe
                                            ? const Color(0xFF0071E3)
                                            : const Color(0xFFF5F5F7),
                                        borderRadius: BorderRadius.only(
                                          topLeft: const Radius.circular(16),
                                          topRight: const Radius.circular(16),
                                          bottomLeft: Radius.circular(
                                            isMe ? 16 : 4,
                                          ),
                                          bottomRight: Radius.circular(
                                            isMe ? 4 : 16,
                                          ),
                                        ),
                                      ),
                                      child: Text(
                                        message.content,
                                        style: TextStyle(
                                          fontSize: 14,
                                          color: isMe
                                              ? Colors.white
                                              : Colors.black87,
                                        ),
                                      ),
                                    ),
                                    Padding(
                                      padding: const EdgeInsets.only(top: 4),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(
                                            _formatTime(message.timestamp),
                                            style: const TextStyle(
                                              fontSize: 10,
                                              color: Color(0xFF9CA3AF),
                                            ),
                                          ),
                                          if (isMe) ...[
                                            const SizedBox(width: 6),
                                            Text(
                                              message.deliveryStatus ==
                                                      'pending'
                                                  ? '发送中'
                                                  : '已发送',
                                              style: TextStyle(
                                                fontSize: 10,
                                                color:
                                                    message.deliveryStatus ==
                                                        'pending'
                                                    ? const Color(0xFFEA580C)
                                                    : const Color(0xFF22C55E),
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (isMe) ...[
                                const SizedBox(width: 8),
                                CircleAvatar(
                                  radius: 16,
                                  backgroundColor: const Color(0xFF0071E3),
                                  child: Text(
                                    isBoss ? '老' : '陪',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        );
                      },
                    ),
            ),

            // 消息输入框
            Container(
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                top: 12,
                bottom: MediaQuery.of(context).viewInsets.bottom > 0
                    ? 12
                    : 12 + MediaQuery.of(context).padding.bottom,
              ),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 10,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _messageController,
                      decoration: InputDecoration(
                        hintText: '输入消息...',
                        hintStyle: const TextStyle(color: Color(0xFF9CA3AF)),
                        filled: true,
                        fillColor: const Color(0xFFF5F5F7),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      textInputAction: TextInputAction.send,
                      onChanged: _onInputChanged,
                      onSubmitted: (_) => _sendMessage(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    onPressed: () => _sendMessage(),
                    icon: const Icon(Icons.send_rounded),
                    style: IconButton.styleFrom(
                      backgroundColor: const Color(0xFF0071E3),
                      foregroundColor: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    if (time.year == now.year &&
        time.month == now.month &&
        time.day == now.day) {
      return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
    }
    return '${time.month}/${time.day} ${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }
}
