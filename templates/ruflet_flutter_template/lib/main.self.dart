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
import 'package:flet_rive/flet_rive.dart' as ruflet_rive;
// --FAT_CLIENT_START--
// --FAT_CLIENT_END--
import 'package:flet_secure_storage/flet_secure_storage.dart'
    as ruflet_secure_storage;
import 'package:flet_spinkit/flet_spinkit.dart' as ruflet_spinkit;
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
import 'ruflet_file_picker_service.dart';

const bool isProduction = bool.fromEnvironment('dart.vm.product');
const int kRufletPort = 8550;
const String kConfiguredClientUrl = String.fromEnvironment(
  'RUFLET_BACKEND_URL',
  defaultValue: String.fromEnvironment('RUFLET_CLIENT_URL', defaultValue: ''),
);
const String kEmbeddedProjectName = String.fromEnvironment(
  'RUFLET_EMBEDDED_PROJECT',
  defaultValue: '',
);
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
    RufletFilePickerExtension(),
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
    ruflet_rive.Extension(),
    ruflet_secure_storage.Extension(),
    ruflet_spinkit.Extension(),
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
      _serverErrorPoller = Timer.periodic(const Duration(seconds: 1), (
        _,
      ) async {
        final serverError = await RubyRuntime.lastFileServerError();
        if (!mounted ||
            serverError.isEmpty ||
            serverError == _lastEmbeddedServerError) {
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
    var pageUrl = 'http://127.0.0.1:$kRufletPort';

    try {
      await RubyRuntime.initialize();
      final serverPath = await _prepareProjectFiles(workDir);
      await RubyRuntime.startFileServer(serverPath, stopSignalPath: stopPath);
      final startupDeadline = DateTime.now().add(const Duration(seconds: 5));
      while (DateTime.now().isBefore(startupDeadline)) {
        final discoveredPort = await _discoverServerPort();
        if (discoveredPort != null && discoveredPort > 0) {
          pageUrl = 'http://127.0.0.1:$discoveredPort';
        }
        // While the plugin reports bound ports, wait for the real port
        // instead of probing the default one: another Ruflet server (e.g. a
        // CRuby dev server) may already be answering on it and the client
        // would silently attach to the wrong app.
        final portKnown = discoveredPort == null || discoveredPort > 0;
        if (portKnown &&
            await RubyRuntime.isFileServerRunning() &&
            await canConnectToPageUrl(
              pageUrl,
              timeout: const Duration(milliseconds: 250),
            )) {
          return EmbeddedRufletRuntime._(pageUrl: pageUrl, workDir: workDir);
        }
        final serverError = await RubyRuntime.lastFileServerError();
        if (serverError.isNotEmpty) {
          throw Exception(serverError);
        }
        await Future<void>.delayed(const Duration(milliseconds: 100));
      }
      throw TimeoutException(
        'Embedded Ruflet server did not become reachable at $pageUrl.',
      );
    } catch (error, stackTrace) {
      return EmbeddedRufletRuntime._(
        pageUrl: pageUrl,
        workDir: workDir,
        error: 'Failed to start embedded Ruflet.\n$error\n$stackTrace',
      );
    }
  }

  /// Port the embedded server actually bound, reported by the ruby_runtime
  /// plugin. Returns 0 until the server binds, or null on platforms whose
  /// plugin predates port reporting — those keep polling the default
  /// [kRufletPort].
  static Future<int?> _discoverServerPort() async {
    try {
      return await RubyRuntime.serverPort();
    } catch (_) {
      return null;
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
    final embeddedProjectPrefix = _embeddedProjectPrefix(manifest);
    final projectAssets = manifest
        .where((asset) => asset.startsWith(embeddedProjectPrefix))
        .toList();

    if (projectAssets.isEmpty) {
      throw StateError(
        'No packaged Ruby project was found under $embeddedProjectPrefix. '
        '${_describeRubyAssets(manifest)} '
        'Run `ruflet build --self` so Ruflet can package the real Ruby app.',
      );
    }

    for (final asset in projectAssets) {
      final relative = asset.substring(embeddedProjectPrefix.length);
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

  /// Resolves where the packaged Ruby project lives in the asset bundle.
  /// Accepts every layout Ruflet has shipped, so apps built by any CLI
  /// version keep booting: the explicit dart-define, a discovered
  /// `assets/<project>/main.rb`, the legacy `assets/ruby_project/` folder,
  /// and the legacy flat `assets/main.rb`.
  static String _embeddedProjectPrefix(List<String> manifest) {
    final name = kEmbeddedProjectName.trim();
    if (name.isNotEmpty) {
      return 'assets/$name/';
    }

    final discovered = manifest
        .where(
          (asset) => asset.startsWith('assets/') && asset.endsWith('/main.rb'),
        )
        .map((asset) => asset.substring(0, asset.length - 'main.rb'.length))
        .where((prefix) => prefix != 'assets/')
        .where((prefix) => !prefix.startsWith('assets/icons/'))
        .toSet()
        .toList();

    if (discovered.length == 1) {
      return discovered.single;
    }
    if (discovered.length > 1) {
      // assets/ruby_project/ is the legacy placeholder folder; a real
      // packaged project alongside it always wins.
      final real = discovered
          .where((prefix) => prefix != 'assets/ruby_project/')
          .toList();
      if (real.length == 1) {
        return real.single;
      }
      throw StateError(
        'Multiple packaged Ruby projects found (${discovered.join(', ')}). '
        'Set the RUFLET_EMBEDDED_PROJECT dart define to choose one.',
      );
    }

    // Legacy flat layout: a single main.rb directly under assets/.
    if (manifest.contains('assets/main.rb')) {
      return 'assets/';
    }

    throw StateError(
      'Could not find a packaged Ruby project in the asset bundle. '
      '${_describeRubyAssets(manifest)} '
      'Run `ruflet build --self` so Ruflet can package the real Ruby app, '
      'or set the RUFLET_EMBEDDED_PROJECT dart define.',
    );
  }

  static String _describeRubyAssets(List<String> manifest) {
    if (manifest.isEmpty) {
      return 'The asset manifest could not be read or is empty.';
    }
    final rubyAssets =
        manifest.where((asset) => asset.endsWith('.rb')).take(8).toList();
    if (rubyAssets.isEmpty) {
      return 'The bundle contains no .rb assets at all.';
    }
    return 'Ruby assets present: ${rubyAssets.join(', ')}.';
  }

  static Future<List<String>> _loadAssetManifest() async {
    try {
      final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
      return manifest.listAssets();
    } catch (_) {}
    return const [];
  }
}
