import 'package:flutter_test/flutter_test.dart';
import 'package:intuly/features/home/home_page.dart';
import 'package:intuly/router/app_router.dart';

void main() {
  test('未登录访问首页跳登录页，在登录页不跳', () {
    expect(resolveRedirect(loggedIn: false, location: '/home'), '/login');
    expect(resolveRedirect(loggedIn: false, location: '/'), '/login');
    expect(resolveRedirect(loggedIn: false, location: '/login'), isNull);
  });

  test('已登录访问登录页或根路径跳首页', () {
    expect(resolveRedirect(loggedIn: true, location: '/login'), '/home');
    expect(resolveRedirect(loggedIn: true, location: '/'), '/home');
    expect(resolveRedirect(loggedIn: true, location: '/home'), isNull);
  });

  test('maskToken 只露出前 10 位', () {
    expect(maskToken('abcdefghijklmnop'), 'abcdefghij…');
    expect(maskToken('short'), '••••••');
  });
}
