import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// Helper to render Solar icons from bundled SVG assets
class SolarIcon extends StatelessWidget {
  final String name;
  final double size;
  final Color? color;

  const SolarIcon(this.name, {super.key, this.size = 24, this.color});

  @override
  Widget build(BuildContext context) {
    return SvgPicture.asset(
      'assets/icons/$name.svg',
      width: size,
      height: size,
      colorFilter: color != null
          ? ColorFilter.mode(color!, BlendMode.srcIn)
          : null,
    );
  }
}

/// Icon name constants
class SolarIcons {
  static const verifiedCheck = 'verified-check-bold';
  static const lockKeyhole = 'lock-keyhole-bold';
  static const bolt = 'bolt-bold';
  static const userCheckRounded = 'user-check-rounded-bold';
  static const chatRoundDots = 'chat-round-dots-bold';
  static const backspace = 'backspace-bold';
  static const sun2 = 'sun-2-bold';
  static const moon = 'moon-bold';
  static const shieldCheck = 'shield-check-bold';
  static const faceScanCircle = 'face-scan-circle-bold';
  static const questionCircle = 'question-circle-bold';
  static const camera = 'camera-bold';
  static const eye = 'eye-bold';
  static const checkCircle = 'check-circle-bold';
}
