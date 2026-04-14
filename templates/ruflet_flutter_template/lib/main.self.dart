import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flet/flet.dart';
import 'package:flet_ads/flet_ads.dart' as ruflet_ads;
// --FAT_CLIENT_START--
import 'package:flet_audio/flet_audio.dart' as ruflet_audio;
// --FAT_CLIENT_END--
import 'package:flet_audio_recorder/flet_audio_recorder.dart'
    as ruflet_audio_recorder;
import 'package:flet_camera/flet_camera.dart' as ruflet_camera;
import 'package:flet_charts/flet_charts.dart' as ruflet_charts;
import 'package:flet_code_editor/flet_code_editor.dart' as ruflet_code_editor;
import 'package:flet_color_pickers/flet_color_pickers.dart'
    as ruflet_color_picker;
import 'package:flet_datatable2/flet_datatable2.dart' as ruflet_datatable2;
import 'package:flet_flashlight/flet_flashlight.dart' as ruflet_flashlight;
import 'package:flet_geolocator/flet_geolocator.dart' as ruflet_geolocator;
import 'package:flet_lottie/flet_lottie.dart' as ruflet_lottie;
import 'package:flet_map/flet_map.dart' as ruflet_map;
import 'package:flet_permission_handler/flet_permission_handler.dart'
    as ruflet_permission_handler;
// --FAT_CLIENT_START--
// --FAT_CLIENT_END--
import 'package:flet_secure_storage/flet_secure_storage.dart'
    as ruflet_secure_storage;
// --FAT_CLIENT_START--
import 'package:flet_video/flet_video.dart' as ruflet_video;
// --FAT_CLIENT_END--
import 'package:flet_webview/flet_webview.dart' as ruflet_webview;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'package:ruby_runtime/ruby_runtime.dart';

import 'connection_probe.dart';

const bool isProduction = bool.fromEnvironment('dart.vm.product');
const int kRufletPort = 8550;
const String kConfiguredClientUrl = String.fromEnvironment(
  'RUFLET_BACKEND_URL',
  defaultValue: String.fromEnvironment('RUFLET_CLIENT_URL', defaultValue: ''),
);
const String kEmbeddedRubyAsset = 'assets/main.rb';
const String kEmbeddedProjectPrefix = 'assets/ruby_project/';
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

String resolveBackendUrl() {
  final configured = parseBackendUrl(kConfiguredClientUrl);
  if (configured != null) return configured;
  return fallbackBackendUrl();
}

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
    ruflet_ads.Extension(),
    ruflet_audio_recorder.Extension(),
    ruflet_camera.Extension(),
    ruflet_charts.Extension(),
    ruflet_code_editor.Extension(),
    ruflet_color_picker.Extension(),
    ruflet_datatable2.Extension(),
    ruflet_flashlight.Extension(),
    ruflet_geolocator.Extension(),
    ruflet_lottie.Extension(),
    ruflet_map.Extension(),
    ruflet_permission_handler.Extension(),
    ruflet_secure_storage.Extension(),
    ruflet_webview.Extension(),

    // --FAT_CLIENT_START--
    ruflet_audio.Extension(),
    ruflet_video.Extension(),
    // --FAT_CLIENT_END--
  ];

  for (final extension in extensions) {
    extension.ensureInitialized();
  }

  EmbeddedRufletRuntime? embeddedRuntime;
  var pageUrl = resolveBackendUrl();
  if (!kIsWeb && kConfiguredClientUrl.trim().isEmpty) {
    embeddedRuntime = await EmbeddedRufletRuntime.start();
    pageUrl = embeddedRuntime.pageUrl;
  }

  if (embeddedRuntime == null) {
    await waitForBackend(pageUrl);
  } else {
    await Future<void>.delayed(const Duration(milliseconds: 250));
  }

  runApp(
    TemplateApp(
      pageUrl: pageUrl,
      embeddedRuntime: embeddedRuntime,
      extensions: extensions,
    ),
  );
}

class TemplateApp extends StatefulWidget {
  const TemplateApp({
    super.key,
    required this.pageUrl,
    required this.extensions,
    this.embeddedRuntime,
  });

  final String pageUrl;
  final List<FletExtension> extensions;
  final EmbeddedRufletRuntime? embeddedRuntime;

  @override
  State<TemplateApp> createState() => _TemplateAppState();
}

class _TemplateAppState extends State<TemplateApp> {
  Timer? _serverErrorPoller;
  String? _lastEmbeddedServerError;

  @override
  void initState() {
    super.initState();
    if (widget.embeddedRuntime != null) {
      _serverErrorPoller = Timer.periodic(const Duration(seconds: 1), (_) async {
        final serverError = await RubyRuntime.lastFileServerError();
        if (!mounted || serverError.isEmpty || serverError == _lastEmbeddedServerError) {
          return;
        }
        _lastEmbeddedServerError = serverError;
        debugPrint('Embedded server error: $serverError');
      });
    }
  }

