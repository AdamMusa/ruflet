import "package:flet/flet.dart";
import "package:flutter/widgets.dart";

import "qrcode_scanner.dart";

class Extension extends FletExtension {
  @override
  Widget? createWidget(Key? key, Control control) {
    if (control.type == "qrcode_scanner") {
      return QrCodeScannerControl(key: key, control: control);
    }
    return null;
  }
}
