import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../../core/network/api_exception.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_icons.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../application/auth_providers.dart';
import '../../data/models/slide_challenge.dart';
import 'slide_geometry.dart';

typedef SlideVerifier = Future<String?> Function(BuildContext context, String loginUser);

/// 表单通过它弹滑块；测试里 override 成假实现。
final slideVerifierProvider = Provider<SlideVerifier>((ref) => showSlideCaptcha);

/// 校验通过返回 loginSlide；用户关闭返回 null。
Future<String?> showSlideCaptcha(BuildContext context, String loginUser) {
  return showDialog<String>(
    context: context,
    barrierColor: AppColors.mask2,
    builder: (_) => SlideCaptchaDialog(loginUser: loginUser),
  );
}

class SlideCaptchaDialog extends ConsumerStatefulWidget {
  const SlideCaptchaDialog({super.key, required this.loginUser});
  final String loginUser;

  @override
  ConsumerState<SlideCaptchaDialog> createState() => _SlideCaptchaDialogState();
}

class _SlideCaptchaDialogState extends ConsumerState<SlideCaptchaDialog> {
  static const _hint = '请拖动滑块完成拼图';
  static const _retryHint = '未对准，请重试';
  static const _designWidth = 297.0;

  SlideChallenge? _challenge;
  String? _loadError;
  bool _loading = true;
  bool _checking = false;
  double _offset = 0;
  String _trackText = _hint;
  Timer? _resetTimer;

  @override
  void initState() {
    super.initState();
    _fetch(); // 首个 await 之前不调用 setState
  }

  @override
  void dispose() {
    _resetTimer?.cancel();
    super.dispose();
  }

  void _reload() {
    _resetTimer?.cancel();
    setState(() {
      _loading = true;
      _loadError = null;
      _offset = 0;
      _trackText = _hint;
    });
    _fetch();
  }

  Future<void> _fetch() async {
    try {
      final c = await ref.read(authRepoProvider).fetchSlide(widget.loginUser);
      if (!mounted) return;
      setState(() {
        _challenge = c;
        _loading = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _loadError = e.message;
        _loading = false;
      });
    }
  }

  Future<void> _submit(SlideGeometry g) async {
    final c = _challenge;
    if (c == null || _checking) return;
    setState(() => _checking = true);
    try {
      final r = await ref.read(authRepoProvider).checkSlide(
            loginUser: widget.loginUser,
            captchaId: c.captchaId,
            moveWidth: g.moveWidthFor(_offset),
          );
      if (!mounted) return;
      if (r.passed && r.loginSlide != null) {
        Navigator.of(context).pop(r.loginSlide);
        return;
      }
      _onFailed(_retryHint, reload: r.errorCount >= 3);
    } on ApiException catch (e) {
      if (mounted) _onFailed(e.message, reload: true);
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  /// 显示提示 1 秒后：失败次数达上限则换图，否则复位滑块。
  void _onFailed(String text, {required bool reload}) {
    setState(() => _trackText = text);
    _resetTimer?.cancel();
    _resetTimer = Timer(const Duration(seconds: 1), () {
      if (!mounted) return;
      if (reload) {
        _reload();
      } else {
        setState(() {
          _offset = 0;
          _trackText = _hint;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppColors.bg1,
      shape: const RoundedRectangleBorder(),
      insetPadding: const EdgeInsets.symmetric(horizontal: 27, vertical: 24),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: LayoutBuilder(builder: (context, constraints) {
          final width = constraints.maxWidth.clamp(0.0, _designWidth).toDouble();
          return SizedBox(width: width, child: _body(width));
        }),
      ),
    );
  }

  Widget _body(double width) {
    if (_loading) {
      return const SizedBox(height: 230, child: Center(child: CircularProgressIndicator()));
    }
    final c = _challenge;
    if (_loadError != null || c == null) {
      return SizedBox(
        height: 230,
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Text(_loadError ?? '获取滑块失败，请重试', style: AppTextStyles.body14),
          const SizedBox(height: 12),
          TextButton(onPressed: _reload, child: const Text('重试')),
        ]),
      );
    }
    final g = SlideGeometry(c, width);
    return Column(mainAxisSize: MainAxisSize.min, children: [
      SizedBox(
        width: width,
        height: g.renderHeight,
        child: Stack(children: [
          Positioned.fill(
            child: Image.memory(c.backgroundBytes, fit: BoxFit.fill, gaplessPlayback: true),
          ),
          Positioned(
            left: _offset,
            top: g.pieceTop,
            width: g.pieceWidth,
            height: g.pieceHeight,
            child: Image.memory(c.pieceBytes, fit: BoxFit.fill, gaplessPlayback: true),
          ),
          Positioned(
            top: 0,
            right: 0,
            child: _RefreshButton(onTap: _checking ? null : _reload),
          ),
        ]),
      ),
      const SizedBox(height: 8),
      _track(g),
    ]);
  }

  Widget _track(SlideGeometry g) {
    return SizedBox(
      height: 44,
      child: Stack(children: [
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: AppColors.sliderTrack,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Center(
              child: ShaderMask(
                // 设计稿 linear-gradient(270deg, #868686 0%, #FEFEFE 100%)：右深左浅
                shaderCallback: (rect) => const LinearGradient(
                  begin: Alignment.centerRight,
                  end: Alignment.centerLeft,
                  colors: [Color(0xFF868686), Color(0xFFFEFEFE)],
                ).createShader(rect),
                child: Text(
                  _trackText,
                  style: AppTextStyles.body16.copyWith(color: Colors.white),
                ),
              ),
            ),
          ),
        ),
        Positioned(
          left: _offset,
          top: 0,
          child: GestureDetector(
            key: const Key('slide-knob'),
            behavior: HitTestBehavior.opaque,
            onHorizontalDragUpdate: _checking
                ? null
                : (d) => setState(() => _offset = g.clamp(_offset + d.delta.dx)),
            onHorizontalDragEnd: _checking ? null : (_) => _submit(g),
            child: Semantics(
              label: '拖动滑块完成拼图',
              child: Container(
                width: SlideGeometry.knobSize,
                height: SlideGeometry.knobSize,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.bg1,
                  borderRadius: BorderRadius.circular(4),
                  boxShadow: const [
                    BoxShadow(color: Color(0x26000000), offset: Offset(1, 2), blurRadius: 10),
                  ],
                ),
                child: RotatedBox(
                  quarterTurns: 1, // 设计稿 rotate: 90，"上"箭头转成"右"
                  child: SvgPicture.asset(AppIcons.arrowDouble, width: 16, height: 16),
                ),
              ),
            ),
          ),
        ),
      ]),
    );
  }
}

class _RefreshButton extends StatelessWidget {
  const _RefreshButton({required this.onTap});
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: '换一张',
      child: Semantics(
        button: true,
        label: '换一张',
        child: InkWell(
          onTap: onTap,
          child: Container(
            width: 32,
            height: 32,
            color: AppColors.mask2,
            alignment: Alignment.center,
            child: SvgPicture.asset(AppIcons.refresh, width: 20, height: 20),
          ),
        ),
      ),
    );
  }
}
