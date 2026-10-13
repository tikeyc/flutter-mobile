import 'package:flutter_test/flutter_test.dart';
import 'package:intuly/router/app_router.dart';

void main() {
  test('未登录游客可浏览公开页面，可停留登录页，根路径去首页', () {
    expect(resolveRedirect(loggedIn: false, location: '/home'), isNull);
    expect(resolveRedirect(loggedIn: false, location: '/model-plaza'), isNull);
    expect(resolveRedirect(loggedIn: false, location: '/feed/ins-1'), isNull);
    expect(resolveRedirect(loggedIn: false, location: '/login'), isNull);
    expect(resolveRedirect(loggedIn: false, location: '/'), '/home');
  });

  test('已登录访问登录页或根路径跳首页', () {
    expect(resolveRedirect(loggedIn: true, location: '/login'), '/home');
    expect(resolveRedirect(loggedIn: true, location: '/'), '/home');
    expect(resolveRedirect(loggedIn: true, location: '/home'), isNull);
  });
}
