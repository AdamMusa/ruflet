import "package:flet/flet.dart";
import "package:flutter/material.dart";
import "package:flutter_test/flutter_test.dart";
import "package:provider/provider.dart";

void main() {
  testWidgets("open false closes the modal bottom sheet", (tester) async {
    final backend = FletBackend(
      pageUri: Uri.parse("http://localhost"),
      assetsDir: "",
      extensions: const [],
      multiView: false,
    );
    addTearDown(backend.dispose);

    final sheet = Control.fromMap(
      {
        "_c": "BottomSheet",
        "_i": 100,
        "open": true,
        "content": {
          "_c": "Text",
          "_i": 101,
          "value": "Sheet content",
        },
      },
      backend,
    );

    await tester.pumpWidget(
      ChangeNotifierProvider<FletBackend>.value(
        value: backend,
        child: MaterialApp(
          home: Scaffold(body: ControlWidget(control: sheet)),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text("Sheet content"), findsOneWidget);

    sheet.update({"open": false}, shouldNotify: true);
    await tester.pumpAndSettle();

    expect(find.text("Sheet content"), findsNothing);
  });

  testWidgets("open false closes a bottom sheet while it is opening",
      (tester) async {
    final backend = FletBackend(
      pageUri: Uri.parse("http://localhost"),
      assetsDir: "",
      extensions: const [],
      multiView: false,
    );
    addTearDown(backend.dispose);

    final sheet = Control.fromMap(
      {
        "_c": "BottomSheet",
        "_i": 100,
        "open": true,
        "content": {
          "_c": "Text",
          "_i": 101,
          "value": "Sheet content",
        },
      },
      backend,
    );

    await tester.pumpWidget(
      ChangeNotifierProvider<FletBackend>.value(
        value: backend,
        child: MaterialApp(
          home: Scaffold(body: ControlWidget(control: sheet)),
        ),
      ),
    );
    sheet.update({"open": false}, shouldNotify: true);
    await tester.pumpAndSettle();

    expect(find.text("Sheet content"), findsNothing);
  });
}
