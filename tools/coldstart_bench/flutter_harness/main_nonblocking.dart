// Verifies that Flutter never waits for the embedded VM.
//
// The platform layer boots the VM from +load, in parallel with the engine, so
// nothing on the Dart side should block on it: runApp is called immediately and
// the first frame renders while the VM is still booting. The server URL arrives
// later and swaps in.
//
// Reports two independent timestamps against the plugin's dylib load:
//
//   first_frame  when Flutter painted. Must not move when the VM gets slower.
//   url_ready    when the embedded server bound its port.
//
// Run this against a fast and a slow VM: if first_frame holds steady while
// url_ready moves, Flutter is genuinely not waiting.

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:ruby_runtime/ruflet_runtime.dart';

const MethodChannel _channel = MethodChannel('ruflet_runtime');

Future<double> sinceLoad() async {
  final value = await _channel.invokeMapMethod<Object?, Object?>('timeline');
  final raw = value?['sinceLoadMs'];
  return raw is num ? raw.toDouble() : -1.0;
}

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  // Nothing is awaited before this point: the VM is booting on the platform
  // side and Dart does not look at it until the widget tree asks.
  runApp(const BenchApp());
}

class BenchApp extends StatefulWidget {
  const BenchApp({super.key});

  @override
  State<BenchApp> createState() => _BenchAppState();
}

class _BenchAppState extends State<BenchApp> {
  double? _firstFrame;
  double? _urlReady;
  String? _error;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      _firstFrame ??= await sinceLoad();
      _report();
    });

    // Requested here, not awaited before runApp.
    RufletRuntime.serverUrl().then((url) async {
      _urlReady = await sinceLoad();
      if (mounted) setState(() {});
      _report();
    }).catchError((Object error) {
      _error = error.toString();
      _report();
    });
  }

  void _report() {
    if (_firstFrame == null) return;
    if (_urlReady == null && _error == null) return;

    stdout.writeln(
      'COLDBENCH first_frame=${_firstFrame!.toStringAsFixed(1)} '
      'url_ready=${(_urlReady ?? -1).toStringAsFixed(1)}'
      '${_error == null ? '' : ' error=${_error!.replaceAll('\n', ' ')}'}',
    );
    RufletRuntime.stop().whenComplete(() => exit(_error == null ? 0 : 1));
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        body: Center(
          child: Text(_urlReady == null ? 'Starting...' : 'Ready'),
        ),
      ),
    );
  }
}
