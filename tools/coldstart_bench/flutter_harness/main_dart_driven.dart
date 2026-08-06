// Cold-start harness for the embedded Ruflet runtime.
//
// Replicates the startup path the Flutter template uses in self-contained mode
// (lib/main.self.dart in ruflet-template): extract the packaged Ruby project out
// of the asset bundle, call RufletRuntime.start, then poll for the port file.
// Every stage is timestamped against the plugin's +load, which runs before the
// Flutter engine exists -- so the numbers say how much of startup happens
// before the VM is asked to boot at all.
//
// Prints one machine-readable line and exits, so it can be run repeatedly to
// get a distribution rather than a single sample.

import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:ruby_runtime/ruflet_runtime.dart';

const MethodChannel _channel = MethodChannel('ruflet_runtime');

/// Milliseconds since the plugin dylib loaded.
Future<double> sinceLoad() async {
  final value = await _channel.invokeMapMethod<Object?, Object?>('timeline');
  final raw = value?['sinceLoadMs'];
  return raw is num ? raw.toDouble() : -1.0;
}

Future<void> main() async {
  final marks = <String, double>{};

  WidgetsFlutterBinding.ensureInitialized();
  marks['binding_ready'] = await sinceLoad();

  final workDir = await Directory.systemTemp.createTemp('coldbench_');
  final portPath = '${workDir.path}/server.port';
  final errorPath = '${workDir.path}/.runtime.error';
  final stopPath = '${workDir.path}/server.stop';

  final entrypoint = await _extractProject(workDir);
  marks['assets_extracted'] = await sinceLoad();

  marks['start_called'] = await sinceLoad();
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
    stopSignalPath: stopPath,
  );
  marks['start_returned'] = await sinceLoad();

  if (status.error.isNotEmpty) {
    stdout.writeln('COLDBENCH_ERROR ${status.error}');
    exit(1);
  }

  final port = await _waitForPort(portPath, errorPath);
  marks['port_bound'] = await sinceLoad();

  stdout.writeln(
    'COLDBENCH ${marks.entries.map((e) => '${e.key}=${e.value.toStringAsFixed(1)}').join(' ')} port=$port',
  );

  await RufletRuntime.stop();
  try {
    await workDir.delete(recursive: true);
  } catch (_) {}
  exit(0);
}

/// Mirrors the template's `_waitForRuntimePort`, including its 25ms poll
/// interval -- the interval is part of what the current design costs.
Future<int> _waitForPort(String portPath, String errorPath) async {
  final portFile = File(portPath);
  final errorFile = File(errorPath);
  final deadline = DateTime.now().add(const Duration(seconds: 20));

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
      throw StateError('runtime stopped before binding');
    }
    await Future<void>.delayed(const Duration(milliseconds: 25));
  }
  throw TimeoutException('no port published');
}

/// Mirrors the template's `_prepareProjectFiles`: one awaited rootBundle.load
/// plus one awaited write per packaged file.
Future<String> _extractProject(Directory workDir) async {
  final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
  const prefix = 'assets/demo/';
  final assets =
      manifest.listAssets().where((asset) => asset.startsWith(prefix)).toList();
  if (assets.isEmpty) {
    throw StateError('no packaged project found under $prefix');
  }

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
  if (!await entrypoint.exists()) {
    throw StateError('packaged project has no main.rb');
  }
  return entrypoint.path;
}
