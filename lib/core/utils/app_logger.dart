import 'package:flutter/foundation.dart';

enum LogLevel { debug, info, warning, error }

class AppLogger {
  AppLogger._();

  static void debug(String message, [dynamic error, StackTrace? stackTrace]) {
    _log(LogLevel.debug, message, error, stackTrace);
  }

  static void info(String message, [dynamic error, StackTrace? stackTrace]) {
    _log(LogLevel.info, message, error, stackTrace);
  }

  static void warn(String message, [dynamic error, StackTrace? stackTrace]) {
    _log(LogLevel.warning, message, error, stackTrace);
  }

  static void error(String message, [dynamic error, StackTrace? stackTrace]) {
    _log(LogLevel.error, message, error, stackTrace);
  }

  static void _log(
    LogLevel level,
    String message,
    dynamic error,
    StackTrace? stackTrace,
  ) {
    final timestamp = DateTime.now().toIso8601String();
    final prefix = '[${level.name.toUpperCase()}] [$timestamp]';

    if (kDebugMode) {
      if (error != null) {
        debugPrint('$prefix $message | Error: $error');
        if (stackTrace != null) {
          debugPrint('$stackTrace');
        }
      } else {
        debugPrint('$prefix $message');
      }
    }

    // Plug-and-play hook for APM / Telemetry (e.g. Sentry / Firebase Crashlytics)
    if (level == LogLevel.error && error != null) {
      _reportToTelemetry(message, error, stackTrace);
    }
  }

  static void _reportToTelemetry(
    String message,
    dynamic error,
    StackTrace? stackTrace,
  ) {
    // Sentry.captureException(error, stackTrace: stackTrace);
  }
}
