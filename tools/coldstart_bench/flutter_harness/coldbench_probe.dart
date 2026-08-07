// Shared startup instrumentation for the A/B comparison.
//
// Timestamps come from the plugin's `timeline` method, which counts from the
// point the platform layer loaded -- before the Flutter engine existed. Both
// startup designs are measured on that same origin, so the numbers are
// directly comparable.
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

const MethodChannel _probeChannel = MethodChannel('ruflet_runtime');

Future<double> rufletSinceLoad() async {
  try {
    final value = await _probeChannel.invokeMapMethod<Object?, Object?>('timeline');
    final raw = value?['sinceLoadMs'];
    return raw is num ? raw.toDouble() : -1.0;
  } catch (_) {
    return -1.0;
  }
}

/// Logs a stage on the platform timeline. Printed with a fixed prefix so it can
/// be picked out of stdout or logcat.
Future<void> rufletMark(String stage) async {
  final ms = await rufletSinceLoad();
  // ignore: avoid_print
  print('COLDBENCH_MARK $stage=${ms.toStringAsFixed(1)}');
}

/// Logs the stage once the next frame has actually been painted.
void rufletMarkAfterFrame(String stage) {
  WidgetsBinding.instance.addPostFrameCallback((_) => rufletMark(stage));
}
