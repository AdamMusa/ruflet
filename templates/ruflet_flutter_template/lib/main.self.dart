import 'dart:async';

import 'package:flet/flet.dart';
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
import 'package:ruflet_qrcode_scanner/ruflet_qrcode_scanner.dart'
    as ruflet_qrcode_scanner;
// --FAT_CLIENT_START--
// --FAT_CLIENT_END--
import 'package:flet_secure_storage/flet_secure_storage.dart'
    as ruflet_secure_storage;
// --FAT_CLIENT_START--
import 'package:flet_video/flet_video.dart' as ruflet_video;
// --FAT_CLIENT_END--
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'package:ruby_runtime/ruflet_runtime.dart';

import 'ruflet_file_picker_service.dart';
import 'ruflet_spinkit.dart';
import 'package:flet_webview/flet_webview.dart' as ruflet_webview;

const bool isProduction = bool.fromEnvironment('dart.vm.product');
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

String resolveBackendUrl() {
  final configured = parseBackendUrl(kConfiguredClientUrl);
  if (configured != null) return configured;
  return '';
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
    RufletSpinKitExtension(),
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
    ruflet_qrcode_scanner.Extension(),
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
        final status = await RufletRuntime.status();
        final serverError = status.error;
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
    final workDir = await Directory.systemTemp.createTemp('ruflet_template_');
    final stopPath = '${workDir.path}/server.stop';
    final portPath = '${workDir.path}/server.port';
    var pageUrl = '';

    try {
      final entrypoint = await _prepareProjectFiles(workDir);
      final errorFile = '${workDir.path}/.runtime.error';
      final status = await RufletRuntime.start(
        projectRoot: workDir.path,
        entrypoint: entrypoint,
        loadPaths: [workDir.path],
        environment: {
          'RUFLET_PORT': '0',
          'RUFLET_ASSETS_DIR': '${workDir.path}/assets',
          'RUFLET_RUNTIME_PORT_FILE': portPath,
          'RUFLET_RUNTIME_ERROR_FILE': errorFile,
        },
        errorFilePath: errorFile,
        stopSignalPath: stopPath,
      );
      if (status.error.isNotEmpty) {
        throw StateError(status.error);
      }
      final port = await _waitForRuntimePort(portPath, errorFile);
      pageUrl = 'http://127.0.0.1:$port';
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
      await RufletRuntime.stop();
    } catch (_) {}
    try {
      if (await workDir.exists()) {
        await workDir.delete(recursive: true);
      }
    } catch (_) {}
  }

  static Future<int> _waitForRuntimePort(
    String portPath,
    String errorPath,
  ) async {
    final portFile = File(portPath);
    final errorFile = File(errorPath);
    final deadline = DateTime.now().add(const Duration(seconds: 15));

    while (DateTime.now().isBefore(deadline)) {
      if (await portFile.exists()) {
        final port = int.tryParse((await portFile.readAsString()).trim()) ?? 0;
        if (port > 0) return port;
      }
      if (await errorFile.exists()) {
        final error = (await errorFile.readAsString()).trim();
        if (error.isNotEmpty) throw StateError(error);
      }
      final status = await RufletRuntime.status();
      if (status.error.isNotEmpty) throw StateError(status.error);
      if (!status.running) {
        throw StateError('Embedded Ruflet server stopped before binding.');
      }
      await Future<void>.delayed(const Duration(milliseconds: 25));
    }
    throw TimeoutException('Embedded Ruflet server did not publish its port.');
  }

  static Future<String> _prepareProjectFiles(Directory workDir) async {
    final manifest = await _loadAssetManifest();
    final embeddedProjectPrefix = _embeddedProjectPrefix(manifest);
    final projectAssets = manifest.where((asset) {
      if (!asset.startsWith(embeddedProjectPrefix)) return false;
      final relative = asset.substring(embeddedProjectPrefix.length);
      return !relative.split('/').any((part) => part.startsWith('.'));
    }).toList();

    if (projectAssets.isEmpty) {
      throw StateError(
        'No packaged Ruby project was found under $embeddedProjectPrefix. '
        '${_describeRufletAssets(manifest)} '
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

    for (final name in ['main.rb', 'main.mrb']) {
      final entrypoint = File('${workDir.path}/$name');
      if (await entrypoint.exists()) {
        return entrypoint.path;
      }
    }
    throw StateError(
      'The packaged Ruflet project does not contain main.rb. '
      'Run `ruflet build --self` to package the app.',
    );
  }

  static String _embeddedProjectPrefix(List<String> manifest) {
    final name = kEmbeddedProjectName.trim();
    if (name.isNotEmpty) {
      return 'assets/$name/';
    }

    final discovered = manifest
        .where(
          (asset) =>
              asset.startsWith('assets/') &&
              (asset.endsWith('/main.rb') || asset.endsWith('/main.mrb')),
        )
        .map((asset) => asset.substring(0, asset.lastIndexOf('/') + 1))
        .toSet()
        .toList();

    // A Ruflet app may contain nested example/plugin applications. They are
    // part of the top-level payload and must not be treated as competing
    // embedded projects. Keep only roots that are not descendants of another
    // discovered root.
    final roots = discovered
        .where(
          (candidate) => !discovered.any(
            (other) => other != candidate && candidate.startsWith(other),
          ),
        )
        .toList();

    if (roots.length == 1) {
      return roots.single;
    }
    if (roots.length > 1) {
      throw StateError(
        'Multiple packaged Ruflet projects found (${roots.join(', ')}). '
        'Set the RUFLET_EMBEDDED_PROJECT dart define to choose one.',
      );
    }

    throw StateError(
      'Could not find main.rb in the asset bundle. '
      '${_describeRufletAssets(manifest)} '
      'Run `ruflet build --self` so Ruflet can package the app, '
      'or set the RUFLET_EMBEDDED_PROJECT dart define.',
    );
  }

  static String _describeRufletAssets(List<String> manifest) {
    if (manifest.isEmpty) {
      return 'The asset manifest could not be read or is empty.';
    }
    final rufletAssets = manifest
        .where((asset) => asset.endsWith('.rb') || asset.endsWith('.mrb'))
        .take(8)
        .toList();
    if (rufletAssets.isEmpty) {
      return 'The bundle contains no Ruby sources.';
    }
    return 'Ruby sources present: ${rufletAssets.join(', ')}.';
  }

  static Future<List<String>> _loadAssetManifest() async {
    try {
      final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
      return manifest.listAssets();
    } catch (_) {}
    return const [];
  }
}
