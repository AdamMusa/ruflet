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
// --RIVE_IMPORT_START--
import 'package:flet_rive/flet_rive.dart' as flet_rive;
// --RIVE_IMPORT_END--
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
import 'package:mobile_scanner/mobile_scanner.dart';

import 'connection_probe.dart';

const bool isProduction = bool.fromEnvironment('dart.vm.product');

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
      // Android emulator reaches host machine via 10.0.2.2.
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

String normalizeUserUrl(String raw) {
  var input = raw.trim();
  if (input.isEmpty) return input;

  if (input.contains('://')) {
    final uri = Uri.tryParse(input);
    if (uri != null && (uri.scheme == 'ws' || uri.scheme == 'wss')) {
      // Accept websocket URLs from users, but keep page URL in http(s) form.
      final normalizedWsInput = uri.replace(
        scheme: uri.scheme == 'wss' ? 'https' : 'http',
        path: (uri.path.isEmpty || uri.path == '/ws') ? '' : uri.path,
        query: '',
        fragment: '',
      );
      input = normalizedWsInput.toString();
    }
    return normalizePageUrlForPlatform(input);
  }

  return normalizePageUrlForPlatform('http://$input');
}

String? parseUrlFromQrOrDeepLinkPayload(String payload) {
  final raw = payload.trim();
  if (raw.isEmpty) return null;

  if (raw.startsWith('http://') ||
      raw.startsWith('https://') ||
      raw.startsWith('ws://') ||
      raw.startsWith('wss://')) {
    return normalizeUserUrl(raw);
  }

  final uri = Uri.tryParse(raw);
  if (uri != null) {
    final nested = uri.queryParameters['url'];
    if (nested != null && nested.trim().isNotEmpty) {
      return normalizeUserUrl(nested);
    }
  }

  final match = RegExp(
    r'(https?:\/\/[^\s]+|wss?:\/\/[^\s]+)',
    caseSensitive: false,
  ).firstMatch(raw);
  if (match != null) {
    return normalizeUserUrl(match.group(0)!);
  }

  return normalizeUserUrl(raw);
}

void main([List<String>? args]) async {
  if (isProduction) {
    // ignore: avoid_returning_null_for_void
    debugPrint = (String? message, {int? wrapWidth}) => null;
  }

  await setupDesktop();

  WidgetsFlutterBinding.ensureInitialized();
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
    // --RIVE_EXTENSION_START--
    flet_rive.Extension(),
    // --RIVE_EXTENSION_END--
    flet_audio.Extension(),
    flet_video.Extension(),
    // --FAT_CLIENT_END--
  ];

  for (final extension in extensions) {
    extension.ensureInitialized();
  }

  var initialUrl = Uri.base.toString();

  if (kDebugMode) {
    initialUrl = const String.fromEnvironment(
      'FLET_URL',
      defaultValue: 'http://0.0.0.0:8550',
    );
  }

  if (kIsWeb) {
    debugPrint('Flet View is running in Web mode');
    final routeUrlStrategy = getFletRouteUrlStrategy();
    debugPrint('URL Strategy: $routeUrlStrategy');
    if (routeUrlStrategy == 'path') {
      usePathUrlStrategy();
    }
  } else {
    if (args != null && args.isNotEmpty) {
      initialUrl = args[0];
    } else if (!kDebugMode &&
        (defaultTargetPlatform == TargetPlatform.windows ||
            defaultTargetPlatform == TargetPlatform.macOS ||
            defaultTargetPlatform == TargetPlatform.linux)) {
      throw Exception(
        'In desktop mode Flet app URL must be provided as a first argument.',
      );
    }
  }

  final isDesktop = !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.windows ||
          defaultTargetPlatform == TargetPlatform.macOS ||
          defaultTargetPlatform == TargetPlatform.linux);
  if (kIsWeb || isDesktop) {
    initialUrl = 'http://localhost:8550';
  }

  initialUrl = normalizePageUrlForPlatform(initialUrl);
  debugPrint('Initial URL: $initialUrl');

  runApp(
    RufletBootstrapApp(
      initialUrl: initialUrl,
      extensions: extensions,
      assetsDir: '',
    ),
  );
}

class RufletBootstrapApp extends StatefulWidget {
  const RufletBootstrapApp({
    super.key,
    required this.initialUrl,
    required this.extensions,
    required this.assetsDir,
  });

  final String initialUrl;
  final List<FletExtension> extensions;
  final String assetsDir;

  @override
  State<RufletBootstrapApp> createState() => _RufletBootstrapAppState();
}

class _RufletBootstrapAppState extends State<RufletBootstrapApp> {
  late final FletAppErrorsHandler _errorsHandler;
  late final TextEditingController _urlController;
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();

  bool _connecting = true;
  bool _connected = false;
  String? _error;
  String? _activeUrl;

