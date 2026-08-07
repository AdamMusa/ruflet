// End-to-end cold start for a real Ruflet app.
//
// Earlier harnesses stopped at "the server bound a port", which is not the same
// as "the app works". This one speaks the actual Ruflet protocol: it opens the
// WebSocket and sends register_client, which the server answers only after
// running the whole application block and building its page. The reply is
// therefore proof that the packaged Ruby app really started and rendered, and
// its arrival is the honest time-to-usable-UI.
//
// Modes, selected with --dart-define=COLDBENCH_MODE=:
//   dart       today's design -- extract the project from assets, call
//              RufletRuntime.start, poll for the port file.
//   autostart  the platform booted the VM from +load; just ask where it is.
//
// Either way runApp happens first and nothing about the VM is awaited before
// the first frame.

import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:ruby_runtime/ruflet_runtime.dart';

const String kMode = String.fromEnvironment(
  'COLDBENCH_MODE',
  defaultValue: 'dart',
);

const MethodChannel _channel = MethodChannel('ruflet_runtime');

Future<double> sinceLoad() async {
  final value = await _channel.invokeMapMethod<Object?, Object?>('timeline');
  final raw = value?['sinceLoadMs'];
  return raw is num ? raw.toDouble() : -1.0;
}

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const BenchApp());
}

class BenchApp extends StatefulWidget {
  const BenchApp({super.key});

  @override
  State<BenchApp> createState() => _BenchAppState();
}

class _BenchAppState extends State<BenchApp> {
  final Map<String, double> _marks = {};
  String? _error;
  int _patchBytes = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      _marks['first_frame'] ??= await sinceLoad();
      _maybeReport();
    });
    unawaited(_run());
  }

  Future<void> _run() async {
    try {
      final Uri url =
          kMode == 'autostart' ? await _viaAutostart() : await _viaDart();
      _marks['server_bound'] = await sinceLoad();

      _patchBytes = await _registerAndAwaitPage(url);
      _marks['page_rendered'] = await sinceLoad();
    } catch (error, stack) {
      _error = '$error\n$stack';
    }
    if (mounted) setState(() {});
    _maybeReport();
  }

  Future<Uri> _viaAutostart() => RufletRuntime.serverUrl();

  Future<Uri> _viaDart() async {
    final workDir = await Directory.systemTemp.createTemp('coldbench_');
    final portPath = '${workDir.path}/server.port';
    final errorPath = '${workDir.path}/.runtime.error';
    final entrypoint = await _extractProject(workDir);
    _marks['assets_extracted'] = await sinceLoad();

    final status = await RufletRuntime.start(
      projectRoot: workDir.path,
      entrypoint: entrypoint,
      loadPaths: [workDir.path],
      environment: {
        'RUFLET_PORT': '0',
        'RUFLET_ASSETS_DIR': '${workDir.path}/assets',
        'RUFLET_RUNTIME_PORT_FILE': portPath,
        'RUFLET_RUNTIME_ERROR_FILE': errorPath,
        'RUFLET_SUPPRESS_SERVER_BANNER': '1',
      },
      errorFilePath: errorPath,
      stopSignalPath: '${workDir.path}/server.stop',
    );
    if (status.error.isNotEmpty) throw StateError(status.error);

    final deadline = DateTime.now().add(const Duration(seconds: 30));
    while (DateTime.now().isBefore(deadline)) {
      final file = File(portPath);
      if (await file.exists()) {
        final port = int.tryParse((await file.readAsString()).trim()) ?? 0;
        if (port > 0) return Uri.parse('http://127.0.0.1:$port');
      }
      final failure = File(errorPath);
      if (await failure.exists()) {
        final text = (await failure.readAsString()).trim();
        if (text.isNotEmpty) throw StateError(text);
      }
      await Future<void>.delayed(const Duration(milliseconds: 25));
    }
    throw TimeoutException('no port published');
  }

  /// Opens the Ruflet WebSocket and performs the register handshake. The server
  /// runs the application block before replying, so the reply means the app
  /// built its page. Returns the size of the page patch it sent back.
  Future<int> _registerAndAwaitPage(Uri url) async {
    final socket = await WebSocket.connect('ws://${url.host}:${url.port}/ws');
    final firstMessage = Completer<List<int>>();
    socket.listen(
      (Object? message) {
        if (!firstMessage.isCompleted && message is List<int>) {
          firstMessage.complete(message);
        }
      },
      onError: (Object error) {
        if (!firstMessage.isCompleted) firstMessage.completeError(error);
      },
      onDone: () {
        if (!firstMessage.isCompleted) {
          firstMessage.completeError(StateError('socket closed before reply'));
        }
      },
    );

    socket.add(_encodeRegisterClient());
    final reply = await firstMessage.future.timeout(
      const Duration(seconds: 30),
      onTimeout: () => throw TimeoutException('no register reply'),
    );
    await socket.close();

    // [action, payload] as a 2-element MessagePack array; action 1 is
    // register_client coming back with the page.
    if (reply.length < 2 || reply[0] != 0x92 || reply[1] != 0x01) {
      throw StateError(
        'unexpected reply: ${reply.take(8).map((b) => b.toRadixString(16)).join(' ')}',
      );
    }
    return reply.length;
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        body: Center(
          child: Text(_marks['page_rendered'] == null ? 'Starting...' : 'Ready'),
        ),
      ),
    );
  }

  void _maybeReport() {
    if (_marks['first_frame'] == null) return;
    if (_marks['page_rendered'] == null && _error == null) return;

    final parts = _marks.entries
        .map((e) => '${e.key}=${e.value.toStringAsFixed(1)}')
        .join(' ');
    if (_error != null) {
      stdout.writeln('COLDBENCH_ERROR mode=$kMode ${_error!.split('\n').first}');
    } else {
      stdout.writeln(
        'COLDBENCH mode=$kMode $parts page_patch_bytes=$_patchBytes',
      );
    }
    RufletRuntime.stop().whenComplete(() => exit(_error == null ? 0 : 1));
  }
}

