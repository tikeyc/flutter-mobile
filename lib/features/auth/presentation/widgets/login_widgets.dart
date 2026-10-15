import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../config/env_config.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/webview_page.dart';

/// 输入框容器：高 44、底 #F9F9FA、描边 #F2F3F5（错误时红色）、圆角 12.8。
class LoginInputBox extends StatelessWidget {
  const LoginInputBox({
    super.key,
    required this.child,
    this.error = false,
    this.padding = const EdgeInsets.symmetric(horizontal: 16),
  });

  final Widget child;
  final bool error;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 44,
      padding: padding,
      alignment: Alignment.centerLeft,
      decoration: BoxDecoration(
        color: AppColors.bg2,
        border: Border.all(color: error ? AppColors.danger : AppColors.border4),
        borderRadius: BorderRadius.circular(12.8),
      ),
      child: child,
    );
  }
}

/// 无边框输入框，放在 LoginInputBox 里。
class LoginTextField extends StatelessWidget {
  const LoginTextField({
    super.key,
    required this.controller,
    required this.hint,
    this.keyboardType,
    this.inputFormatters,
    this.obscureText = false,
  });

  final TextEditingController controller;
  final String hint;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final bool obscureText;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      obscureText: obscureText,
      style: AppTextStyles.body14,
      decoration: InputDecoration(
        isDense: true,
        border: InputBorder.none,
        contentPadding: EdgeInsets.zero,
        hintText: hint,
        hintStyle: AppTextStyles.body14.copyWith(color: AppColors.text4),
      ),
    );
  }
}

class FieldLabel extends StatelessWidget {
  const FieldLabel(this.text, {super.key});
  final String text;

  @override
  Widget build(BuildContext context) => Text(text, style: AppTextStyles.title14);
}

/// 主按钮"立即登录"：高 44、圆角 8、主色；禁用时 40% 透明度。
class PrimaryLoginButton extends StatelessWidget {
  const PrimaryLoginButton({
    super.key,
    required this.enabled,
    required this.loading,
    required this.onPressed,
  });

  final bool enabled;
  final bool loading;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final active = enabled && !loading;
    return SizedBox(
      height: 44,
      child: FilledButton(
        onPressed: active ? onPressed : null,
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.primary,
          disabledBackgroundColor: AppColors.primary.withValues(alpha: 0.4),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        child: loading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.textWhite),
              )
            : Text('立即登录', style: AppTextStyles.title16.copyWith(color: AppColors.textWhite)),
      ),
    );
  }
}

void showLoginToast(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message), behavior: SnackBarBehavior.floating));
}

/// 协议勾选行：复选框 + "我已阅读并同意《用户服务协议》和《隐私政策》"。
class AgreementRow extends StatefulWidget {
  const AgreementRow({super.key, required this.agreed, required this.onChanged});
  final bool agreed;
  final ValueChanged<bool> onChanged;

  @override
  State<AgreementRow> createState() => _AgreementRowState();
}

class _AgreementRowState extends State<AgreementRow> {
  late final TapGestureRecognizer _userTap =
      TapGestureRecognizer()..onTap = () => _open('用户服务协议', EnvConfig.userAgreementUrl);
  late final TapGestureRecognizer _privacyTap =
      TapGestureRecognizer()..onTap = () => _open('隐私政策', EnvConfig.privacyPolicyUrl);

  @override
  void dispose() {
    _userTap.dispose();
    _privacyTap.dispose();
    super.dispose();
  }

  void _open(String title, String url) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => WebViewPage(title: title, url: url)),
    );
  }

  @override
  Widget build(BuildContext context) {
    const link = TextStyle(color: AppColors.primary);
    return Row(mainAxisAlignment: MainAxisAlignment.center, children: [
      Semantics(
        checked: widget.agreed,
        label: '同意用户服务协议和隐私政策',
        child: GestureDetector(
          key: const Key('agreement-checkbox'),
          behavior: HitTestBehavior.opaque,
          onTap: () => widget.onChanged(!widget.agreed),
          child: SizedBox(
            width: 20,
            height: 20,
            child: Center(
              child: Container(
                width: 16,
                height: 16,
                decoration: BoxDecoration(
                  color: widget.agreed ? AppColors.primary : AppColors.bg1,
                  border: Border.all(
                    color: widget.agreed ? AppColors.primary : AppColors.border3,
                  ),
                  borderRadius: BorderRadius.circular(1),
                ),
                child: widget.agreed
                    ? const Icon(Icons.check, size: 12, color: AppColors.textWhite)
                    : null,
              ),
            ),
          ),
        ),
      ),
      const SizedBox(width: 4),
      Flexible(
        child: Text.rich(TextSpan(style: AppTextStyles.body12, children: [
          const TextSpan(text: '我已阅读并同意'),
          TextSpan(text: '《用户服务协议》', style: link, recognizer: _userTap),
          const TextSpan(text: '和'),
          TextSpan(text: '《隐私政策》', style: link, recognizer: _privacyTap),
        ])),
      ),
    ]);
  }
}
