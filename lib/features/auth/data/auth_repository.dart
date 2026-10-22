import 'package:dio/dio.dart';

import '../../../core/network/api_exception.dart';
import 'models/slide_challenge.dart';

abstract class AuthRepository {
  Future<SlideChallenge> fetchSlide(String loginUser, {CancelToken? cancelToken});

  Future<SlideCheckResult> checkSlide({
    required String loginUser,
    required String captchaId,
    required int moveWidth,
    CancelToken? cancelToken,
  });

  /// 返回后续登录要用的 loginSlide。
  Future<String> sendSms({required String phone, required String loginSlide});

  /// 返回 token。
  Future<String> loginWithPhone({
    required String phone,
    required String code,
    required String loginSlide,
  });

  /// 返回 token。
  Future<String> loginWithPassword({
    required String account,
    required String password,
    required String loginSlide,
  });
}

class DioAuthRepository implements AuthRepository {
  static const int _smsTypeLogin = 1;
  static const String _loginTypeMobile = '2';

  final Dio _dio;
  DioAuthRepository(this._dio);

  /// 统一 POST：DioException 转成 ApiException，返回 body Map。
  Future<Map<String, dynamic>> _post(
    String path,
    Map<String, dynamic> data, {
    CancelToken? cancelToken,
  }) async {
    try {
      final res = await _dio.post<Map<String, dynamic>>(path,
          data: data, cancelToken: cancelToken);
      return res.data ?? const {};
    } on DioException catch (e) {
      final err = e.error;
      throw err is ApiException ? err : ApiException.fromDio(e);
    }
  }

  @override
  Future<SlideChallenge> fetchSlide(String loginUser, {CancelToken? cancelToken}) async {
    final body = await _post('/login/ai/slide', {
      'loginUser': loginUser,
      'smsType': _smsTypeLogin,
    }, cancelToken: cancelToken);
    final data = body['data'];
    if (data is! Map<String, dynamic>) {
      throw ApiException(status: body['status'] as int?, message: '获取滑块失败，请重试');
    }
    try {
      return SlideChallenge.fromJson(data);
    } on FormatException {
      throw const ApiException(status: null, message: '获取滑块失败，请重试');
    }
  }

  @override
  Future<SlideCheckResult> checkSlide({
    required String loginUser,
    required String captchaId,
    required int moveWidth,
    CancelToken? cancelToken,
  }) async {
    final body = await _post('/login/ai/checkSlide', {
      'loginUser': loginUser,
      'imgCaptchaId': captchaId,
      'moveWidth': moveWidth.toString(),
      'smsType': _smsTypeLogin,
    }, cancelToken: cancelToken);
    final data = body['data'] as Map<String, dynamic>? ?? const {};
    return SlideCheckResult(
      passed: data['checkResult'] == true,
      loginSlide: data['loginSlide'] as String?,
      errorCount: (data['errorCnt'] as num?)?.toInt() ?? 0,
    );
  }

  @override
  Future<String> sendSms({required String phone, required String loginSlide}) async {
    final body = await _post('/login/ai/sendSms', {
      'phone': phone,
      'loginSlide': loginSlide,
      'smsType': _smsTypeLogin,
    });
    // 与 Web 端一致：201 时 data 是新的 loginSlide。
    final data = body['data'];
    return body['status'] == 201 && data is String && data.isNotEmpty ? data : loginSlide;
  }

  @override
  Future<String> loginWithPhone({
    required String phone,
    required String code,
    required String loginSlide,
  }) async {
    final body = await _post('/login/ai/phone', {
      'loginUser': phone,
      'loginCode': code,
      'loginSlide': loginSlide,
      'smsType': _smsTypeLogin,
      'loginType': _loginTypeMobile,
    });
    return _token(body);
  }

  @override
  Future<String> loginWithPassword({
    required String account,
    required String password,
    required String loginSlide,
  }) async {
    final body = await _post('/login/ai/pass', {
      'loginUser': account,
      'loginPass': password,
      'loginSlide': loginSlide,
      'loginType': _loginTypeMobile,
    });
    return _token(body);
  }

  String _token(Map<String, dynamic> body) {
    final data = body['data'];
    if (data is String && data.isNotEmpty) return data;
    throw ApiException(status: body['status'] as int?, message: '登录失败，请重试');
  }
}
