import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../../core/network/api_exception.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_icons.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../application/auth_providers.dart';
import '../slide_captcha/slide_captcha_dialog.dart';
import 'login_error_handler.dart';
import 'login_widgets.dart';

/// 账号 + 密码登录。流程：滑块 → loginWithPassword。
class AccountLoginForm extends ConsumerStatefulWidget {
  const AccountLoginForm({super.key, required this.agreed, required this.onAgreedChanged});

  final bool agreed;
  final ValueChanged<bool> onAgreedChanged;

  @override
  ConsumerState<AccountLoginForm> createState() => _AccountLoginFormState();
}

class _AccountLoginFormState extends ConsumerState<AccountLoginForm> {
  final _accountCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _obscure = true;
  bool _submitting = false;
  bool _wrongCredentials = false;

  @override
  void initState() {
    super.initState();
    _accountCtrl.addListener(_onChanged);
    _passwordCtrl.addListener(_onChanged);
  }

  @override
  void dispose() {
    _accountCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  /// 编辑任一输入框都清除"账号或密码错误"。
  void _onChanged() => setState(() => _wrongCredentials = false);

  bool get _canSubmit =>
      _accountCtrl.text.trim().isNotEmpty && _passwordCtrl.text.isNotEmpty && !_submitting;

  Future<void> _submit() async {
    if (!_canSubmit) return;
    if (!widget.agreed) {
      showLoginToast(context, '请先同意用户协议');
      return;
    }
    final account = _accountCtrl.text.trim();
    final password = _passwordCtrl.text;
    setState(() => _submitting = true);
    try {
      final slide = await ref.read(slideVerifierProvider)(context, account);
      if (slide == null || !mounted) return;
      await ref.read(authProvider.notifier).loginWithPassword(account, password, slide);
    } on ApiException catch (e) {
      if (!mounted) return;
      if (e.isWrongCredentials) {
        setState(() => _wrongCredentials = true);
      } else {
        await showLoginError(context, e);
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        LoginInputBox(
          error: _wrongCredentials,
          child: LoginTextField(
            key: const Key('account-input'),
            controller: _accountCtrl,
            hint: '请输入账号',
          ),
        ),
        const SizedBox(height: 12),
        const FieldLabel('密码'),
        const SizedBox(height: 8),
        LoginInputBox(
          error: _wrongCredentials,
          padding: const EdgeInsets.only(left: 16, right: 4),
          child: Row(children: [
            Expanded(
              child: LoginTextField(
                key: const Key('password-input'),
                controller: _passwordCtrl,
                hint: '请输入密码',
                obscureText: _obscure,
              ),
            ),
            IconButton(
              tooltip: _obscure ? '显示密码' : '隐藏密码',
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints.tightFor(width: 40, height: 40),
              onPressed: () => setState(() => _obscure = !_obscure),
              icon: SvgPicture.asset(
                AppIcons.eye,
                width: 24,
                height: 24,
                colorFilter: ColorFilter.mode(
                  _obscure ? AppColors.text4 : AppColors.text2,
                  BlendMode.srcIn,
                ),
              ),
            ),
          ]),
        ),
        if (_wrongCredentials) ...[
          const SizedBox(height: 4),
          Text('账号或密码错误', style: AppTextStyles.body12.copyWith(color: AppColors.danger)),
        ],
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerLeft,
          child: GestureDetector(
            onTap: () => showLoginToast(context, '功能即将上线'),
            child: Text('忘记密码', style: AppTextStyles.body12.copyWith(color: AppColors.primary)),
          ),
        ),
        const SizedBox(height: 40),
        PrimaryLoginButton(enabled: _canSubmit, loading: _submitting, onPressed: _submit),
        const SizedBox(height: 12),
        AgreementRow(agreed: widget.agreed, onChanged: widget.onAgreedChanged),
      ],
    );
  }
}
