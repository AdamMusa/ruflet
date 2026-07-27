import 'package:flet/flet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';

class SpinKitControl extends StatefulWidget {
  final Control control;

  const SpinKitControl({super.key, required this.control});

  @override
  State<SpinKitControl> createState() => _SpinKitControlState();
}

class _SpinKitControlState extends State<SpinKitControl> {
  @override
  Widget build(BuildContext context) {
    final color = widget.control.getColor("color", context) ??
        Theme.of(context).primaryColor;
    final size = widget.control.getDouble("size", 50.0)!;
    final isRufletControl = widget.control.type == "RufletSpinKit";
    final duration = isRufletControl
        ? Duration(
            milliseconds: widget.control.getInt("duration", 1200)!,
          )
        : widget.control.getDuration("duration");
    final spinnerType = isRufletControl
        ? spinkitTypeForVariant(widget.control.getString("variant"))
        : widget.control.type;

    final lineWidth = widget.control.getDouble("line_width");
    final borderWidth = widget.control.getDouble("border_width");
    final itemCount = widget.control.getInt("item_count");
    final waveType = parseEnum(SpinKitWaveType.values,
        widget.control.getString("wave_type"), SpinKitWaveType.start)!;

    Widget spinner;

    switch (spinnerType) {
      case "SpinKitRotatingPlain":
        spinner = SpinKitRotatingPlain(
          color: color,
          size: size,
          duration: duration ?? const Duration(milliseconds: 1200),
        );
        break;
      case "SpinKitDoubleBounce":
        spinner = SpinKitDoubleBounce(
          color: color,
          size: size,
          duration: duration ?? const Duration(milliseconds: 2000),
        );
        break;
      case "SpinKitWave":
        spinner = SpinKitWave(
          color: color,
          size: size,
          duration: duration ?? const Duration(milliseconds: 1200),
          itemCount: itemCount ?? 5,
          type: waveType,
        );
        break;
      case "SpinKitWanderingCubes":
        spinner = SpinKitWanderingCubes(
          color: color,
          size: size,
          duration: duration ?? const Duration(milliseconds: 1800),
        );
        break;
      case "SpinKitFadingFour":
        spinner = SpinKitFadingFour(
          color: color,
          size: size,
          duration: duration ?? const Duration(milliseconds: 1200),
        );
        break;
      case "SpinKitFadingCube":
        spinner = SpinKitFadingCube(
          color: color,
          size: size,
          duration: duration ?? const Duration(milliseconds: 1200),
        );
        break;
      case "SpinKitPulse":
        spinner = SpinKitPulse(
          color: color,
          size: size,
          duration: duration ?? const Duration(milliseconds: 1000),
        );
        break;
      case "SpinKitChasingDots":
        spinner = SpinKitChasingDots(
          color: color,
          size: size,
          duration: duration ?? const Duration(milliseconds: 2000),
        );
        break;
      case "SpinKitThreeBounce":
        spinner = SpinKitThreeBounce(
          color: color,
          size: size,
          duration: duration ?? const Duration(milliseconds: 1400),
        );
        break;
      case "SpinKitCircle":
        spinner = SpinKitCircle(
          color: color,
          size: size,
          duration: duration ?? const Duration(milliseconds: 1200),
        );
        break;
      case "SpinKitCubeGrid":
        spinner = SpinKitCubeGrid(
          color: color,
          size: size,
          duration: duration ?? const Duration(milliseconds: 1200),
        );
        break;
      case "SpinKitFadingCircle":
        spinner = SpinKitFadingCircle(
          color: color,
          size: size,
          duration: duration ?? const Duration(milliseconds: 1200),
        );
        break;
      case "SpinKitRotatingCircle":
        spinner = SpinKitRotatingCircle(
          color: color,
          size: size,
          duration: duration ?? const Duration(milliseconds: 1200),
        );
        break;
      case "SpinKitFoldingCube":
        spinner = SpinKitFoldingCube(
          color: color,
          size: size,
          duration: duration ?? const Duration(milliseconds: 2400),
        );
        break;
      case "SpinKitPumpingHeart":
        spinner = SpinKitPumpingHeart(
          color: color,
          size: size,
          duration: duration ?? const Duration(milliseconds: 1000),
        );
        break;
      case "SpinKitHourGlass":
        spinner = SpinKitHourGlass(
          color: color,
          size: size,
          duration: duration ?? const Duration(milliseconds: 1200),
        );
        break;
      case "SpinKitPouringHourGlass":
        spinner = SpinKitPouringHourGlass(
          color: color,
          size: size,
          duration: duration ?? const Duration(milliseconds: 2400),
        );
        break;
      case "SpinKitPouringHourGlassRefined":
        spinner = SpinKitPouringHourGlassRefined(
          color: color,
          size: size,
          duration: duration ?? const Duration(milliseconds: 2400),
        );
        break;
      case "SpinKitFadingGrid":
        spinner = SpinKitFadingGrid(
          color: color,
          size: size,
          duration: duration ?? const Duration(milliseconds: 1200),
        );
        break;
      case "SpinKitRing":
        spinner = SpinKitRing(
          color: color,
          size: size,
          duration: duration ?? const Duration(milliseconds: 1200),
          lineWidth: lineWidth ?? 7.0,
        );
        break;
      case "SpinKitRipple":
        spinner = SpinKitRipple(
          color: color,
          size: size,
          duration: duration ?? const Duration(milliseconds: 1800),
          borderWidth: borderWidth ?? 6.0,
        );
        break;
      case "SpinKitDualRing":
        spinner = SpinKitDualRing(
          color: color,
          size: size,
          duration: duration ?? const Duration(milliseconds: 1200),
          lineWidth: lineWidth ?? 7.0,
        );
        break;
      case "SpinKitSpinningCircle":
        spinner = SpinKitSpinningCircle(
          color: color,
          size: size,
          duration: duration ?? const Duration(milliseconds: 1200),
        );
        break;
      case "SpinKitSpinningLines":
        spinner = SpinKitSpinningLines(
          color: color,
          size: size,
          duration: duration ?? const Duration(milliseconds: 1200),
          lineWidth: lineWidth ?? 2.0,
        );
        break;
      case "SpinKitSquareCircle":
        spinner = SpinKitSquareCircle(
          color: color,
          size: size,
          duration: duration ?? const Duration(milliseconds: 500),
        );
        break;
      case "SpinKitThreeInOut":
        spinner = SpinKitThreeInOut(
          color: color,
          size: size,
          duration: duration ?? const Duration(milliseconds: 1500),
        );
        break;
      case "SpinKitDancingSquare":
        spinner = SpinKitDancingSquare(
          color: color,
          size: size,
          duration: duration ?? const Duration(milliseconds: 1200),
        );
        break;
      case "SpinKitPianoWave":
        spinner = SpinKitPianoWave(
          color: color,
          size: size,
          duration: duration ?? const Duration(milliseconds: 1200),
          itemCount: itemCount ?? 5,
        );
        break;
      case "SpinKitPulsingGrid":
        spinner = SpinKitPulsingGrid(
          color: color,
          size: size,
          duration: duration ?? const Duration(milliseconds: 1200),
        );
        break;
      case "SpinKitWaveSpinner":
        spinner = SpinKitWaveSpinner(
          color: color,
          size: size,
          duration: duration ?? const Duration(milliseconds: 1200),
        );
        break;
      default:
        spinner = SpinKitRotatingCircle(
          color: color,
          size: size,
          duration: duration ?? const Duration(milliseconds: 1200),
        );
    }

    return LayoutControl(control: widget.control, child: spinner);
  }
}

String spinkitTypeForVariant(String? value) {
  final words = (value ?? "rotating_circle")
      .trim()
      .split(RegExp(r"[^a-zA-Z0-9]+"))
      .where((word) => word.isNotEmpty);
  final suffix = words
      .map((word) =>
          "${word[0].toUpperCase()}${word.substring(1).toLowerCase()}")
      .join();
  return "SpinKit${suffix.isEmpty ? 'RotatingCircle' : suffix}";
}
