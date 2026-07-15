import 'package:flet/flet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';

class RufletSpinKitExtension extends FletExtension {
  @override
  Widget? createWidget(Key? key, Control control) {
    if (control.type != 'RufletSpinKit') return null;
    return RufletSpinKitControl(key: key, control: control);
  }
}

class RufletSpinKitControl extends StatelessWidget {
  const RufletSpinKitControl({super.key, required this.control});

  final Control control;

  @override
  Widget build(BuildContext context) {
    final color =
        control.getColor('color', context) ??
        Theme.of(context).colorScheme.primary;
    final size = control.getDouble('size', 50)!;
    final duration = Duration(milliseconds: control.getInt('duration', 1200)!);
    final variant = control.getString('variant', 'rotating_circle')!;

    return LayoutControl(
      control: control,
      child: _spinner(variant, color, size, duration),
    );
  }

  Widget _spinner(String variant, Color color, double size, Duration duration) {
    switch (variant) {
      case 'rotating_plain':
        return SpinKitRotatingPlain(
          color: color,
          size: size,
          duration: duration,
        );
      case 'double_bounce':
        return SpinKitDoubleBounce(
          color: color,
          size: size,
          duration: duration,
        );
      case 'wave':
        return SpinKitWave(color: color, size: size, duration: duration);
      case 'wandering_cubes':
        return SpinKitWanderingCubes(
          color: color,
          size: size,
          duration: duration,
        );
      case 'fading_four':
        return SpinKitFadingFour(color: color, size: size, duration: duration);
      case 'fading_cube':
        return SpinKitFadingCube(color: color, size: size, duration: duration);
      case 'pulse':
        return SpinKitPulse(color: color, size: size, duration: duration);
      case 'chasing_dots':
        return SpinKitChasingDots(color: color, size: size, duration: duration);
      case 'three_bounce':
        return SpinKitThreeBounce(color: color, size: size, duration: duration);
      case 'circle':
        return SpinKitCircle(color: color, size: size, duration: duration);
      case 'cube_grid':
        return SpinKitCubeGrid(color: color, size: size, duration: duration);
      case 'fading_circle':
        return SpinKitFadingCircle(
          color: color,
          size: size,
          duration: duration,
        );
      case 'folding_cube':
        return SpinKitFoldingCube(color: color, size: size, duration: duration);
      case 'pumping_heart':
        return SpinKitPumpingHeart(
          color: color,
          size: size,
          duration: duration,
        );
      case 'hour_glass':
        return SpinKitHourGlass(color: color, size: size, duration: duration);
      case 'pouring_hour_glass':
        return SpinKitPouringHourGlass(
          color: color,
          size: size,
          duration: duration,
        );
      case 'pouring_hour_glass_refined':
        return SpinKitPouringHourGlassRefined(
          color: color,
          size: size,
          duration: duration,
        );
      case 'fading_grid':
        return SpinKitFadingGrid(color: color, size: size, duration: duration);
      case 'ring':
        return SpinKitRing(color: color, size: size, duration: duration);
      case 'ripple':
        return SpinKitRipple(color: color, size: size, duration: duration);
      case 'dual_ring':
        return SpinKitDualRing(color: color, size: size, duration: duration);
      case 'spinning_circle':
        return SpinKitSpinningCircle(
          color: color,
          size: size,
          duration: duration,
        );
      case 'spinning_lines':
        return SpinKitSpinningLines(
          color: color,
          size: size,
          duration: duration,
        );
      case 'square_circle':
        return SpinKitSquareCircle(
          color: color,
          size: size,
          duration: duration,
        );
      case 'three_in_out':
        return SpinKitThreeInOut(color: color, size: size, duration: duration);
      case 'dancing_square':
        return SpinKitDancingSquare(
          color: color,
          size: size,
          duration: duration,
        );
      case 'piano_wave':
        return SpinKitPianoWave(color: color, size: size, duration: duration);
      case 'pulsing_grid':
        return SpinKitPulsingGrid(color: color, size: size, duration: duration);
      case 'wave_spinner':
        return SpinKitWaveSpinner(color: color, size: size, duration: duration);
      case 'rotating_circle':
      default:
        return SpinKitRotatingCircle(
          color: color,
          size: size,
          duration: duration,
        );
    }
  }
}
