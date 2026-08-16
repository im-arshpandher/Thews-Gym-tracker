import 'dart:developer' as developer;
import 'package:flutter/foundation.dart';

/// Lightweight, ANSI color-coded, pretty logging utility for Thews.
class AppLogger {
  static const String _reset = '\x1B[0m';
  static const String _green = '\x1B[32m';
  static const String _yellow = '\x1B[33m';
  static const String _red = '\x1B[31m';
  static const String _blue = '\x1B[34m';
  static const String _cyan = '\x1B[36m';
  static const String _magenta = '\x1B[35m';

  /// Log informational events
  static void info(String message, {String tag = 'THEWS'}) {
    if (kDebugMode) {
      developer.log(
        '$_blueℹ️  [INFO] [$tag] $message$_reset',
        name: tag,
      );
    }
  }

  /// Log successful operations
  static void success(String message, {String tag = 'THEWS'}) {
    if (kDebugMode) {
      developer.log(
        '$_green✅ [SUCCESS] [$tag] $message$_reset',
        name: tag,
      );
    }
  }

  /// Log warnings or non-fatal anomalies
  static void warning(String message, {String tag = 'THEWS'}) {
    if (kDebugMode) {
      developer.log(
        '$_yellow⚠️  [WARN] [$tag] $message$_reset',
        name: tag,
      );
    }
  }

  /// Log errors with optional stacktrace
  static void error(
    String message, {
    dynamic error,
    StackTrace? stackTrace,
    String tag = 'THEWS',
  }) {
    if (kDebugMode) {
      developer.log(
        '$_red❌ [ERROR] [$tag] $message${error != null ? ' | $error' : ''}$_reset',
        name: tag,
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  /// Log database queries / operations
  static void db(String message) {
    if (kDebugMode) {
      developer.log(
        '$_cyan💾 [DB] $message$_reset',
        name: 'DATABASE',
      );
    }
  }

  /// Log synchronization events
  static void sync(String message) {
    if (kDebugMode) {
      developer.log(
        '$_magenta🔄 [SYNC] $message$_reset',
        name: 'SYNC',
      );
    }
  }
}
