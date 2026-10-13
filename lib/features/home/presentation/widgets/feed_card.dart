import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_icons.dart';
import '../../../../core/utils/image_utils.dart';
import '../../data/models/feed_item.dart';

/// 图片区宽高比约束：防止极端长图/扁图撑爆瀑布流。
double clampAspect(double ratio) => ratio.clamp(9 / 16, 16 / 9);

/// 首页瀑布流卡片：图片区（按真实比例）+ 白底信息区（按卡片类型变化）。
class FeedCard extends StatelessWidget {
  const FeedCard({super.key, required this.item});

  final FeedItem item;

  static const double radius = 8;

  @override
  Widget build(BuildContext context) {
    final dpr = MediaQuery.devicePixelRatioOf(context);
    return LayoutBuilder(builder: (context, constraints) {
      // 图片按列宽解码，避免整图解码浪费内存与耗时。
      final cacheWidth = (constraints.maxWidth * dpr).round();
      return Container(
        decoration: const BoxDecoration(
          color: AppColors.bg1,
          borderRadius: BorderRadius.all(Radius.circular(radius)),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AspectRatio(
              aspectRatio: clampAspect(item.aspectRatio),
              child: _imageArea(cacheWidth),
            ),
            _infoArea(),
          ],
        ),
      );
    });
  }

  // ---------- 图片区 ----------

  Widget _imageArea(int cacheWidth) {
    return Stack(
      fit: StackFit.expand,
      children: [
        Image.network(
          imageProcessFormat(item.imageUrl),
          fit: BoxFit.cover,
          cacheWidth: cacheWidth,
          errorBuilder: (_, _, _) => Container(color: AppColors.border4),
        ),
        switch (item) {
          InsFeedItem(isVideo: true) => const Positioned(
              top: 4,
              right: 4,
              child: _PlayBadge(),
            ),
          ModelFeedItem() => const Positioned(
              top: 4,
              left: 4,
              child: _TypeBadge(label: ModelFeedItem.badge),
            ),
          _ => const SizedBox.shrink(),
        },
      ],
    );
  }

  // ---------- 信息区 ----------

  Widget _infoArea() {
    return switch (item) {
      InsFeedItem ins => _insInfo(ins),
      ModelFeedItem model => _modelInfo(model),
      DesignFeedItem design => _designInfo(design),
      GoodsFeedItem goods => _goodsInfo(goods),
    };
  }

  Widget _insInfo(InsFeedItem card) {
    return _InfoPadding(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Title(text: card.title, big: true),
          if (card.tags.isNotEmpty) ...[
            const SizedBox(height: 4),
            _TagRow(tags: card.tags),
          ],
          const SizedBox(height: 8),
          _AuthorRow(
            avatar: card.authorAvatar,
            nick: card.authorNick,
            trailing: _IconCount(
              icon: AppIcons.heartOutline,
              count: card.likeNum.toString(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _modelInfo(ModelFeedItem card) {
    return _InfoPadding(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _Title(text: card.title, big: true),
              if (card.tags.isNotEmpty) ...[
                const SizedBox(height: 4),
                _TagRow(tags: card.tags, firstHighlight: !card.paid),
              ],
              if (card.priceText.isNotEmpty) ...[
                const SizedBox(height: 4),
                _PriceRow(price: card.priceText, trailing: card.salesText),
              ],
            ],
          ),
          const SizedBox(height: 8),
          _AuthorRow(
            avatar: card.authorAvatar,
            nick: card.authorNick,
            trailing: _IconCount(
              icon: AppIcons.starFilled,
              count: card.likeNum.toString(),
              color: const Color(0xFFFFC300),
            ),
          ),
        ],
      ),
    );
  }

  Widget _designInfo(DesignFeedItem card) {
    return _InfoPadding(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Title(text: card.title, big: true),
          if (card.tags.isNotEmpty) ...[
            const SizedBox(height: 4),
            _TagRow(tags: card.tags),
          ],
          const SizedBox(height: 8),
          _PriceRow(price: card.priceText, trailing: card.partNumText),
        ],
      ),
    );
  }

  Widget _goodsInfo(GoodsFeedItem card) {
    return _InfoPadding(
      bottom: 8,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Title(text: card.title),
          if (card.priceText.isNotEmpty) ...[
            const SizedBox(height: 4),
            _Price(price: card.priceText),
          ],
          const SizedBox(height: 8),
          _AuthorRow(
            avatar: card.shopAvatar,
            nick: card.shopName,
            nickColor: AppColors.text2,
            avatarRadius: 9,
            trailing: _IconCount(icon: AppIcons.starOutline, count: card.scoreText),
          ),
        ],
      ),
    );
  }
}

