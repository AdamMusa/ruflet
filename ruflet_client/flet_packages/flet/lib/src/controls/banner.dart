import 'package:flutter/material.dart';

import '../extensions/control.dart';
import '../models/control.dart';
import '../utils/colors.dart';
import '../utils/edge_insets.dart';
import '../utils/numbers.dart';
import '../utils/text.dart';
import '../widgets/error.dart';

class BannerControl extends StatelessWidget {
  final Control control;

  const BannerControl({super.key, required this.control});

  MaterialBanner _createBanner(BuildContext context) {
    return MaterialBanner(
      leading: control.buildIconOrWidget("leading"),
      leadingPadding: control.getPadding("leading_padding"),
      content: control.buildTextOrWidget("content")!,
      padding: control.getPadding("content_padding"),
      actions: control.buildWidgets("actions"),
      forceActionsBelow: control.getBool("force_actions_below", false)!,
      backgroundColor: control.getColor("bgcolor", context),
      contentTextStyle: control.getTextStyle(
        "content_text_style",
        Theme.of(context),
      ),
      shadowColor: control.getColor("shadow_color", context),
      dividerColor: control.getColor("divider_color", context),
      elevation: control.getDouble("elevation"),
      minActionBarHeight: control.getDouble("min_action_bar_height", 52.0)!,
      margin: control.getMargin("margin"),
      onVisible: () {
        control.triggerEvent("visible");
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final lastOpen = control.getBool("_open", false)!;
    final open = control.getBool("open", false)!;

    if (open && !lastOpen) {
      if (control.get("content") == null) {
        return const ErrorControl(
          "Banner.content must be provided and visible",
        );
      } else if (control.children("actions").isEmpty) {
        return const ErrorControl(
          "Banner.actions must be provided and at least one action should be visible",
        );
      }

      final generation = control.getInt("_show_generation", 0)! + 1;
      control.updateProperties({
        "_open": true,
        "_dismissed": false,
        "_show_generation": generation,
      }, python: false);

      WidgetsBinding.instance.addPostFrameCallback((_) {
        ScaffoldMessenger.of(context).removeCurrentMaterialBanner();
        ScaffoldMessenger.of(
          context,
        ).showMaterialBanner(_createBanner(context)).closed.then((reason) {
          debugPrint("Closing Banner(${control.id}) with reason: $reason");
          final isCurrentCycle =
              control.getInt("_show_generation", 0) == generation;
          if (isCurrentCycle && control.get("_dismissed") != true) {
            control.updateProperties({"_dismissed": true}, python: false);
            debugPrint("Dismissing Banner(${control.id}) with reason: $reason");
            //_open = false;
            control.updateProperties({"_open": false}, python: false);
            control.updateProperties({"open": false});
            control.triggerEvent("dismiss");
          }
        });
      });
    } else if (!open && lastOpen) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ScaffoldMessenger.of(context).hideCurrentMaterialBanner();
        control.updateProperties({"_open": false}, python: false);
      });
    }
    return const SizedBox.shrink();
  }
}
