import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../services/platform_api.dart';
import '../../../utils/haptic_feedback.dart';

/// 举报类型
enum ReportType {
  user('用户', Icons.person_off_rounded),
  room('房间', Icons.meeting_room_outlined),
  order('订单', Icons.receipt_long_outlined),
  chat('聊天消息', Icons.chat_bubble_outline_rounded);

  const ReportType(this.label, this.icon);
  final String label;
  final IconData icon;
}

/// 举报原因
class ReportReason {
  const ReportReason({
    required this.id,
    required this.label,
    required this.description,
  });

  final String id;
  final String label;
  final String description;
}

/// 预定义举报原因列表
const List<ReportReason> reportReasons = [
  ReportReason(id: 'fraud', label: '诈骗行为', description: '虚假充值、骗取钱财、冒充客服等'),
  ReportReason(id: 'harassment', label: '骚扰辱骂', description: '言语侮辱、人身攻击、频繁骚扰等'),
  ReportReason(
    id: 'service_quality',
    label: '服务质量差',
    description: '挂机、消极游戏、技术明显不符等',
  ),
  ReportReason(
    id: 'false_advertising',
    label: '虚假宣传',
    description: '段位虚标、技术水平不实等',
  ),
  ReportReason(
    id: 'inappropriate_content',
    label: '不当内容',
    description: '色情暗示、政治敏感、违法信息等',
  ),
  ReportReason(
    id: 'account_trading',
    label: '账号交易',
    description: '私下交易账号、代练账号等',
  ),
  ReportReason(id: 'cheating', label: '使用外挂', description: '使用作弊软件、辅助工具等'),
  ReportReason(id: 'other', label: '其他原因', description: '不在以上分类的其他违规行为'),
];

/// 举报表单页面
class ReportFormPage extends StatefulWidget {
  const ReportFormPage({
    super.key,
    required this.api,
    this.targetType,
    this.targetId,
    this.targetName,
  });

  final PlatformApi api;
  final ReportType? targetType;
  final String? targetId;
  final String? targetName;

  @override
  State<ReportFormPage> createState() => _ReportFormPageState();
}

class _ReportFormPageState extends State<ReportFormPage> {
  ReportType? _selectedType;
  ReportReason? _selectedReason;
  final _descriptionController = TextEditingController();
  final List<String> _evidenceUrls = [];
  bool _isSubmitting = false;
  bool _agreedToRules = false;

  // 最大证据图片数量
  static const int maxEvidenceCount = 6;
  // 描述最大字数
  static const int maxDescriptionLength = 500;

  @override
  void initState() {
    super.initState();
    _selectedType = widget.targetType;
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    super.dispose();
  }

  bool get _canSubmit {
    return _selectedType != null &&
        _selectedReason != null &&
        _agreedToRules &&
        !_isSubmitting;
  }

  Future<void> _pickEvidence() async {
    if (_evidenceUrls.length >= maxEvidenceCount) {
      _showSnackBar('最多上传${maxEvidenceCount}张证据图片');
      return;
    }

    HapticFeedbackUtil.lightImpact();

    // TODO: 实际项目中使用 image_picker
    // 模拟选择图片
    await Future.delayed(const Duration(milliseconds: 300));
    setState(() {
      _evidenceUrls.add(
        'https://via.placeholder.com/200?text=证据${_evidenceUrls.length + 1}',
      );
    });
    _showSnackBar('已添加证据图片');
  }

  void _removeEvidence(int index) {
    HapticFeedbackUtil.lightImpact();
    setState(() {
      _evidenceUrls.removeAt(index);
    });
  }

