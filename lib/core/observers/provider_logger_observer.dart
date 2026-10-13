import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logger/logger.dart';

/// 通过 [Logger] 记录 provider 生命周期，仅在 debug 模式输出（DevelopmentFilter）。
final class ProviderLoggerObserver extends ProviderObserver {
  ProviderLoggerObserver({Logger? logger})
    : _logger =
          logger ??
          Logger(
            filter: DevelopmentFilter(),
            printer: PrettyPrinter(methodCount: 0, printEmojis: false),
          );

  final Logger _logger;

  @override
  void didAddProvider(ProviderObserverContext context, Object? value) {
    _logger.i(
      '[riverpod] created  ${_describe(context)} | value: $value',
    );
  }

  @override
  void didUpdateProvider(
    ProviderObserverContext context,
    Object? previousValue,
    Object? newValue,
  ) {
    _logger.f(
      '[riverpod] updated  ${_describe(context)} | '
      '$previousValue -> $newValue',
    );
  }

  @override
  void didDisposeProvider(ProviderObserverContext context) {
    _logger.i('[riverpod] disposed ${_describe(context)}');
  }

  @override
  void providerDidFail(
    ProviderObserverContext context,
    Object error,
    StackTrace stackTrace,
  ) {
    _logger.e(
      '[riverpod] failed  ${_describe(context)}',
      error: error,
      stackTrace: stackTrace,
    );
  }

  static String _describe(ProviderObserverContext context) {
    final provider = context.provider;
    return provider.name ?? provider.toString();
  }
}
