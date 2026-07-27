import "package:flet/flet.dart";
import "package:flutter/widgets.dart";
import "package:mobile_scanner/mobile_scanner.dart";

class ScannerConfiguration {
  const ScannerConfiguration({
    required this.autoStart,
    required this.autoZoom,
    required this.cameraFacing,
    required this.detectionSpeed,
    required this.detectionTimeoutMs,
    required this.fit,
    required this.formats,
    required this.invertImage,
    required this.returnImage,
    required this.scanWindow,
    required this.tapToFocus,
    required this.torchEnabled,
    required this.zoomScale,
  });

  factory ScannerConfiguration.fromControl(Control control) {
    return ScannerConfiguration(
      autoStart: control.getBool("auto_start", true)!,
      autoZoom: control.getBool("auto_zoom", false)!,
      cameraFacing: parseCameraFacing(control.getString("camera_facing")),
      detectionSpeed: parseDetectionSpeed(control.getString("detection_speed")),
      detectionTimeoutMs: control.getInt("detection_timeout", 250)!,
      fit: control.getBoxFit("fit", BoxFit.cover)!,
      formats: parseBarcodeFormats(control.get<List<dynamic>>("formats")),
      invertImage: control.getBool("invert_image", false)!,
      returnImage: control.getBool("return_image", false)!,
      scanWindow: parseScannerRect(control.get("scan_window")),
      tapToFocus: control.getBool("tap_to_focus", false)!,
      torchEnabled: control.getBool("torch_enabled", false)!,
      zoomScale: control.getDouble("zoom_scale", 1.0)!,
    );
  }

  final bool autoStart;
  final bool autoZoom;
  final CameraFacing cameraFacing;
  final DetectionSpeed detectionSpeed;
  final int detectionTimeoutMs;
  final BoxFit fit;
  final List<BarcodeFormat> formats;
  final bool invertImage;
  final bool returnImage;
  final Rect? scanWindow;
  final bool tapToFocus;
  final bool torchEnabled;
  final double zoomScale;

  @override
  bool operator ==(Object other) {
    return other is ScannerConfiguration &&
        autoStart == other.autoStart &&
        autoZoom == other.autoZoom &&
        cameraFacing == other.cameraFacing &&
        detectionSpeed == other.detectionSpeed &&
        detectionTimeoutMs == other.detectionTimeoutMs &&
        fit == other.fit &&
        _listEquals(formats, other.formats) &&
        invertImage == other.invertImage &&
        returnImage == other.returnImage &&
        scanWindow == other.scanWindow &&
        tapToFocus == other.tapToFocus &&
        torchEnabled == other.torchEnabled &&
        zoomScale == other.zoomScale;
  }

  @override
  int get hashCode => Object.hash(
        autoStart,
        autoZoom,
        cameraFacing,
        detectionSpeed,
        detectionTimeoutMs,
        fit,
        Object.hashAll(formats),
        invertImage,
        returnImage,
        scanWindow,
        tapToFocus,
        torchEnabled,
        zoomScale,
      );
}

CameraFacing parseCameraFacing(String? value) {
  return value?.toLowerCase() == "front"
      ? CameraFacing.front
      : CameraFacing.back;
}

DetectionSpeed parseDetectionSpeed(String? value) {
  switch (_normalizedEnumName(value)) {
    case "noduplicates":
      return DetectionSpeed.noDuplicates;
    case "unrestricted":
      return DetectionSpeed.unrestricted;
    default:
      return DetectionSpeed.normal;
  }
}

List<BarcodeFormat> parseBarcodeFormats(List<dynamic>? values) {
  if (values == null || values.isEmpty) return const <BarcodeFormat>[];

  final formats = <BarcodeFormat>[];
  for (final value in values) {
    final normalized = _normalizedEnumName(value?.toString());
    for (final format in BarcodeFormat.values) {
      if (_normalizedEnumName(format.name) == normalized &&
          !formats.contains(format)) {
        formats.add(format);
        break;
      }
    }
  }
  return formats;
}

Rect? parseScannerRect(dynamic value) {
  if (value is! Map) return null;

  final left = _asDouble(value["left"] ?? value["x"]);
  final top = _asDouble(value["top"] ?? value["y"]);
  final right = _asDouble(value["right"]);
  final bottom = _asDouble(value["bottom"]);
  final width = _asDouble(value["width"]);
  final height = _asDouble(value["height"]);

  if (left == null || top == null) return null;
  if (right != null && bottom != null) {
    return Rect.fromLTRB(left, top, right, bottom);
  }
  if (width != null && height != null) {
    return Rect.fromLTWH(left, top, width, height);
  }
  return null;
}

String _normalizedEnumName(String? value) =>
    value?.replaceAll(RegExp("[^a-zA-Z0-9]"), "").toLowerCase() ?? "";

double? _asDouble(dynamic value) {
  if (value is num) return value.toDouble();
  return double.tryParse(value?.toString() ?? "");
}

bool _listEquals<T>(List<T> left, List<T> right) {
  if (identical(left, right)) return true;
  if (left.length != right.length) return false;
  for (var index = 0; index < left.length; index += 1) {
    if (left[index] != right[index]) return false;
  }
  return true;
}
