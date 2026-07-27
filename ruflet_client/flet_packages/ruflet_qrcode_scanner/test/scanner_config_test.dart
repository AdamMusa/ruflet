import "package:flutter/widgets.dart";
import "package:flutter_test/flutter_test.dart";
import "package:mobile_scanner/mobile_scanner.dart";
import "package:ruflet_qrcode_scanner/src/scanner_config.dart";

void main() {
  test("parses scanner enums using Ruby snake_case names", () {
    expect(parseCameraFacing("front"), CameraFacing.front);
    expect(parseCameraFacing("unknown"), CameraFacing.back);
    expect(parseDetectionSpeed("no_duplicates"), DetectionSpeed.noDuplicates);
    expect(parseDetectionSpeed("unrestricted"), DetectionSpeed.unrestricted);
  });

  test("filters and deduplicates barcode formats", () {
    final formats = parseBarcodeFormats(<dynamic>[
      "qr_code",
      "data_matrix",
      "qrCode",
      "not_a_format",
    ]);

    expect(formats,
        <BarcodeFormat>[BarcodeFormat.qrCode, BarcodeFormat.dataMatrix]);
  });

  test("parses scan windows from both supported hash shapes", () {
    expect(
      parseScannerRect(<String, dynamic>{
        "left": 10,
        "top": 20,
        "right": 110,
        "bottom": 220,
      }),
      const Rect.fromLTRB(10, 20, 110, 220),
    );
    expect(
      parseScannerRect(<String, dynamic>{
        "x": 10,
        "y": 20,
        "width": 100,
        "height": 200,
      }),
      const Rect.fromLTWH(10, 20, 100, 200),
    );
  });
}
