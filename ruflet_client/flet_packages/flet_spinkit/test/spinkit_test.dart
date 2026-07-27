import "package:flet_spinkit/src/spinkit.dart";
import "package:flutter_test/flutter_test.dart";

void main() {
  test("maps Ruflet snake-case variants to Flet SpinKit control types", () {
    expect(spinkitTypeForVariant(null), "SpinKitRotatingCircle");
    expect(spinkitTypeForVariant("double_bounce"), "SpinKitDoubleBounce");
    expect(
      spinkitTypeForVariant("pouring_hour_glass_refined"),
      "SpinKitPouringHourGlassRefined",
    );
  });
}
