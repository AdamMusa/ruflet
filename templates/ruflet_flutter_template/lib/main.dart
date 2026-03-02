import 'dart:async';

import 'package:flet/flet.dart';
import 'package:flet_ads/flet_ads.dart' as flet_ads;
// --FAT_CLIENT_START--
import 'package:flet_audio/flet_audio.dart' as flet_audio;
// --FAT_CLIENT_END--
import 'package:flet_audio_recorder/flet_audio_recorder.dart'
    as flet_audio_recorder;
import 'package:flet_camera/flet_camera.dart' as flet_camera;
import 'package:flet_charts/flet_charts.dart' as flet_charts;
import 'package:flet_code_editor/flet_code_editor.dart' as flet_code_editor;
import 'package:flet_color_pickers/flet_color_pickers.dart'
    as flet_color_picker;
import 'package:flet_datatable2/flet_datatable2.dart' as flet_datatable2;
import 'package:flet_flashlight/flet_flashlight.dart' as flet_flashlight;
import 'package:flet_geolocator/flet_geolocator.dart' as flet_geolocator;
import 'package:flet_lottie/flet_lottie.dart' as flet_lottie;
import 'package:flet_map/flet_map.dart' as flet_map;
import 'package:flet_permission_handler/flet_permission_handler.dart'
    as flet_permission_handler;
// --FAT_CLIENT_START--
// --FAT_CLIENT_END--
import 'package:flet_secure_storage/flet_secure_storage.dart'
    as flet_secure_storage;
// --FAT_CLIENT_START--
import 'package:flet_video/flet_video.dart' as flet_video;
// --FAT_CLIENT_END--
import 'package:flet_webview/flet_webview.dart' as flet_webview;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_web_plugins/url_strategy.dart';

import 'connection_probe.dart';

const bool isProduction = bool.fromEnvironment('dart.vm.product');
const int kRufletPort = 8550;
Tester? tester;

String normalizePageUrlForPlatform(String rawUrl) {
  final uri = Uri.tryParse(rawUrl);
  if (uri == null || uri.host.isEmpty) return rawUrl;

  final localHosts = {
    '0.0.0.0',
    '::',
    '[::]',
    '127.0.0.1',
    'localhost',
    '::1',
    '[::1]',
  };
  if (!localHosts.contains(uri.host)) {
    return rawUrl;
  }

  String host;
  switch (defaultTargetPlatform) {
    case TargetPlatform.android:
      host = '10.0.2.2';
      break;
    case TargetPlatform.macOS:
    case TargetPlatform.windows:
    case TargetPlatform.linux:
    case TargetPlatform.iOS:
    case TargetPlatform.fuchsia:
      host = 'localhost';
      break;
  }

  return uri.replace(host: host).toString();
}

String fallbackBackendUrl() =>
    normalizePageUrlForPlatform('http://0.0.0.0:$kRufletPort');

Future<void> main() async {
  if (isProduction) {
    // ignore: avoid_returning_null_for_void
    debugPrint = (String? message, {int? wrapWidth}) => null;
  }

  await setupDesktop();
  WidgetsFlutterBinding.ensureInitialized();

  if (kIsWeb) {
    final routeUrlStrategy = getFletRouteUrlStrategy();
    if (routeUrlStrategy == 'path') {
      usePathUrlStrategy();
    }
  }

  final extensions = <FletExtension>[
    flet_ads.Extension(),
    flet_audio_recorder.Extension(),
    flet_camera.Extension(),
    flet_charts.Extension(),
    flet_code_editor.Extension(),
    flet_color_picker.Extension(),
    flet_datatable2.Extension(),
    flet_flashlight.Extension(),
    flet_geolocator.Extension(),
    flet_lottie.Extension(),
    flet_map.Extension(),
    flet_permission_handler.Extension(),
    flet_secure_storage.Extension(),
    flet_webview.Extension(),

    // --FAT_CLIENT_START--
    flet_audio.Extension(),
    flet_video.Extension(),
    // --FAT_CLIENT_END--
  ];

  for (final extension in extensions) {
    extension.ensureInitialized();
  }

  final pageUrl = fallbackBackendUrl();

  await waitForBackend(pageUrl);

  runApp(
    FletApp(
      title: 'Ruflet',
      pageUrl: pageUrl,
      assetsDir: '',
      errorsHandler: FletAppErrorsHandler(),
      showAppStartupScreen: true,
      appStartupScreenMessage: 'Working...',
      appErrorMessage: 'The application encountered an error: {message}',
      extensions: extensions,
      multiView: isMultiView(),
      tester: tester,
    ),
  );
}

Future<void> waitForBackend(String pageUrl) async {
  if (kIsWeb) return;

  final deadline = DateTime.now().add(const Duration(seconds: 20));
  while (DateTime.now().isBefore(deadline)) {
    if (await canConnectToPageUrl(pageUrl)) return;
    await Future<void>.delayed(const Duration(milliseconds: 300));
  }
  debugPrint('Backend not reachable yet at $pageUrl. Flet client will retry.');
}

String? parseBackendUrl(String value) {
  if (value.isEmpty) return null;
  final raw = value.trim();
  final uri = Uri.tryParse(raw);
  if (uri != null &&
      (uri.scheme == 'http' ||
          uri.scheme == 'https' ||
          uri.scheme == 'ws' ||
          uri.scheme == 'wss') &&
      uri.host.isNotEmpty) {
    return normalizePageUrlForPlatform(raw);
  }
  final match = RegExp(r'(https?:\/\/[^\s]+|wss?:\/\/[^\s]+)').firstMatch(raw);
  if (match == null) return null;
  return normalizePageUrlForPlatform(match.group(0)!);
}
