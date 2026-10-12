/// 环境常量。目前所有环境共用一套值。
class EnvConfig {
  EnvConfig._();

  static const String baseUrl = 'https://www.intuly.com/api';
  static const String clientId = '101409740478767510';
  static const String apiVersion = 'v1.0.0';

  // 协议页沿用 Web 端路径（Agreements.vue）。
  // 假设：Web 站点域名为 https://www.intuly.com，上线前需确认。
  static const String userAgreementUrl =
      'https://www.intuly.com/content/agreement/userUseAgreement';
  static const String privacyPolicyUrl =
      'https://www.intuly.com/content/agreement/platformPrivacyPolicy';
}
