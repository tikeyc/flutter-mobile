import 'package:flutter_test/flutter_test.dart';
import 'package:intuly/core/network/api_exception.dart';
import 'package:intuly/core/network/dio_client.dart';
import 'package:intuly/features/auth/data/auth_repository.dart';

import '../../../helpers/fake_http_adapter.dart';
import '../../../helpers/test_images.dart';

void main() {
  late FakeHttpAdapter adapter;
  late DioAuthRepository repo;

  setUp(() {
    adapter = FakeHttpAdapter();
    repo = DioAuthRepository(
        createDio(readToken: () => null, onUnauthorized: () {}, adapter: adapter));
  });

  Map<String, dynamic> body() => adapter.requests.last.data as Map<String, dynamic>;

  test('fetchSlide 传 loginUser + smsType=1 并解析', () async {
    adapter.on('/login/ai/slide', body: {'status': 200, 'data': slideJson()});
    final c = await repo.fetchSlide('13800000000');
    expect(body(), {'loginUser': '13800000000', 'smsType': 1});
    expect(c.captchaId, 'cap-1');
  });

  test('fetchSlide 数据不完整时抛 ApiException', () async {
    adapter.on('/login/ai/slide', body: {'status': 200, 'data': {'imgCaptchaId': 'x'}});
    await expectLater(repo.fetchSlide('u'), throwsA(isA<ApiException>()));
  });

  test('checkSlide 把 moveWidth 转成字符串', () async {
    adapter.on('/login/ai/checkSlide', body: {
      'status': 200,
      'data': {'checkResult': true, 'loginSlide': 'ls-1', 'errorCnt': 0},
    });
    final r = await repo.checkSlide(loginUser: 'u', captchaId: 'cap-1', moveWidth: 200);
    expect(body(),
        {'loginUser': 'u', 'imgCaptchaId': 'cap-1', 'moveWidth': '200', 'smsType': 1});
    expect(r.passed, isTrue);
    expect(r.loginSlide, 'ls-1');
  });

  test('sendSms 200 沿用入参 loginSlide', () async {
    adapter.on('/login/ai/sendSms', body: {'status': 200});
    expect(await repo.sendSms(phone: 'p', loginSlide: 'ls-1'), 'ls-1');
    expect(body(), {'phone': 'p', 'loginSlide': 'ls-1', 'smsType': 1});
  });

  test('sendSms 201 改用 data 中的新 loginSlide', () async {
    adapter.on('/login/ai/sendSms', body: {'status': 201, 'data': 'ls-2', 'message': 'm'});
    expect(await repo.sendSms(phone: 'p', loginSlide: 'ls-1'), 'ls-2');
  });

  test('loginWithPhone 返回 token，loginType=2', () async {
    adapter.on('/login/ai/phone', body: {'status': 200, 'data': 'tk'});
    expect(await repo.loginWithPhone(phone: 'p', code: '1234', loginSlide: 'ls'), 'tk');
    expect(body(), {
      'loginUser': 'p',
      'loginCode': '1234',
      'loginSlide': 'ls',
      'smsType': 1,
      'loginType': '2',
    });
  });

  test('loginWithPassword 403 抛 ApiException', () async {
    adapter.on('/login/ai/pass', body: {'status': 403, 'message': '账号或密码错误'});
    await expectLater(
      repo.loginWithPassword(account: 'a', password: 'b', loginSlide: 'ls'),
      throwsA(isA<ApiException>().having((e) => e.isWrongCredentials, 'wrong', isTrue)),
    );
  });

  test('登录成功但 data 不是字符串时抛 ApiException', () async {
    adapter.on('/login/ai/pass', body: {'status': 200, 'data': null});
    await expectLater(
      repo.loginWithPassword(account: 'a', password: 'b', loginSlide: 'ls'),
      throwsA(isA<ApiException>()),
    );
  });
}