  bool get _isMobilePlatform =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  @override
  void initState() {
    super.initState();
    _errorsHandler = FletAppErrorsHandler();
    _urlController = TextEditingController(text: widget.initialUrl);
    if (!_isMobilePlatform) {
      _activeUrl = normalizePageUrlForPlatform(widget.initialUrl);
      _connected = true;
      _connecting = false;
      return;
    }
    _tryConnect(widget.initialUrl, auto: true);
  }

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  Future<void> _tryConnect(String rawUrl, {bool auto = false}) async {
    final url = normalizeUserUrl(rawUrl);
    if (url.isEmpty) {
      setState(() {
        _connecting = false;
        _error = 'Please enter server URL';
      });
      return;
    }

    setState(() {
      _connecting = true;
      _error = null;
    });

    if (kIsWeb) {
      setState(() {
        _activeUrl = url;
        _connected = true;
        _connecting = false;
      });
      return;
    }

    final ok = await canConnectToPageUrl(url);
    if (!mounted) return;

    if (ok) {
      setState(() {
        _activeUrl = url;
        _connected = true;
        _connecting = false;
      });
      return;
    }

    setState(() {
      _connecting = false;
      _error = auto
          ? (_isMobilePlatform
              ? 'Unable to connect to $url. On Android emulator use 10.0.2.2 (not 127.0.0.1).'
              : 'Unable to connect to $url')
          : 'Unable to connect to $url';
    });
  }

  Future<void> _scanQrAndConnect() async {
    final navigator = _navigatorKey.currentState;
    if (navigator == null) {
      setState(() {
        _error = 'Navigator not ready yet. Please try again.';
      });
      return;
    }

    final payload = await navigator.push<String>(
      MaterialPageRoute(builder: (_) => const QrScannerPage()),
    );
    if (!mounted || payload == null || payload.trim().isEmpty) return;
    final parsed = parseUrlFromQrOrDeepLinkPayload(payload);
    if (parsed == null || parsed.isEmpty) {
      setState(() {
        _error = 'Could not parse URL from scanned QR code';
      });
      return;
    }
    _urlController.text = parsed;
    _tryConnect(parsed);
  }

  @override
  Widget build(BuildContext context) {
    if (_connected && _activeUrl != null) {
      debugPrint('Page URL: $_activeUrl');
      return FletApp(
        title: 'Ruby Native',
        pageUrl: _activeUrl!,
        assetsDir: widget.assetsDir,
        errorsHandler: _errorsHandler,
        showAppStartupScreen: true,
        appStartupScreenMessage: 'Working...',
        appErrorMessage: 'The application encountered an error: {message}',
        extensions: widget.extensions,
        multiView: isMultiView(),
        tester: tester,
      );
    }

    return MaterialApp(
      navigatorKey: _navigatorKey,
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        appBar: AppBar(title: const Text('Ruflet Connect')),
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (_isMobilePlatform) ...[
                    TextField(
                      controller: _urlController,
                      decoration: const InputDecoration(
                        labelText: 'Server URL',
                        hintText: 'http://10.0.2.2:8550 or ws://10.0.2.2:8550/ws',
                      ),
                    ),
                  ] else ...[
                    Text('Target URL: ${_urlController.text}'),
                  ],
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      FilledButton(
                        onPressed: _connecting
                            ? null
                            : () => _tryConnect(_urlController.text),
                        child: Text(_isMobilePlatform ? 'Connect URL' : 'Retry'),
                      ),
                      if (_isMobilePlatform)
                        OutlinedButton.icon(
                          onPressed: _connecting ? null : _scanQrAndConnect,
                          icon: const Icon(Icons.qr_code_scanner),
                          label: const Text('Scan QR'),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (_connecting) const LinearProgressIndicator(minHeight: 3),
                  if (_error != null) ...[
                    const SizedBox(height: 10),
                    Text(
                      _error!,
                      style: const TextStyle(color: Colors.redAccent),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class QrScannerPage extends StatefulWidget {
  const QrScannerPage({super.key});

  @override
  State<QrScannerPage> createState() => _QrScannerPageState();
}

class _QrScannerPageState extends State<QrScannerPage> {
  final MobileScannerController _controller = MobileScannerController();
  bool _handled = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_handled) return;
    if (capture.barcodes.isEmpty) return;
    final code = capture.barcodes.first.rawValue?.trim();
    if (code == null || code.isEmpty) return;
    _handled = true;
    Navigator.of(context).pop(code);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Scan Ruflet QR')),
      body: Stack(
        fit: StackFit.expand,
        children: [
          MobileScanner(controller: _controller, onDetect: _onDetect),
          Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              width: double.infinity,
              color: Colors.black54,
              padding: const EdgeInsets.all(12),
              child: const Text(
                'Point camera at the QR shown by `ruflet run ...`',
                style: TextStyle(color: Colors.white),
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
