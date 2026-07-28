import "package:flet/flet.dart";
import "package:flutter/widgets.dart";

import "qrcode_scanner.dart";

class Extension extends FletExtension {
  @override
  Widget? createWidget(Key? key, Control control) {
    switch (control.type) {
      case "QrcodeScanner":
      case "qrcode_scanner":
        return QrCodeScannerControl(key: key, control: control);
      default:
        return null;
    }
  }
}