// ---------- 共享小组件 ----------

class _InfoPadding extends StatelessWidget {
  const _InfoPadding({required this.child, this.bottom = 12});

  final Widget child;
  final double bottom;

  @override
  Widget build(BuildContext context) =>
      Padding(padding: EdgeInsets.fromLTRB(8, 8, 8, bottom), child: child);
}

class _Title extends StatelessWidget {
  const _Title({required this.text, this.big = false});

  final String text;
  final bool big;

  @override
  Widget build(BuildContext context) {
    final style = big
        ? const TextStyle(
            fontSize: 16,
            height: 24 / 16,
            fontWeight: FontWeight.w400,
            color: AppColors.text1,
          )
        : const TextStyle(
            fontSize: 14,
            height: 20 / 14,
            fontWeight: FontWeight.w500,
            color: AppColors.text1,
          );
    return Text(text, style: style, maxLines: 2, overflow: TextOverflow.ellipsis);
  }
}

class _TagRow extends StatelessWidget {
  const _TagRow({required this.tags, this.firstHighlight = false});

  final List<String> tags;
  final bool firstHighlight;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 4,
      runSpacing: 4,
      children: [
        for (final (i, tag) in tags.indexed)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: AppColors.border4,
              border: Border.all(color: AppColors.border3),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              tag,
              style: TextStyle(
                fontSize: 12,
                height: 16 / 12,
                color: firstHighlight && i == 0 ? AppColors.primary : AppColors.text1,
              ),
            ),
          ),
      ],
    );
  }
}

class _Price extends StatelessWidget {
  const _Price({required this.price});

  final String price;

  @override
  Widget build(BuildContext context) => Text(
        price,
        style: const TextStyle(
          fontSize: 16,
          height: 24 / 16,
          fontWeight: FontWeight.w500,
          color: AppColors.primary,
        ),
      );
}

class _PriceRow extends StatelessWidget {
  const _PriceRow({required this.price, required this.trailing});

  final String price;
  final String trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: _Price(price: price)),
        if (trailing.isNotEmpty)
          Text(
            trailing,
            style: const TextStyle(
              fontSize: 12,
              height: 16 / 12,
              color: Color(0xFF999999),
            ),
          ),
      ],
    );
  }
}

class _AuthorRow extends StatelessWidget {
  const _AuthorRow({
    required this.avatar,
    required this.nick,
    required this.trailing,
    this.nickColor = AppColors.text3,
    this.avatarRadius = 9,
  });

  final String avatar;
  final String nick;
  final Widget trailing;
  final Color nickColor;
  final double avatarRadius;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        if (avatar.isNotEmpty)
          ClipOval(
            child: Image.network(
              imageProcessFormat(avatar),
              width: avatarRadius * 2,
              height: avatarRadius * 2,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) =>
                  CircleAvatar(radius: avatarRadius, backgroundColor: AppColors.border4),
            ),
          ),
        const SizedBox(width: 4),
        Expanded(
          child: Text(
            nick,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 12, height: 16 / 12, color: nickColor),
          ),
        ),
        trailing,
      ],
    );
  }
}

class _IconCount extends StatelessWidget {
  const _IconCount({
    required this.icon,
    required this.count,
    this.color = AppColors.text3,
  });

  final String icon;
  final String count;
  final Color color;

  @override
  Widget build(BuildContext context) {
    if (count.isEmpty) return const SizedBox.shrink();
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SvgPicture.asset(icon, width: 16, height: 16),
        const SizedBox(width: 4),
        Text(count, style: TextStyle(fontSize: 12, height: 16 / 12, color: color)),
      ],
    );
  }
}

/// 视频卡右上角播放角标：18px 半透明黑圆 + 白色三角。
class _PlayBadge extends StatelessWidget {
  const _PlayBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 20,
      height: 20,
      alignment: Alignment.center,
      decoration: const BoxDecoration(
        color: Color(0x661A1A1A),
        shape: BoxShape.circle,
      ),
      child: const Icon(Icons.play_arrow, size: 10, color: Color(0xCCFFFFFF)),
    );
  }
}

/// 模型卡左上角类型角标：黑 50% 胶囊。
class _TypeBadge extends StatelessWidget {
  const _TypeBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(148),
      ),
      child: Text(
        label,
        style: const TextStyle(fontSize: 12, height: 16 / 12, color: Colors.white),
      ),
    );
  }
}
