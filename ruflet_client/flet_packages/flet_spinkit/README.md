# flet_spinkit

Bundled Flet extension for Ruflet loading indicators. The package owns the
`flutter_spinkit` dependency and exports the standard `FletExtension`
entrypoint:

```dart
import "package:flet_spinkit/flet_spinkit.dart" as flet_spinkit;

final extensions = <FletExtension>[
  flet_spinkit.Extension(),
];
```

It accepts both the individual Flet SpinKit wire types and Ruflet's generic
`RufletSpinKit` wire type with a snake-case `variant` property. The reusable
client depends on this package; it does not import `flutter_spinkit` directly.
