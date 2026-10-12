import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intuly/core/theme/app_icons.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('所有图标资源都已注册且是 SVG', () async {
    for (final path in AppIcons.all) {
      final content = await rootBundle.loadString(path);
      expect(content, contains('<svg'), reason: path);
    }
  });
}
