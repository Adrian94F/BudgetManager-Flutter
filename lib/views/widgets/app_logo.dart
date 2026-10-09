import 'package:flutter/material.dart';

/// The square "BM" logo, drawn from the same vector as the Android
/// launcher icon (android/app/src/main/res/drawable/bm.xml).
class AppLogo extends StatelessWidget {
  const AppLogo({super.key, this.size = 72});

  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: size,
      child: const CustomPaint(painter: _LogoPainter()),
    );
  }
}

class _LogoPainter extends CustomPainter {
  const _LogoPainter();

  static const _viewport = 750.0;
  static const _background = Color(0xFF3F51B5);

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = _background);
    canvas.scale(size.width / _viewport, size.height / _viewport);
    canvas.drawPath(_letters, Paint()..color = Colors.white);
  }

  @override
  bool shouldRepaint(_LogoPainter oldDelegate) => false;
}

final Path _letters = Path()
  // Letter B
  ..moveTo(67.4, 509.24)
  ..lineTo(67.4, 499.24)
  ..cubicTo(79.13, 498.44, 87.53, 497.31, 92.59, 495.85)
  ..cubicTo(97.66, 494.38, 101.2, 491.38, 103.2, 486.85)
  ..cubicTo(105.2, 482.31, 106.2, 474.84, 106.2, 464.44)
  ..lineTo(106.2, 274.04)
  ..cubicTo(106.2, 263.64, 105.2, 256.18, 103.2, 251.65)
  ..cubicTo(101.2, 247.11, 97.73, 244.11, 92.79, 242.65)
  ..cubicTo(87.86, 241.18, 79.4, 240.04, 67.4, 239.24)
  ..lineTo(67.4, 229.24)
  ..lineTo(198.6, 229.24)
  ..cubicTo(234.07, 229.24, 261.74, 234.64, 281.6, 245.44)
  ..cubicTo(301.47, 256.25, 311.4, 273.91, 311.4, 298.44)
  ..cubicTo(311.4, 314.7, 306.06, 327.9, 295.4, 338.04)
  ..cubicTo(284.73, 348.17, 269.4, 355.11, 249.4, 358.83)
  ..cubicTo(271.53, 363.11, 288.73, 371.64, 300.99, 384.44)
  ..cubicTo(313.26, 397.25, 319.4, 412.31, 319.4, 429.65)
  ..cubicTo(319.4, 454.98, 309.0, 474.58, 288.2, 488.44)
  ..cubicTo(267.39, 502.31, 239.79, 509.24, 205.4, 509.24)
  ..close()
  ..moveTo(157.81, 247.24)
  ..cubicTo(154.06, 247.24, 151.13, 248.31, 148.99, 250.44)
  ..cubicTo(146.87, 252.58, 145.81, 255.51, 145.81, 259.24)
  ..lineTo(145.81, 350.04)
  ..lineTo(202.2, 350.04)
  ..cubicTo(245.67, 350.04, 267.4, 332.84, 267.4, 298.44)
  ..cubicTo(267.4, 280.58, 261.86, 267.58, 250.79, 259.44)
  ..cubicTo(239.73, 251.31, 222.73, 247.24, 199.81, 247.24)
  ..close()
  ..moveTo(145.81, 367.65)
  ..lineTo(145.81, 479.24)
  ..cubicTo(145.81, 482.97, 146.87, 485.9, 148.99, 488.04)
  ..cubicTo(151.13, 490.17, 154.06, 491.24, 157.81, 491.24)
  ..lineTo(205.4, 491.24)
  ..cubicTo(228.6, 491.24, 246.06, 485.78, 257.79, 474.85)
  ..cubicTo(269.53, 463.91, 275.4, 448.84, 275.4, 429.65)
  ..cubicTo(275.4, 410.98, 269.6, 395.98, 257.99, 384.65)
  ..cubicTo(246.4, 373.31, 230.47, 367.65, 210.2, 367.65)
  ..close()
  ..moveTo(145.81, 367.65)
  // Letter M
  ..moveTo(565.4, 499.24)
  ..cubicTo(577.4, 498.44, 585.87, 497.31, 590.8, 495.85)
  ..cubicTo(595.73, 494.38, 599.2, 491.38, 601.2, 486.85)
  ..cubicTo(603.2, 482.31, 604.2, 474.84, 604.2, 464.44)
  ..lineTo(604.2, 259.24)
  ..lineTo(513.0, 509.24)
  ..lineTo(499.8, 509.24)
  ..lineTo(408.59, 259.65)
  ..lineTo(408.59, 464.44)
  ..cubicTo(408.59, 474.84, 409.59, 482.31, 411.59, 486.85)
  ..cubicTo(413.59, 491.38, 417.12, 494.38, 422.19, 495.85)
  ..cubicTo(427.26, 497.31, 435.66, 498.44, 447.4, 499.24)
  ..lineTo(447.4, 509.24)
  ..lineTo(349.0, 509.24)
  ..lineTo(349.0, 499.24)
  ..cubicTo(360.72, 498.44, 369.12, 497.31, 374.19, 495.85)
  ..cubicTo(379.26, 494.38, 382.86, 491.38, 385.0, 486.85)
  ..cubicTo(387.13, 482.31, 388.2, 474.84, 388.2, 464.44)
  ..lineTo(388.2, 274.04)
  ..cubicTo(388.2, 263.64, 387.2, 256.18, 385.2, 251.65)
  ..cubicTo(383.2, 247.11, 379.66, 244.11, 374.59, 242.65)
  ..cubicTo(369.53, 241.18, 361.0, 240.04, 349.0, 239.24)
  ..lineTo(349.0, 229.24)
  ..lineTo(439.8, 229.24)
  ..lineTo(516.59, 440.04)
  ..lineTo(593.8, 229.24)
  ..lineTo(682.59, 229.24)
  ..lineTo(682.59, 239.24)
  ..cubicTo(670.59, 240.04, 662.12, 241.18, 657.19, 242.65)
  ..cubicTo(652.26, 244.11, 648.8, 247.11, 646.8, 251.65)
  ..cubicTo(644.8, 256.18, 643.8, 263.64, 643.8, 274.04)
  ..lineTo(643.8, 464.44)
  ..cubicTo(643.8, 474.84, 644.8, 482.31, 646.8, 486.85)
  ..cubicTo(648.8, 491.38, 652.33, 494.38, 657.39, 495.85)
  ..cubicTo(662.46, 497.31, 670.86, 498.44, 682.59, 499.24)
  ..lineTo(682.59, 509.24)
  ..lineTo(565.4, 509.24)
  ..close()
  ..moveTo(565.4, 499.24);
