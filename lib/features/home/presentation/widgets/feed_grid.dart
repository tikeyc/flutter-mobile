import 'package:flutter/material.dart';

import '../../data/models/feed_item.dart';
import 'feed_card.dart';

/// 双列瀑布流：按内容实际高度左右两列交替填充，间距 8。
class FeedGrid extends StatelessWidget {
  const FeedGrid({super.key, required this.items});

  final List<FeedItem> items;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final width = constraints.maxWidth;
      const gap = 8.0;
      final columnWidth = (width - gap * 3) / 2;
      final columns = <List<FeedItem>>[[], []];
      for (final item in items) {
        // 短列优先：列高按「图片高度 + 信息区约 100px」估算。
        final leftTotal = _estimate(columns[0], columnWidth);
        final rightTotal = _estimate(columns[1], columnWidth);
        final target = leftTotal <= rightTotal ? columns[0] : columns[1];
        target.add(item);
      }
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final (i, column) in columns.indexed) ...[
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final item in column)
                    Padding(
                      padding: EdgeInsets.only(
                        top: 8,
                        left: i == 0 ? 8 : 0,
                        right: i == 1 ? 8 : 0,
                      ),
                      child: FeedCard(item: item, width: columnWidth),
                    ),
                ],
              ),
            ),
            if (i == 0) const SizedBox(width: gap),
          ],
        ],
      );
    });
  }

  double _estimate(List<FeedItem> column, double columnWidth) {
    var total = 0.0;
    for (final item in column) {
      total += columnWidth / clampAspect(item.aspectRatio) + 100;
    }
    return total;
  }
}
