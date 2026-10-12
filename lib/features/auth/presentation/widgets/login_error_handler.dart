import 'package:flutter/material.dart';

import '../../../../core/network/api_exception.dart';
import 'login_widgets.dart';

/// 301/302/303 弹对话框（与 Web 端一致：301 不展示服务端消息），其余弹 toast。
Future<void> showLoginError(BuildContext context, ApiException e) async {
  if (!e.isAccountDisabled) {
    showLoginToast(context, e.message);
    return;
  }
  final title = switch (e.status) {
    301 => '账号已被封禁',
    302 => '账号已被冻结',
    _ => '账号存在违规行为',
  };
  final content = e.status == 301 ? '如有疑问请联系客服' : e.message;
  await showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: Text(content),
      actions: [
        TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('我知道了')),
      ],
    ),
  );
}