  @override
  void dispose() {
    _serverErrorPoller?.cancel();
    unawaited(widget.embeddedRuntime?.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final error = widget.embeddedRuntime?.error;
    if (error != null) {
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          appBar: AppBar(title: const Text('Ruflet')),
          body: Padding(
            padding: const EdgeInsets.all(16),
            child: SelectableText(error),
          ),
        ),
      );
    }

    return FletApp(
      title: 'Ruflet',
      pageUrl: widget.pageUrl,
      assetsDir: '',
      errorsHandler: FletAppErrorsHandler(),
      showAppStartupScreen: true,
      appStartupScreenMessage: 'Working...',
      appErrorMessage: 'The application encountered an error: {message}',
      extensions: widget.extensions,
      multiView: isMultiView(),
      tester: tester,
    );
  }
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

class EmbeddedRufletRuntime {
  EmbeddedRufletRuntime._({
    required this.pageUrl,
    required this.workDir,
    this.error,
  });

  final String pageUrl;
  final Directory workDir;
  final String? error;

  static Future<EmbeddedRufletRuntime> start() async {
    await _deleteStaleTempWorkDirs();
    final workDir = await Directory.systemTemp.createTemp('ruflet_template_');
    final stopPath = '${workDir.path}/server.stop';
    const pageUrl = 'http://127.0.0.1:$kRufletPort';

    try {
      await RubyRuntime.initialize();
      await RubyRuntime.eval("ENV['RUFLET_DEBUG'] ||= '1'; 'debug enabled'");
      final digestLength = await RubyRuntime.eval(
        "require 'digest/sha1'; Digest::SHA1.digest('abc').bytesize.to_s",
      );
      debugPrint('Embedded Digest::SHA1 bytesize: $digestLength');
      final serverPath = await _prepareProjectFiles(workDir);
      await RubyRuntime.startFileServer(serverPath, stopSignalPath: stopPath);
      final startupDeadline = DateTime.now().add(const Duration(seconds: 5));
      while (DateTime.now().isBefore(startupDeadline)) {
        if (await RubyRuntime.isFileServerRunning()) {
          return EmbeddedRufletRuntime._(pageUrl: pageUrl, workDir: workDir);
        }
        final serverError = await RubyRuntime.lastFileServerError();
        if (serverError.isNotEmpty) {
          throw Exception(serverError);
        }
        await Future<void>.delayed(const Duration(milliseconds: 100));
      }
      return EmbeddedRufletRuntime._(pageUrl: pageUrl, workDir: workDir);
    } catch (error, stackTrace) {
      return EmbeddedRufletRuntime._(
        pageUrl: pageUrl,
        workDir: workDir,
        error: 'Failed to start embedded Ruflet.\n$error\n$stackTrace',
      );
    }
  }

  Future<void> dispose() async {
    try {
      await RubyRuntime.stopFileServer();
    } catch (_) {}
    try {
      await RubyRuntime.reset();
    } catch (_) {}
    try {
      if (await workDir.exists()) {
        await workDir.delete(recursive: true);
      }
    } catch (_) {}
  }

  static Future<void> _deleteStaleTempWorkDirs() async {
    try {
      await for (final entity in Directory.systemTemp.list()) {
        if (entity is! Directory) continue;
        final name = entity.uri.pathSegments.isEmpty
            ? ''
            : entity.uri.pathSegments[entity.uri.pathSegments.length - 2];
        if (!name.startsWith('ruflet_template_')) continue;
        try {
          await entity.delete(recursive: true);
        } catch (_) {}
      }
    } catch (_) {}
  }

  static Future<String> _prepareProjectFiles(Directory workDir) async {
    final manifest = await _loadAssetManifest();
    final projectAssets = manifest.where((asset) => asset.startsWith(kEmbeddedProjectPrefix)).toList();

    if (projectAssets.isNotEmpty) {
      for (final asset in projectAssets) {
        final relative = asset.substring(kEmbeddedProjectPrefix.length);
        if (relative.isEmpty) continue;
        final destination = File('${workDir.path}/$relative');
        await destination.parent.create(recursive: true);
        final data = await rootBundle.load(asset);
        await destination.writeAsBytes(
          data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
        );
      }
      return '${workDir.path}/main.rb';
    }

    final serverPath = '${workDir.path}/main.rb';
    final source = await rootBundle.loadString(kEmbeddedRubyAsset);
    debugPrint(_describeEmbeddedAsset(source, serverPath));
    await File(serverPath).writeAsString(source);
    return serverPath;
  }

  static Future<List<String>> _loadAssetManifest() async {
    try {
      final raw = await rootBundle.loadString('AssetManifest.json');
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) {
        return decoded.keys.toList();
      }
    } catch (_) {}
    return const [];
  }

  static String _describeEmbeddedAsset(String source, String serverPath) {
    final lines = source.split('\n');
    final preview = lines
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .take(3)
        .join(' | ');
    return 'Embedded Ruby asset $kEmbeddedRubyAsset -> $serverPath '
        '(${source.length} chars) preview: $preview';
  }
}
