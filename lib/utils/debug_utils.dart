import 'package:flutter/foundation.dart';

class DebugUtils {
  /// Log a debug message. Only prints in debug mode.
  static void log(String message, [String? tag]) {
    if (kDebugMode) {
      final String prefix = tag != null ? '[$tag] ' : '';
      debugPrint('$prefix$message');
    }
  }

  /// Log an error message. Only prints in debug mode.
  static void logError(String message, [Object? error, String? tag]) {
    if (kDebugMode) {
      final String prefix = tag != null ? '[$tag] ' : '';
      debugPrint('$prefix[ERROR] $message');
      if (error != null) {
        debugPrint('$prefix[ERROR] Details: $error');
      }
    }
  }

  /// Log an info message. Only prints in debug mode.
  static void logInfo(String message, [String? tag]) {
    if (kDebugMode) {
      final String prefix = tag != null ? '[$tag] ' : '';
      debugPrint('$prefix[INFO] $message');
    }
  }
}
