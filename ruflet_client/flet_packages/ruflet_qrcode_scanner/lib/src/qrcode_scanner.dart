import "dart:async";
import "dart:convert";

import "package:flet/flet.dart";
import "package:flutter/material.dart";
import "package:mobile_scanner/mobile_scanner.dart";

import "scanner_config.dart";

class QrCodeScannerControl extends StatefulWidget {
  const QrCodeScannerControl({
    super.key,
    required this.control,
  });

  final Control control;

  @override
  State<QrCodeScannerControl> createState() => _QrCodeScannerControlState();
}

class _QrCodeScannerControlState extends State<QrCodeScannerControl>
    with WidgetsBindingObserver {
  late ScannerConfiguration _configuration;
  late MobileScannerController _controller;
  StreamSubscription<BarcodeCapture>? _barcodeSubscription;
  Future<void> _replacementQueue = Future<void>.value();
  late bool _shouldRun;
  bool _disposed = false;

  @override
  void initState() {
    super.initState();
    _configuration = ScannerConfiguration.fromControl(widget.control);
    _shouldRun = _configuration.autoStart;
    _controller = _createController(_configuration);
    WidgetsBinding.instance.addObserver(this);
    widget.control.addInvokeMethodListener(_invokeMethod);
    _listenForBarcodes();
    if (_shouldRun) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _resumeScanner());
    }
  }

  @override
  void didUpdateWidget(covariant QrCodeScannerControl oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.control != widget.control) {
      oldWidget.control.removeInvokeMethodListener(_invokeMethod);
      widget.control.addInvokeMethodListener(_invokeMethod);
    }

    final next = ScannerConfiguration.fromControl(widget.control);
    if (next != _configuration) {
      if (next.autoStart != _configuration.autoStart) {
        _shouldRun = next.autoStart;
      }
      _configuration = next;
      _replacementQueue = _replacementQueue
          .then((_) => _replaceController(next))
          .catchError((Object error, StackTrace stackTrace) {
        _triggerError(error, stackTrace);
      });
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!_controller.value.hasCameraPermission) return;

    switch (state) {
      case AppLifecycleState.resumed:
        if (_shouldRun) unawaited(_resumeScanner());
      case AppLifecycleState.inactive:
        unawaited(_pauseScanner());
      case AppLifecycleState.detached:
      case AppLifecycleState.hidden:
      case AppLifecycleState.paused:
        return;
    }
  }

  MobileScannerController _createController(
      ScannerConfiguration configuration) {
    return MobileScannerController(
      autoStart: false,
      autoZoom: configuration.autoZoom,
      detectionSpeed: configuration.detectionSpeed,
      detectionTimeoutMs: configuration.detectionTimeoutMs,
      facing: configuration.cameraFacing,
      formats: configuration.formats,
      invertImage: configuration.invertImage,
      initialZoom: configuration.zoomScale,
      returnImage: configuration.returnImage,
      torchEnabled: configuration.torchEnabled,
    );
  }

  void _listenForBarcodes() {
    _barcodeSubscription = _controller.barcodes.listen(
      _handleBarcodeCapture,
      onError: (Object error, StackTrace stackTrace) {
        _triggerError(error, stackTrace);
      },
    );
  }

  Future<void> _replaceController(ScannerConfiguration next) async {
    await _barcodeSubscription?.cancel();
    if (_controller.value.isRunning) await _controller.stop();
    _controller.dispose();
    if (_disposed) return;

    _controller = _createController(next);
    _listenForBarcodes();
    if (mounted) setState(() {});
    if (_shouldRun) await _resumeScanner();
  }

  Future<void> _resumeScanner() async {
    if (_disposed ||
        _controller.value.isRunning ||
        _controller.value.isStarting) {
      return;
    }
    await _controller.start();
  }

  Future<void> _pauseScanner() async {
    if (_disposed || !_controller.value.isRunning) return;
    await _controller.stop();
  }

  void _handleBarcodeCapture(BarcodeCapture capture) {
    if (!widget.control.getBool("on_detect", false)!) return;

    final barcodes = capture.barcodes.map(_serializeBarcode).toList();
    widget.control.triggerEvent("detect", <String, dynamic>{
      "value":
          capture.barcodes.isEmpty ? null : capture.barcodes.first.rawValue,
      "barcodes": barcodes,
      if (capture.image != null) "image": base64Encode(capture.image!),
    });
  }

  Map<String, dynamic> _serializeBarcode(Barcode barcode) {
    return <String, dynamic>{
      "raw_value": barcode.rawValue,
      "display_value": barcode.displayValue,
      "format": barcode.format.name,
      "type": barcode.type.name,
      if (barcode.corners.isNotEmpty)
        "corners": barcode.corners
            .map((point) => <String, double>{"x": point.dx, "y": point.dy})
            .toList(),
    };
  }

  void _triggerError(Object error, [StackTrace? stackTrace]) {
    if (!widget.control.getBool("on_error", false)!) return;
    widget.control.triggerEvent("error", <String, dynamic>{
      "message": error.toString(),
      "type": error.runtimeType.toString(),
      if (stackTrace != null) "stack_trace": stackTrace.toString(),
    });
  }

  Future<dynamic> _invokeMethod(String name, dynamic args) async {
    try {
      switch (name) {
        case "start":
          _shouldRun = true;
          await _resumeScanner();
          return true;
        case "stop":
          _shouldRun = false;
          await _pauseScanner();
          return true;
        case "switch_camera":
          await _controller.switchCamera();
          return true;
        case "toggle_torch":
          await _controller.toggleTorch();
          return true;
        case "set_zoom_scale":
          final value = _doubleValue(args?["value"]);
          if (value == null) throw ArgumentError("value is required");
          await _controller.setZoomScale(value);
          return true;
        case "reset_zoom_scale":
          await _controller.resetZoomScale();
          return true;
        default:
          throw ArgumentError("Unknown qrcode_scanner method: $name");
      }
    } catch (error, stackTrace) {
      _triggerError(error, stackTrace);
      rethrow;
    }
  }

  double? _doubleValue(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? "");
  }

  @override
  void dispose() {
    _disposed = true;
    WidgetsBinding.instance.removeObserver(this);
    widget.control.removeInvokeMethodListener(_invokeMethod);
    _barcodeSubscription?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scanner = MobileScanner(
      controller: _controller,
      fit: _configuration.fit,
      scanWindow: _configuration.scanWindow,
      tapToFocus: _configuration.tapToFocus,
      useAppLifecycleState: false,
      errorBuilder: (context, error) {
        _triggerError(error);
        return Center(child: Text(error.toString()));
      },
    );
    return LayoutControl(control: widget.control, child: scanner);
  }
}