/// Minimal MessagePack for the one message this harness sends:
/// [1, {session_id, page_name, page:{route,width,height,platform}}]
Uint8List _encodeRegisterClient() {
  final out = <int>[];

  void str(String value) {
    final bytes = value.codeUnits;
    if (bytes.length > 31) throw ArgumentError('fixstr only');
    out.add(0xA0 | bytes.length);
    out.addAll(bytes);
  }

  void uint16(int value) {
    out.add(0xCD);
    out.add((value >> 8) & 0xFF);
    out.add(value & 0xFF);
  }

  out.add(0x92); // array of 2
  out.add(0x01); // action: register_client

  out.add(0x80 | 3); // map of 3
  str('session_id');
  str('');
  str('page_name');
  str('');
  str('page');

  out.add(0x80 | 4); // map of 4
  str('route');
  str('/');
  str('width');
  uint16(1024);
  str('height');
  uint16(768);
  str('platform');
  str('macos');

  return Uint8List.fromList(out);
}

Future<String> _extractProject(Directory workDir) async {
  final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
  const prefix = 'assets/demo/';
  final assets =
      manifest.listAssets().where((asset) => asset.startsWith(prefix)).toList();
  if (assets.isEmpty) throw StateError('no packaged project under $prefix');

  for (final asset in assets) {
    final relative = asset.substring(prefix.length);
    if (relative.isEmpty) continue;
    final destination = File('${workDir.path}/$relative');
    await destination.parent.create(recursive: true);
    final data = await rootBundle.load(asset);
    await destination.writeAsBytes(
      data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
    );
  }

  final entrypoint = File('${workDir.path}/main.rb');
  if (!await entrypoint.exists()) throw StateError('no main.rb in payload');
  return entrypoint.path;
}
