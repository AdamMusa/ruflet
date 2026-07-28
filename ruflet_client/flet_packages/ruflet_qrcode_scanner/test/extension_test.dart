import "package:flet/flet.dart";
import "package:flutter_test/flutter_test.dart";
import "package:ruflet_qrcode_scanner/src/extension.dart";
import "package:ruflet_qrcode_scanner/src/qrcode_scanner.dart";

void main() {
  final backend = FletBackend(
    pageUri: Uri.parse("http://localhost"),
    assetsDir: "",
    extensions: const [],
    multiView: false,
  );

  Control control(String type) => Control(
        id: 1,
        type: type,
        properties: const {},
        backend: backend,
      );

  test("creates the scanner for Flet's normalized control type", () {
    expect(
      Extension().createWidget(null, control("QrcodeScanner")),
      isA<QrCodeScannerControl>(),
    );
  });

  test("keeps accepting the legacy wire control type", () {
    expect(
      Extension().createWidget(null, control("qrcode_scanner")),
      isA<QrCodeScannerControl>(),
    );
  });

  test("ignores unrelated controls", () {
    expect(Extension().createWidget(null, control("Text")), isNull);
  });
}
