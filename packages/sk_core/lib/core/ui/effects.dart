import 'dart:math';

import 'package:flutter/material.dart';

import 'palette.dart';

/// Slowly floating translucent bubbles behind every screen (stops if the OS asks to reduce motion).
class FloatingBubbles extends StatefulWidget {
  const FloatingBubbles({super.key, this.count = 14});
  final int count;
  @override
  State<FloatingBubbles> createState() => _FloatingBubblesState();
}

class _FloatingBubblesState extends State<FloatingBubbles>
    with SingleTickerProviderStateMixin {
  late final _c = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 40),
  )..repeat();
  late final List<_Bubble> _bubbles = () {
    final rng = Random(3);
    return [
      for (var i = 0; i < widget.count; i++)
        _Bubble(
          rng.nextDouble(),
          rng.nextDouble(),
          20 + rng.nextDouble() * 70,
          0.5 + rng.nextDouble(),
          rng.nextInt(5),
        ),
    ];
  }();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.disableAnimationsOf(context)) _c.stop();
    return IgnorePointer(
      child: RepaintBoundary(
        child: CustomPaint(
          size: Size.infinite,
          painter: _BubblePainter(_bubbles, _c),
        ),
      ),
    );
  }
}

class _Bubble {
  _Bubble(this.x, this.y, this.r, this.speed, this.color);
  final double x, y, r, speed;
  final int color;

  /// Built once, centered at the origin; the canvas is translated when drawing.
  late final Paint paint = Paint()
    ..shader = RadialGradient(
      colors: [
        _BubblePainter.colors[color].withValues(alpha: 0.35),
        _BubblePainter.colors[color].withValues(alpha: 0.0),
      ],
    ).createShader(Rect.fromCircle(center: Offset.zero, radius: r));
}

class _BubblePainter extends CustomPainter {
  _BubblePainter(this.bubbles, this.anim) : super(repaint: anim);
  final List<_Bubble> bubbles;
  final Animation<double> anim;
  static const colors = [
    Pure.red,
    Pure.orange,
    Pure.yellow,
    Pure.green,
    Pure.blue,
    Pure.purple,
  ];

  @override
  void paint(Canvas canvas, Size size) {
    for (final b in bubbles) {
      final t = (b.y - anim.value * b.speed * 2) % 1.0;
      final x =
          b.x * size.width +
          sin((anim.value * 2 * pi * b.speed) + b.x * 10) * 20;
      final y = t * (size.height + b.r * 2) - b.r;
      canvas.save();
      canvas.translate(x, y);
      canvas.drawCircle(Offset.zero, b.r, b.paint);
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _BubblePainter old) => false;
}

/// Falling confetti celebration (plays once).
class Confetti extends StatefulWidget {
  const Confetti({
    super.key,
    this.count = 90,
    this.duration = const Duration(milliseconds: 2800),
  });
  final int count;
  final Duration duration;
  @override
  State<Confetti> createState() => _ConfettiState();
}

class _ConfettiState extends State<Confetti>
    with SingleTickerProviderStateMixin {
  late final _c = AnimationController(vsync: this, duration: widget.duration)
    ..forward();
  late final List<_Piece> _pieces = () {
    final rng = Random();
    return [
      for (var i = 0; i < widget.count; i++)
        _Piece(
          x: rng.nextDouble(),
          delay: rng.nextDouble() * 0.35,
          speed: 0.7 + rng.nextDouble() * 0.6,
          drift: (rng.nextDouble() - 0.5) * 0.3,
          spin: (rng.nextDouble() - 0.5) * 20,
          size: 7 + rng.nextDouble() * 9,
          color: _ConfettiPainter
              .colors[rng.nextInt(_ConfettiPainter.colors.length)],
          shape: rng.nextInt(3),
        ),
    ];
  }();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: CustomPaint(
      size: Size.infinite,
      painter: _ConfettiPainter(_pieces, _c),
    ),
  );
}

class _Piece {
  _Piece({
    required this.x,
    required this.delay,
    required this.speed,
    required this.drift,
    required this.spin,
    required this.size,
    required this.color,
    required this.shape,
  });
  final double x, delay, speed, drift, spin, size;
  final Color color;
  final int shape;
}

class _ConfettiPainter extends CustomPainter {
  _ConfettiPainter(this.pieces, this.anim) : super(repaint: anim);
  final List<_Piece> pieces;
  final Animation<double> anim;
  static const colors = [
    Pure.red,
    Pure.orange,
    Pure.yellow,
    Pure.green,
    Pure.blue,
    Pure.purple,
    Color(0xFFFFFFFF),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint();
    for (final p in pieces) {
      final t = ((anim.value - p.delay) / (1 - p.delay)).clamp(0.0, 1.0);
      if (t <= 0) continue;
      final y = -20 + t * p.speed * (size.height + 60);
      final x = (p.x + p.drift * t) * size.width + sin(t * 10 + p.x * 20) * 18;
      paint.color = p.color.withValues(alpha: t > 0.8 ? (1 - t) / 0.2 : 1);
      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(t * p.spin);
      switch (p.shape) {
        case 0:
          canvas.drawRect(
            Rect.fromCenter(
              center: Offset.zero,
              width: p.size,
              height: p.size * 0.5,
            ),
            paint,
          );
        case 1:
          canvas.drawCircle(Offset.zero, p.size * 0.4, paint);
        default:
          canvas.drawPath(_star(p.size * 0.6), paint);
      }
      canvas.restore();
    }
  }

  static Path _star(double r) {
    final path = Path();
    for (var i = 0; i < 10; i++) {
      final rad = i.isEven ? r : r * 0.45;
      final a = -pi / 2 + i * pi / 5;
      i == 0
          ? path.moveTo(cos(a) * rad, sin(a) * rad)
          : path.lineTo(cos(a) * rad, sin(a) * rad);
    }
    return path..close();
  }

  @override
  bool shouldRepaint(covariant _ConfettiPainter old) => false;
}

/// Bounces its child whenever [value] changes (e.g. a goal counter going down).
class BounceOnChange extends StatelessWidget {
  const BounceOnChange({super.key, required this.value, required this.child});
  final Object value;
  final Widget child;
  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
    key: ValueKey(value),
    tween: Tween(begin: 1.45, end: 1),
    duration: const Duration(milliseconds: 450),
    curve: Curves.elasticOut,
    builder: (_, s, c) => Transform.scale(scale: s, child: c),
    child: child,
  );
}
