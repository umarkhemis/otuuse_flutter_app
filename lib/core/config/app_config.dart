import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;

/// Central place for app-wide configuration.
class AppConfig {
  // Set via --dart-define=API_BASE_URL=... at build/run time. Empty string
  // if not provided, in which case we fall back to a sensible per-platform
  // default below.
  static const String _envOverride = String.fromEnvironment('API_BASE_URL');

  /// Base URL for the backend API.
  ///
  /// This has to change depending on how you're running the app, because
  /// "localhost" means a different thing on each target:
  ///
  ///  - Android emulator: the emulator is its own little machine with its
  ///    own loopback address. It can't see your host machine's localhost.
  ///    Android maps 10.0.2.2 back to your host machine's localhost for
  ///    exactly this reason.
  ///  - Chrome (flutter run -d chrome) or iOS simulator: these share your
  ///    machine's network stack directly, so localhost works as-is.
  ///  - A physical phone (USB or wifi debugging): the phone is a genuinely
  ///    separate device on your network. Neither of the above works - you
  ///    need your machine's actual LAN IP (Windows: run `ipconfig`, look
  ///    for "IPv4 Address" under your active adapter), e.g.
  ///    http://192.168.1.42:5000/api/v1
  ///
  /// Override without editing this file:
  ///   flutter run --dart-define=API_BASE_URL=http://192.168.1.42:5000/api/v1
  static String get apiBaseUrl {
    if (_envOverride.isNotEmpty) return _envOverride;
    if (kIsWeb) return 'http://localhost:5000/api/v1';
    if (Platform.isAndroid) return 'http://10.0.2.2:5000/api/v1';
    return 'http://localhost:5000/api/v1';
  }
}
