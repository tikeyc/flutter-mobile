/// 登录会话：token + account。
class Session {
  final String token;
  final String account;

  const Session({required this.token, required this.account});

  Map<String, String> toJson() => {'token': token, 'account': account};

  factory Session.fromJson(Map<String, dynamic> json) {
    final token = json['token'];
    final account = json['account'];
    if (token is! String || account is! String) {
      throw const FormatException('Session 数据格式错误');
    }
    return Session(token: token, account: account);
  }
}