  Future<void> _submitReport() async {
    if (!_canSubmit) return;

    HapticFeedbackUtil.mediumImpact();

    setState(() {
      _isSubmitting = true;
    });

    try {
      await widget.api.submitReport(
        targetType: _selectedType!.name,
        targetId: widget.targetId ?? 'unknown',
        reason: _selectedReason!.id,
        description: _descriptionController.text.trim().isNotEmpty
            ? _descriptionController.text.trim()
            : null,
        evidenceUrls: _evidenceUrls.isNotEmpty ? _evidenceUrls : null,
      );

      HapticFeedbackUtil.notificationSuccess();

      if (!mounted) return;

      // 显示成功对话框
      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          icon: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.green.shade50,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.check_circle_rounded,
              color: Colors.green.shade600,
              size: 48,
            ),
          ),
          title: const Text('举报已提交'),
          content: const Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '感谢您的反馈，我们会在24小时内进行审核。',
                style: TextStyle(fontSize: 14, color: Colors.black87),
              ),
              SizedBox(height: 12),
              Text(
                '您可以在"我的举报"中查看处理进度。',
                style: TextStyle(fontSize: 13, color: Colors.black54),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(); // 关闭对话框
                Navigator.of(context).pop(); // 返回上一页
              },
              child: const Text('知道了'),
            ),
          ],
        ),
      );
    } catch (e) {
      HapticFeedbackUtil.notificationError();
      _showSnackBar('提交失败: ${e.toString()}');
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('举报'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => _MyReportsPage(api: widget.api),
                ),
              );
            },
            child: const Text('我的举报'),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 举报对象信息（如果有）
            if (widget.targetName != null) ...[
              _buildTargetInfoCard(theme),
              const SizedBox(height: 20),
            ],

            // 举报类型选择
            _buildSectionTitle(theme, '举报类型'),
            const SizedBox(height: 12),
            _buildTypeSelector(theme),
            const SizedBox(height: 24),

            // 举报原因选择
            _buildSectionTitle(theme, '举报原因'),
            const SizedBox(height: 12),
            _buildReasonSelector(theme),
            const SizedBox(height: 24),

            // 详细描述
            _buildSectionTitle(theme, '详细描述（可选）'),
            const SizedBox(height: 12),
            _buildDescriptionInput(theme),
            const SizedBox(height: 24),

            // 证据上传
            _buildSectionTitle(theme, '上传证据（可选）'),
            const SizedBox(height: 8),
            Text(
              '最多上传${maxEvidenceCount}张截图作为证据',
              style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 12),
            _buildEvidenceUploader(theme),
            const SizedBox(height: 24),

            // 举报须知
            _buildReportRules(theme),
            const SizedBox(height: 24),

            // 提交按钮
            _buildSubmitButton(theme),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildTargetInfoCard(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.orange.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orange.shade200),
      ),
      child: Row(
        children: [
          Icon(
            widget.targetType?.icon ?? Icons.report_outlined,
            color: Colors.orange.shade700,
            size: 32,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '举报对象',
                  style: TextStyle(fontSize: 12, color: Colors.orange.shade700),
                ),
                const SizedBox(height: 2),
                Text(
                  widget.targetName ?? '未知',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(ThemeData theme, String title) {
    return Text(
      title,
      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
    );
  }

  Widget _buildTypeSelector(ThemeData theme) {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: ReportType.values.map((type) {
        final isSelected = _selectedType == type;
        final isDisabled =
            widget.targetType != null && widget.targetType != type;

        return GestureDetector(
          onTap: isDisabled
              ? null
              : () {
                  HapticFeedbackUtil.selectionClick();
                  setState(() {
                    _selectedType = type;
                  });
                },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: isSelected
                  ? theme.primaryColor.withAlpha(26)
                  : isDisabled
                  ? Colors.grey.shade100
                  : Colors.grey.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSelected
                    ? theme.primaryColor
                    : isDisabled
                    ? Colors.grey.shade200
                    : Colors.grey.shade300,
                width: isSelected ? 2 : 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  type.icon,
                  size: 20,
                  color: isSelected
                      ? theme.primaryColor
                      : isDisabled
                      ? Colors.grey.shade400
                      : Colors.grey.shade700,
                ),
                const SizedBox(width: 8),
                Text(
                  type.label,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: isSelected
                        ? FontWeight.w600
                        : FontWeight.normal,
                    color: isSelected
                        ? theme.primaryColor
                        : isDisabled
                        ? Colors.grey.shade400
                        : Colors.black87,
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildReasonSelector(ThemeData theme) {
    return Column(
      children: reportReasons.map((reason) {
        final isSelected = _selectedReason?.id == reason.id;

        return GestureDetector(
          onTap: () {
            HapticFeedbackUtil.selectionClick();
            setState(() {
              _selectedReason = reason;
            });
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isSelected
                  ? theme.primaryColor.withAlpha(26)
                  : Colors.grey.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSelected ? theme.primaryColor : Colors.grey.shade200,
                width: isSelected ? 2 : 1,
              ),
            ),
            child: Row(
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isSelected ? theme.primaryColor : Colors.transparent,
                    border: Border.all(
                      color: isSelected
                          ? theme.primaryColor
                          : Colors.grey.shade400,
                      width: 2,
                    ),
                  ),
                  child: isSelected
                      ? const Icon(Icons.check, size: 16, color: Colors.white)
                      : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        reason.label,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: isSelected
                              ? FontWeight.w600
                              : FontWeight.w500,
                          color: isSelected
                              ? theme.primaryColor
                              : Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        reason.description,
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildDescriptionInput(ThemeData theme) {
    return TextField(
      controller: _descriptionController,
      maxLines: 5,
      maxLength: maxDescriptionLength,
      inputFormatters: [LengthLimitingTextInputFormatter(maxDescriptionLength)],
      decoration: InputDecoration(
        hintText: '请详细描述您遇到的问题，以便我们更好地处理...',
        hintStyle: TextStyle(color: Colors.grey.shade500),
        filled: true,
        fillColor: Colors.grey.shade50,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: theme.primaryColor, width: 2),
        ),
      ),
    );
  }

  Widget _buildEvidenceUploader(ThemeData theme) {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        // 已上传的证据
        ..._evidenceUrls.asMap().entries.map((entry) {
          return Stack(
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  color: Colors.grey.shade200,
                  image: DecorationImage(
                    image: NetworkImage(entry.value),
                    fit: BoxFit.cover,
                  ),
                ),
              ),
              Positioned(
                top: -6,
                right: -6,
                child: GestureDetector(
                  onTap: () => _removeEvidence(entry.key),
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.close,
                      size: 14,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          );
        }),

        // 添加按钮
        if (_evidenceUrls.length < maxEvidenceCount)
          GestureDetector(
            onTap: _pickEvidence,
            child: Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: Colors.grey.shade300,
                  style: BorderStyle.solid,
                ),
                color: Colors.grey.shade50,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.add_photo_alternate_outlined,
                    size: 28,
                    color: Colors.grey.shade500,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '添加',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildReportRules(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.info_outline_rounded,
                size: 18,
                color: Colors.grey.shade700,
              ),
              const SizedBox(width: 8),
              const Text(
                '举报须知',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            '• 请如实填写举报内容，恶意举报将影响您的信用积分\n'
            '• 上传的截图证据将有助于我们快速处理\n'
            '• 我们会在24小时内完成审核并反馈结果\n'
            '• 举报内容仅用于平台治理，不会泄露给第三方',
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey.shade700,
              height: 1.6,
            ),
          ),
          const SizedBox(height: 16),
          GestureDetector(
            onTap: () {
              HapticFeedbackUtil.selectionClick();
              setState(() {
                _agreedToRules = !_agreedToRules;
              });
            },
            child: Row(
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(4),
                    color: _agreedToRules
                        ? theme.primaryColor
                        : Colors.transparent,
                    border: Border.all(
                      color: _agreedToRules
                          ? theme.primaryColor
                          : Colors.grey.shade400,
                      width: 2,
                    ),
                  ),
                  child: _agreedToRules
                      ? const Icon(Icons.check, size: 16, color: Colors.white)
                      : null,
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text('我已阅读并同意上述举报须知', style: TextStyle(fontSize: 14)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubmitButton(ThemeData theme) {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: ElevatedButton(
        onPressed: _canSubmit ? _submitReport : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: theme.primaryColor,
          disabledBackgroundColor: Colors.grey.shade300,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 0,
        ),
        child: _isSubmitting
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation(Colors.white),
                ),
              )
            : const Text(
                '提交举报',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
      ),
    );
  }
}

/// 我的举报列表页面
class _MyReportsPage extends StatefulWidget {
  const _MyReportsPage({required this.api});

  final PlatformApi api;

  @override
  State<_MyReportsPage> createState() => _MyReportsPageState();
}

class _MyReportsPageState extends State<_MyReportsPage> {
  bool _isLoading = true;
  List<dynamic> _reports = [];

  @override
  void initState() {
    super.initState();
    _loadReports();
  }

  Future<void> _loadReports() async {
    try {
      final reports = await widget.api.fetchMyReports();
      if (mounted) {
        setState(() {
          _reports = reports;
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
        ).showSnackBar(SnackBar(content: Text('加载失败: ${e.toString()}')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('我的举报')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _reports.isEmpty
          ? _buildEmptyState()
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _reports.length,
              itemBuilder: (context, index) {
                return _buildReportItem(_reports[index]);
              },
            ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.inbox_rounded, size: 64, color: Colors.grey.shade400),
          const SizedBox(height: 16),
          Text(
            '暂无举报记录',
            style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
          ),
        ],
      ),
    );
  }

  Widget _buildReportItem(dynamic report) {
    final status = report.status ?? 'pending';
    final statusInfo = _getStatusInfo(status);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(13),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: statusInfo['color'].withAlpha(26),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  statusInfo['label'],
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: statusInfo['color'],
                  ),
                ),
              ),
              const Spacer(),
              Text(
                report.createdAt ?? '',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            '举报原因: ${report.reason ?? '未知'}',
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
          ),
          if (report.description != null && report.description.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              report.description,
              style: TextStyle(fontSize: 14, color: Colors.grey.shade700),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
          if (report.result != null && report.result.isNotEmpty) ...[
            const SizedBox(height: 12),
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
                    Icons.comment_outlined,
                    size: 18,
                    color: Colors.grey.shade600,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '处理结果',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          report.result,
                          style: const TextStyle(fontSize: 14),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Map<String, dynamic> _getStatusInfo(String status) {
    switch (status) {
      case 'pending':
        return {'label': '待处理', 'color': Colors.orange};
      case 'processing':
        return {'label': '处理中', 'color': Colors.blue};
      case 'resolved':
        return {'label': '已处理', 'color': Colors.green};
      case 'rejected':
        return {'label': '已驳回', 'color': Colors.red};
      default:
        return {'label': '未知', 'color': Colors.grey};
    }
  }
}
