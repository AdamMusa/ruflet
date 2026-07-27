import 'package:flutter/material.dart';

import '../extensions/control.dart';
import '../models/control.dart';
import '../utils/animations.dart';
import '../utils/borders.dart';
import '../utils/box.dart';
import '../utils/colors.dart';
import '../utils/misc.dart';
import '../utils/numbers.dart';
import '../widgets/error.dart';

class BottomSheetControl extends StatefulWidget {
  final Control control;

  BottomSheetControl({Key? key, required this.control})
      : super(key: key ?? ValueKey("control_${control.id}"));

  @override
  State<BottomSheetControl> createState() => _BottomSheetControlState();
}

class _BottomSheetControlState extends State<BottomSheetControl> {
  ModalRoute<dynamic>? _sheetRoute;
  bool _opening = false;
  bool _closeRequested = false;

  Control get control => widget.control;

  void _closeOwnedRoute(BuildContext context) {
    _closeRequested = true;
    control.updateProperties({"_open": false}, python: false);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      final route = _sheetRoute;
      if (route?.isActive == true && route?.navigator != null) {
        route!.navigator!.pop();
      } else if (!_opening) {
        final navigator = Navigator.maybeOf(context);
        if (navigator?.canPop() == true) navigator!.pop();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    debugPrint("BottomSheet build: ${control.id}");

    bool lastOpen = control.getBool("_open", false)!;
    var open = control.getBool("open", false)!;

    var maintainBottomViewInsetsPadding =
        control.getBool("maintain_bottom_view_insets_padding", true)!;
    final fullscreen = control.getBool("fullscreen", false)!;
    final scrollable = fullscreen || control.getBool("scrollable", false)!;
    final draggable = control.getBool("draggable", false)!;

    if (open && !lastOpen) {
      _opening = true;
      _closeRequested = false;
      control.updateProperties({"_open": open}, python: false);

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;

        ModalRoute<dynamic>? sheetRoute;
        showModalBottomSheet<void>(
                context: context,
                builder: (context) {
                  sheetRoute ??= ModalRoute.of(context);
                  _sheetRoute = sheetRoute;
                  _opening = false;
                  if (_closeRequested) {
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (mounted && sheetRoute?.isActive == true) {
                        sheetRoute?.navigator?.pop();
                      }
                    });
                  }

                  var content = control.buildWidget("content");

                  if (content == null) {
                    return const ErrorControl(
                        "BottomSheet.content must be visible");
                  }

                  if (maintainBottomViewInsetsPadding) {
                    content = Padding(
                      padding: EdgeInsets.only(
                          bottom: MediaQuery.of(context).viewInsets.bottom),
                      child: content,
                    );
                  }

                  if (fullscreen) {
                    content = SizedBox.expand(child: content);
                  }

                  return content;
                },
                isDismissible: control.getBool("dismissible", true)!,
                backgroundColor: control.getColor("bgcolor", context),
                elevation: control.getDouble("elevation"),
                isScrollControlled: scrollable,
                enableDrag: draggable,
                barrierColor: control.getColor("barrier_color", context),
                sheetAnimationStyle:
                    control.getAnimationStyle("animation_style"),
                constraints: fullscreen
                    ? null
                    : control.getBoxConstraints("size_constraints"),
                showDragHandle: control.getBool("show_drag_handle", false)!,
                clipBehavior: control.getClipBehavior("clip_behavior"),
                shape: control.getOutlinedBorder("shape", Theme.of(context)),
                useSafeArea: control.getBool("use_safe_area", true)!)
            .then((value) {
          (sheetRoute?.completed ?? Future<void>.value()).then((_) {
            _sheetRoute = null;
            _opening = false;
            _closeRequested = false;
            control.updateProperties({"_open": false}, python: false);
            control.updateProperties({"open": false});
            control.triggerEvent("dismiss");
          });
        });
      });
    } else if (open != lastOpen && lastOpen) {
      _closeOwnedRoute(context);
    }

    return const SizedBox.shrink();
  }
}
