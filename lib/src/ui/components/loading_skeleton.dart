import 'package:flutter/material.dart';

/// 骨架屏加载效果组件
class LoadingSkeleton extends StatefulWidget {
  const LoadingSkeleton({
    super.key,
    required this.width,
    required this.height,
    this.borderRadius = 8,
  });

  final double width;
  final double height;
  final double borderRadius;

  @override
  State<LoadingSkeleton> createState() => _LoadingSkeletonState();
}

class _LoadingSkeletonState extends State<LoadingSkeleton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat();
    _animation = Tween<double>(
      begin: -2,
      end: 2,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(widget.borderRadius),
            gradient: LinearGradient(
              begin: Alignment(-1 + _animation.value, 0),
              end: Alignment(1 + _animation.value, 0),
              colors: const [
                Color(0xFFE5E7EB),
                Color(0xFFF3F4F6),
                Color(0xFFE5E7EB),
              ],
              stops: const [0.0, 0.5, 1.0],
            ),
          ),
        );
      },
    );
  }
}

/// 房间卡片骨架屏
class RoomCardSkeleton extends StatelessWidget {
  const RoomCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: const Color(0xFFEAEAF0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    LoadingSkeleton(width: 160, height: 20),
                    SizedBox(height: 8),
                    LoadingSkeleton(width: 100, height: 14),
                  ],
                ),
              ),
              LoadingSkeleton(width: 60, height: 28, borderRadius: 14),
            ],
          ),
          const SizedBox(height: 14),
          const Row(
            children: [
              LoadingSkeleton(width: 70, height: 44, borderRadius: 18),
              SizedBox(width: 8),
              LoadingSkeleton(width: 70, height: 44, borderRadius: 18),
              SizedBox(width: 8),
              LoadingSkeleton(width: 70, height: 44, borderRadius: 18),
            ],
          ),
          const SizedBox(height: 12),
          const LoadingSkeleton(width: double.infinity, height: 40),
          const SizedBox(height: 12),
          const Row(
            children: [
              LoadingSkeleton(width: 50, height: 28, borderRadius: 14),
              SizedBox(width: 8),
              LoadingSkeleton(width: 50, height: 28, borderRadius: 14),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              const LoadingSkeleton(width: 80, height: 16),
              const Spacer(),
              LoadingSkeleton(width: 90, height: 40, borderRadius: 20),
            ],
          ),
        ],
      ),
    );
  }
}

/// 列表骨架屏
class ListSkeleton extends StatelessWidget {
  const ListSkeleton({super.key, this.itemCount = 3, this.itemBuilder});

  final int itemCount;
  final Widget Function(BuildContext, int)? itemBuilder;

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      physics: const NeverScrollableScrollPhysics(),
      shrinkWrap: true,
      itemCount: itemCount,
      itemBuilder: itemBuilder ?? (_, __) => const RoomCardSkeleton(),
    );
  }
}

/// 余额卡片骨架屏
class BalanceCardSkeleton extends StatelessWidget {
  const BalanceCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFEAEAF0)),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LoadingSkeleton(width: 80, height: 14),
          SizedBox(height: 8),
          LoadingSkeleton(width: 140, height: 32),
          SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    LoadingSkeleton(width: 60, height: 12),
                    SizedBox(height: 4),
                    LoadingSkeleton(width: 80, height: 20),
                  ],
                ),
              ),
              SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    LoadingSkeleton(width: 60, height: 12),
                    SizedBox(height: 4),
                    LoadingSkeleton(width: 80, height: 20),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
