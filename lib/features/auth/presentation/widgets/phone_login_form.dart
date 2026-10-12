import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/api_exception.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../application/auth_providers.dart';
import '../slide_captcha/slide_captcha_dialog.dart';
import 'login_error_handler.dart';
import 'login_widgets.dart';

/// 手机号 + 验证码登录。流程：滑块 → sendSms → 60s 倒计时 → 登录。
class PhoneLoginForm extends ConsumerStatefulWidget {
  const PhoneLoginForm({super.key, required this.agreed, required this.onAgreedChanged});

  final bool agreed;
  final ValueChanged<bool> onAgreedChanged;

  @override
  ConsumerState<PhoneLoginForm> createState() => _PhoneLoginFormState();
}

class _PhoneLoginFormState extends ConsumerState<PhoneLoginForm> {
  static final _phoneRe = RegExp(r'^1[3-9]\d{9}$');
  static const _countdownSeconds = 60;

  final _phoneCtrl = TextEditingController();
  final _codeCtrl = TextEditingController();
  Timer? _timer;
  int _countdown = 0;
  bool _sending = false;
  bool _submitting = false;
  String? _loginSlide;
  String? _smsSentPhone;

  @override
  void initState() {
    super.initState();
    _phoneCtrl.addListener(_onChanged);
    _codeCtrl.addListener(_onChanged);
  }

  @override
  void dispose() {
    _timer?.cancel();
    _phoneCtrl.dispose();
    _codeCtrl.dispose();
    super.dispose();
  }

  void _onChanged() => setState(() {});

  String get _phone => _phoneCtrl.text.trim();
  bool get _phoneValid => _phoneRe.hasMatch(_phone);
  bool get _canSend => _phoneValid && _countdown == 0 && !_sending;
  bool get _canSubmit => _phoneValid && _codeCtrl.text.trim().isNotEmpty && !_submitting;

  Future<void> _sendCode() async {
    if (!_canSend) return;
    final phone = _phone;
    setState(() => _sending = true);
    try {
      final slide = await ref.read(slideVerifierProvider)(context, phone);
      if (slide == null || !mounted) return;
      final loginSlide =
          await ref.read(authRepoProvider).sendSms(phone: phone, loginSlide: slide);
      if (!mounted) return;
      _loginSlide = loginSlide;
      _smsSentPhone = phone;
      _startCountdown();
      showLoginToast(context, '验证码已发送');
    } on ApiException catch (e) {
      if (mounted) await showLoginError(context, e);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  void _startCountdown() {
    _timer?.cancel();
    setState(() => _countdown = _countdownSeconds);
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      setState(() => _countdown--);
      if (_countdown <= 0) t.cancel();
    });
  }

  Future<void> _submit() async {
    if (!_canSubmit) return;
    if (!widget.agreed) {
      showLoginToast(context, '请先同意用户协议');
      return;
    }
    final phone = _phone;
    final loginSlide = _loginSlide;
    // 发码后改了手机号，旧的 loginSlide 不再有效。
    if (loginSlide == null || _smsSentPhone != phone) {
      showLoginToast(context, '请先获取验证码');
      return;
    }
    setState(() => _submitting = true);
    try {
      await ref
          .read(authProvider.notifier)
          .loginWithPhone(phone, _codeCtrl.text.trim(), loginSlide);
    } on ApiException catch (e) {
      if (mounted) await showLoginError(context, e);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('未注册手机号将自动注册', style: AppTextStyles.body12.copyWith(color: AppColors.text3)),
        const SizedBox(height: 8),
        LoginInputBox(
          padding: const EdgeInsets.only(left: 16, right: 16),
          child: Row(children: [
            const SizedBox(width: 50, child: Text('+86', style: AppTextStyles.title14)),
            Expanded(
              child: LoginTextField(
                key: const Key('phone-input'),
                controller: _phoneCtrl,
                hint: '请输入手机号',
                keyboardType: TextInputType.phone,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(11),
                ],
              ),
            ),
          ]),
        ),
        const SizedBox(height: 12),
        const FieldLabel('验证码'),
        const SizedBox(height: 8),
        LoginInputBox(
          padding: const EdgeInsets.only(left: 16, right: 4),
          child: Row(children: [
            Expanded(
              child: LoginTextField(
                key: const Key('code-input'),
                controller: _codeCtrl,
                hint: '请输入验证码',
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(6),
                ],
              ),
            ),
            _SmsButton(countdown: _countdown, onPressed: _canSend ? _sendCode : null),
          ]),
        ),
        const SizedBox(height: 40),
        PrimaryLoginButton(enabled: _canSubmit, loading: _submitting, onPressed: _submit),
        const SizedBox(height: 12),
        AgreementRow(agreed: widget.agreed, onChanged: widget.onAgreedChanged),
      ],
    );
  }
}

/// "获取验证码"：设计稿 94x36 次要按钮；禁用时文字 #CACCD0。
class _SmsButton extends StatelessWidget {
  const _SmsButton({required this.countdown, required this.onPressed});

  final int countdown;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 94,
      height: 36,
      child: TextButton(
        onPressed: onPressed,
        style: TextButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          foregroundColor: AppColors.primary,
          disabledForegroundColor: AppColors.text4,
          textStyle: AppTextStyles.body14,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(2)),
        ),
        child: Text(countdown > 0 ? '${countdown}s' : '获取验证码'),
      ),
    );
  }
}
