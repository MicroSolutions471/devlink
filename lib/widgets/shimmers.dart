// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

Color _baseColor(BuildContext context) {
  final isDark = Theme.of(context).brightness == Brightness.dark;
  return isDark ? Colors.grey.shade800 : Colors.grey.shade300;
}

Color _highlightColor(BuildContext context) {
  final isDark = Theme.of(context).brightness == Brightness.dark;
  return isDark ? Colors.grey.shade700 : Colors.grey.shade100;
}

Widget _line(
  BuildContext context, {
  double height = 12,
  double width = double.infinity,
  BorderRadius? radius,
}) {
  return Container(
    height: height,
    width: width,
    decoration: BoxDecoration(
      color: _baseColor(context),
      borderRadius: radius ?? BorderRadius.circular(6),
    ),
  );
}

class ShimmerHorizontalAvatars extends StatelessWidget {
  final int count;
  const ShimmerHorizontalAvatars({super.key, this.count = 8});

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: _baseColor(context),
      highlightColor: _highlightColor(context),
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
        scrollDirection: Axis.horizontal,
        itemCount: count,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (_, __) => Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: _baseColor(context),
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(height: 6),
            _line(
              context,
              width: 72,
              height: 12,
              radius: BorderRadius.circular(4),
            ),
          ],
        ),
      ),
    );
  }
}

class ShimmerPostCard extends StatelessWidget {
  const ShimmerPostCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: _baseColor(context),
      highlightColor: _highlightColor(context),
      child: Card(
        elevation: 0,
        color: Theme.of(context).cardColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
            color: Theme.of(context).dividerColor.withOpacity(0.12),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: _baseColor(context),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _line(context, width: 140, height: 12),
                        const SizedBox(height: 6),
                        _line(context, width: 90, height: 10),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _line(context, width: double.infinity, height: 12),
              const SizedBox(height: 8),
              _line(context, width: double.infinity, height: 12),
              const SizedBox(height: 8),
              _line(context, width: 180, height: 12),
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  height: 160,
                  width: double.infinity,
                  color: _baseColor(context),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class ShimmerPostList extends StatelessWidget {
  final int count;
  const ShimmerPostList({super.key, this.count = 6});

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 80),
      itemCount: count,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (_, __) => const ShimmerPostCard(),
    );
  }
}

class ShimmerNotificationTile extends StatelessWidget {
  const ShimmerNotificationTile({super.key});

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: _baseColor(context),
      highlightColor: _highlightColor(context),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: _baseColor(context),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _line(context, width: 180, height: 12),
                const SizedBox(height: 6),
                _line(context, width: 240, height: 10),
                const SizedBox(height: 6),
                _line(context, width: 80, height: 10),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: _baseColor(context),
              shape: BoxShape.circle,
            ),
          ),
        ],
      ),
    );
  }
}

class ShimmerNotificationList extends StatelessWidget {
  final int count;
  const ShimmerNotificationList({super.key, this.count = 8});

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: count,

      itemBuilder: (_, __) => const Padding(
        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: ShimmerNotificationTile(),
      ),
    );
  }
}

class ShimmerReplyTile extends StatelessWidget {
  const ShimmerReplyTile({super.key});

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: _baseColor(context),
      highlightColor: _highlightColor(context),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: _baseColor(context),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _line(context, width: 120, height: 12),
                const SizedBox(height: 6),
                _line(context, height: 12),
                const SizedBox(height: 6),
                _line(context, width: 200, height: 12),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class ShimmerRepliesList extends StatelessWidget {
  final int count;
  const ShimmerRepliesList({super.key, this.count = 4});

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: count,
      separatorBuilder: (context, __) =>
          Divider(color: Theme.of(context).dividerColor),
      itemBuilder: (_, __) => const Padding(
        padding: EdgeInsets.symmetric(vertical: 8),
        child: ShimmerReplyTile(),
      ),
    );
  }
}

class ShimmerUserTile extends StatelessWidget {
  final bool showTrailingButton;

  const ShimmerUserTile({super.key, this.showTrailingButton = false});

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: _baseColor(context),
      highlightColor: _highlightColor(context),
      child: ListTile(
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: _baseColor(context),
            shape: BoxShape.circle,
          ),
        ),
        title: _line(context, width: 120, height: 14),
        trailing: showTrailingButton
            ? Container(
                width: 60,
                height: 24,
                decoration: BoxDecoration(
                  color: _baseColor(context),
                  borderRadius: BorderRadius.circular(12),
                ),
              )
            : null,
      ),
    );
  }
}

class ShimmerUserList extends StatelessWidget {
  final int count;
  final bool showTrailingButton;

  const ShimmerUserList({
    super.key,
    this.count = 6,
    this.showTrailingButton = false,
  });

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      itemCount: count,
      itemBuilder: (_, __) =>
          ShimmerUserTile(showTrailingButton: showTrailingButton),
    );
  }
}

class ShimmerPostDetailCard extends StatelessWidget {
  const ShimmerPostDetailCard({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        children: [
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Shimmer.fromColors(
              baseColor: _baseColor(context),
              highlightColor: _highlightColor(context),
              child: Card(
                elevation: 0,
                color: Theme.of(context).cardColor,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(
                    color: Theme.of(context).dividerColor.withOpacity(0.12),
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: _baseColor(context),
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _line(context, width: 160, height: 12),
                                const SizedBox(height: 6),
                                _line(context, width: 100, height: 10),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      _line(context, height: 14),
                      const SizedBox(height: 8),
                      _line(context, height: 14),
                      const SizedBox(height: 8),
                      _line(context, width: 200, height: 14),
                      const SizedBox(height: 12),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: Container(
                          height: 200,
                          width: double.infinity,
                          color: _baseColor(context),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              ),
            ),
          ),
          Divider(thickness: 8, color: Theme.of(context).dividerColor),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(children: const [SizedBox(width: 120, height: 18)]),
          ),
          const SizedBox(height: 8),
          const ShimmerRepliesList(count: 4),
          const SizedBox(height: 100),
        ],
      ),
    );
  }
}
