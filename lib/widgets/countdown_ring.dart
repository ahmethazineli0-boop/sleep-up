import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme.dart';

/// Ana ekrandaki halka: [progress] 0..1 arası dolar.
class CountdownRing extends StatelessWidget {
  const CountdownRing({
    super.key,
    required this.progress,
    required this.caption,
    required this.value,
    required this.footer,
    this.color = SU.amber,
  });

  final double progress;
  final String caption;
  final String value;
  final String footer;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 220,
      height: 220,
      child: CustomPaint(
        painter: _RingPainter(progress.clamp(0.0, 1.0), color),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(caption, style: const TextStyle(fontSize: 13, color: SU.muted)),
              const SizedBox(height: 4),
              FittedBox(
                child: Text(value,
                    style: const TextStyle(fontSize: 44, fontWeight: FontWeight.w700, letterSpacing: -1)),
              ),
              const SizedBox(height: 4),
              Text(footer, style: const TextStyle(fontSize: 13, color: SU.muted)),
            ],
          ),
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter(this.progress, this.color);
  final double progress;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    const stroke = 14.0;
    final rect = Offset.zero & size;
    final r = rect.deflate(stroke / 2 + 4);
    final track = Paint()
      ..color = SU.line
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke;
    final arc = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = stroke;
    canvas.drawArc(r, 0, math.pi * 2, false, track);
    if (progress > 0) {
      canvas.drawArc(r, -math.pi / 2, math.pi * 2 * progress, false, arc);
    }
  }

  @override
  bool shouldRepaint(_RingPainter old) => old.progress != progress || old.color != color;
}
