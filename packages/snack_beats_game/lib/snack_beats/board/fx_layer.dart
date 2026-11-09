import 'dart:math';

import 'package:flame/components.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/animation.dart';
import 'package:flutter/painting.dart';
import 'package:sk_core/core/ui/palette.dart';

final _rng = Random();

/// Live blurs are very expensive on the web engine; use them only on native.
MaskFilter? _blur(double sigma) =>
    kIsWeb ? null : MaskFilter.blur(BlurStyle.normal, sigma);

/// Juicy visual effects drawn on top of the board: particle bursts, line beams,
/// shockwave rings, rainbow rays and floating praise text.
/// [intensity] 1.0 = full, ~0.4 = soft (parent setting for sensory-sensitive kids).
/// No rapid strobing: every flash is a single, smooth fade.
class FxLayer extends PositionComponent {
  double intensity = 1;
  double cell = 40;

  final _particles = <_Particle>[];
  final _beams = <_Beam>[];
  final _rings = <_Ring>[];
  final _rays = <_Rays>[];
  final _texts = <_FloatText>[];
  final _flights = <_Flight>[];
  final _novas = <_Nova>[];
  static TextPainter _rocket = _makeRocket();
  static TextPainter _makeRocket() => TextPainter(
    text: const TextSpan(text: '🚀', style: TextStyle(fontSize: 40)),
    textDirection: TextDirection.ltr,
  )..layout();

  /// Re-layout cached emoji after fonts change (web downloads emoji fonts lazily).
  static void fontsChanged() => _rocket = _makeRocket();

  static const rainbow = Pure.rainbow;

  bool get soft => intensity < 0.7;

  /// Confetti-like burst of circles, stars and sparkles.
  void burst(Vector2 at, Color color, {int count = 12, double speed = 1}) {
    final n = max(3, (count * intensity).round());
    for (var i = 0; i < n; i++) {
      final a = _rng.nextDouble() * 2 * pi;
      final v = (0.8 + _rng.nextDouble()) * cell * 4 * speed;
      final shape = _rng.nextInt(3);
      _particles.add(
        _Particle(
          p: at.clone(),
          v: Vector2(cos(a), sin(a)) * v - Vector2(0, cell * 3),
          // Mostly the fruit's own color (visible on the light board), some yellow/orange sparkle.
          color: i % 5 == 0 ? Pure.yellow : (i % 5 == 1 ? Pure.orange : color),
          size: cell * (0.12 + _rng.nextDouble() * 0.14),
          life: 0.8 + _rng.nextDouble() * 0.5,
          shape: shape,
          gravity: cell * 7,
        ),
      );
    }
    if (_particles.length > 900) {
      _particles.removeRange(0, _particles.length - 900);
    }
  }

  void beam({
    required bool horizontal,
    required double at,
    required Color color,
  }) {
    _beams.add(_Beam(horizontal, at, color));
    final along = horizontal ? size.x : size.y;
    for (var x = cell / 2; x < along; x += cell) {
      burst(
        horizontal ? Vector2(x, at) : Vector2(at, x),
        color,
        count: 4,
        speed: 0.6,
      );
    }
  }

  void ring(
    Vector2 at, {
    required double radius,
    Color color = const Color(0xFFFFFFFF),
    double width = 12,
  }) => _rings.add(_Ring(at, radius, color, width * (soft ? 0.6 : 1)));

  void rays(Vector2 from, List<Vector2> to) => _rays.add(_Rays(from, to));

  /// A rocket flying along a curve from [from] to [to] with a sparkle trail.
  void flight(Vector2 from, Vector2 to, Color color, {double bend = 0}) =>
      _flights.add(_Flight(from.clone(), to.clone(), color, bend));

  /// Whole-board clear: a big golden wave and a soft (single, non-strobing) glow.
  void nova(Vector2 at, {required double radius}) {
    _novas.add(_Nova(at.clone(), radius));
    burst(at, const Color(0xFFFFD600), count: 30, speed: 1.8);
  }

  void praise(String text, Vector2 at) {
    _texts
      ..clear()
      ..add(_FloatText(text, at, cell * (soft ? 0.75 : 1.0)));
  }

  @override
  void update(double dt) {
    for (final p in _particles) {
      p.v.y += p.gravity * dt;
      p.v.scale(pow(0.5, dt).toDouble());
      p.p.addScaled(p.v, dt);
      p.life -= dt;
      p.rot += p.spin * dt;
    }
    _particles.removeWhere((p) => p.life <= 0);
    for (final b in _beams) {
      b.t += dt;
    }
    _beams.removeWhere((b) => b.t >= _Beam.dur);
    for (final r in _rings) {
      r.t += dt;
    }
    _rings.removeWhere((r) => r.t >= _Ring.dur);
    for (final r in _rays) {
      r.t += dt;
    }
    _rays.removeWhere((r) => r.t >= _Rays.dur);
    for (final t in _texts) {
      t.t += dt;
    }
    _texts.removeWhere((t) => t.t >= _FloatText.dur);
    for (final f in _flights) {
      f.t += dt;
      // sparkle trail
      if (_rng.nextDouble() < (soft ? 0.3 : 0.8)) {
        final p = f.pos(cell);
        _particles.add(
          _Particle(
            p: p,
            v: Vector2(
              (_rng.nextDouble() - 0.5) * cell,
              (_rng.nextDouble() - 0.5) * cell,
            ),
            color: _rng.nextBool() ? const Color(0xFFFFD600) : f.color,
            size: cell * 0.08,
            life: 0.35,
            shape: 2,
            gravity: 0,
          ),
        );
      }
    }
    for (final f in _flights.where((f) => f.t >= _Flight.dur).toList()) {
      burst(f.to, f.color, count: 14, speed: 1.1);
    }
    _flights.removeWhere((f) => f.t >= _Flight.dur);
    for (final n in _novas) {
      n.t += dt;
    }
    _novas.removeWhere((n) => n.t >= _Nova.dur);
  }

  @override
  void render(Canvas canvas) {
    // Beams (line blasters)
    for (final b in _beams) {
      final p = b.t / _Beam.dur;
      final th = cell * 0.95 * sin(pi * p);
      final a = 1 - p * 0.6;
      final rect = b.horizontal
          ? Rect.fromCenter(
              center: Offset(size.x / 2, b.at),
              width: size.x + cell,
              height: th,
            )
          : Rect.fromCenter(
              center: Offset(b.at, size.y / 2),
              width: th,
              height: size.y + cell,
            );
      canvas.drawRect(
        rect.inflate(cell * 0.3),
        Paint()
          ..color = b.color.withValues(alpha: 0.55 * a)
          ..maskFilter = _blur(cell * 0.35),
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, Radius.circular(th / 2)),
        Paint()..color = b.color.withValues(alpha: a),
      );
      // thin bright core
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          b.horizontal
              ? Rect.fromCenter(
                  center: rect.center,
                  width: rect.width,
                  height: th * 0.35,
                )
              : Rect.fromCenter(
                  center: rect.center,
                  width: th * 0.35,
                  height: rect.height,
                ),
          Radius.circular(th / 2),
        ),
        Paint()..color = const Color(0xFFFFFFFF).withValues(alpha: a),
      );
    }

    // Shockwave rings (bombs, specials being born)
    for (final r in _rings) {
      final p = r.t / _Ring.dur;
      final rad = r.radius * Curves.easeOutCubic.transform(p);
      canvas.drawCircle(
        r.at.toOffset(),
        rad,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = r.width * (1 - p) + 1
          ..color = r.color.withValues(alpha: 1 - p)
          ..maskFilter = _blur(3),
      );
    }

    // Rainbow rays (music-note tile)
    for (final rs in _rays) {
      final p = rs.t / _Rays.dur;
      final grow = Curves.easeOut.transform((p * 2).clamp(0.0, 1.0));
      for (var i = 0; i < rs.to.length; i++) {
        final end = rs.from + (rs.to[i] - rs.from) * grow;
        final color = rainbow[i % rainbow.length];
        final w = (soft ? 3.0 : 6.0) * (1 - p) + 1;
        canvas.drawLine(
          rs.from.toOffset(),
          end.toOffset(),
          Paint()
            ..color = color.withValues(alpha: 0.6 * (1 - p))
            ..strokeWidth = w * 3
            ..maskFilter = _blur(6),
        );
        canvas.drawLine(
          rs.from.toOffset(),
          end.toOffset(),
          Paint()
            ..color = const Color(0xFFFFFFFF).withValues(alpha: 1 - p)
            ..strokeWidth = w
            ..strokeCap = StrokeCap.round,
        );
      }
    }

    // Whole-board wave
    for (final n in _novas) {
      final p = (n.t / _Nova.dur).clamp(0.0, 1.0);
      final glow = (1 - p) * (soft ? 0.25 : 0.45);
      canvas.drawRect(
        Rect.fromLTWH(0, 0, size.x, size.y),
        Paint()..color = const Color(0xFFFFF3B0).withValues(alpha: glow),
      );
      for (final (k, color) in const [
        (1.0, Color(0xFFFFD600)),
        (0.7, Color(0xFFFFFFFF)),
        (0.45, Color(0xFFFF6D00)),
      ]) {
        canvas.drawCircle(
          n.at.toOffset(),
          n.radius * k * Curves.easeOutCubic.transform(p),
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = cell * 0.5 * (1 - p) + 2
            ..color = color.withValues(alpha: 1 - p),
        );
      }
    }

    // Rockets
    for (final f in _flights) {
      final p = f.pos(cell);
      final ahead = f.pos(cell, dt: 0.02);
      final angle =
          atan2(ahead.y - p.y, ahead.x - p.x) + pi / 4; // emoji points up-right
      final s = cell * 0.62 / 40;
      canvas.save();
      canvas.translate(p.x, p.y);
      canvas.rotate(angle);
      canvas.scale(s);
      _rocket.paint(canvas, Offset(-_rocket.width / 2, -_rocket.height / 2));
      canvas.restore();
    }

    // Particles
    final paint = Paint();
    for (final pt in _particles) {
      final a = (pt.life / pt.maxLife).clamp(0.0, 1.0);
      paint.color = pt.color.withValues(alpha: a);
      final s = pt.size * (0.5 + 0.5 * a);
      canvas.save();
      canvas.translate(pt.p.x, pt.p.y);
      canvas.rotate(pt.rot);
      switch (pt.shape) {
        case 0:
          canvas.drawCircle(Offset.zero, s, paint);
        case 1:
          canvas.drawPath(_star(s * 1.5), paint);
        default:
          canvas.drawPath(_sparkle(s * 1.8), paint);
      }
      canvas.restore();
    }

    // Praise text ("Awesome!")
    for (final t in _texts) {
      final p = t.t / _FloatText.dur;
      final scale = p < 0.3 ? Curves.elasticOut.transform(p / 0.3) : 1.0;
      final alpha = p > 0.7 ? (1 - (p - 0.7) / 0.3) : 1.0;
      canvas.save();
      canvas.translate(t.at.x, t.at.y - t.size * 0.8 * p);
      canvas.scale(max(0.01, scale));
      final (stroke, fill) = t.painters;
      canvas.saveLayer(null, Paint()..color = Color.fromRGBO(0, 0, 0, alpha));
      stroke.paint(canvas, Offset(-stroke.width / 2, -stroke.height / 2));
      fill.paint(canvas, Offset(-fill.width / 2, -fill.height / 2));
      canvas.restore();
      canvas.restore();
    }
  }

  static Path _star(double r) {
    final path = Path();
    for (var i = 0; i < 10; i++) {
      final rad = i.isEven ? r : r * 0.45;
      final a = -pi / 2 + i * pi / 5;
      final pt = Offset(cos(a) * rad, sin(a) * rad);
      i == 0 ? path.moveTo(pt.dx, pt.dy) : path.lineTo(pt.dx, pt.dy);
    }
    return path..close();
  }

  static Path _sparkle(double r) => Path()
    ..moveTo(0, -r)
    ..quadraticBezierTo(0, 0, r, 0)
    ..quadraticBezierTo(0, 0, 0, r)
    ..quadraticBezierTo(0, 0, -r, 0)
    ..quadraticBezierTo(0, 0, 0, -r)
    ..close();
}

class _Particle {
  _Particle({
    required this.p,
    required this.v,
    required this.color,
    required this.size,
    required this.life,
    required this.shape,
    required this.gravity,
  }) : maxLife = life,
       rot = _rng.nextDouble() * pi,
       spin = (_rng.nextDouble() - 0.5) * 12;
  final Vector2 p, v;
  final Color color;
  final double size, gravity, maxLife, spin;
  final int shape;
  double life, rot;
}

class _Beam {
  _Beam(this.horizontal, this.at, this.color);
  static const dur = 0.4;
  final bool horizontal;
  final double at;
  final Color color;
  double t = 0;
}

class _Ring {
  _Ring(this.at, this.radius, this.color, this.width);
  static const dur = 0.5;
  final Vector2 at;
  final double radius, width;
  final Color color;
  double t = 0;
}

class _Rays {
  _Rays(this.from, this.to);
  static const dur = 0.5;
  final Vector2 from;
  final List<Vector2> to;
  double t = 0;
}

class _FloatText {
  _FloatText(this.text, this.at, this.size);
  static const dur = 1.2;
  final String text;
  final Vector2 at;
  final double size;
  double t = 0;

  late final (TextPainter, TextPainter) painters = (
    TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          fontSize: size,
          fontWeight: FontWeight.w900,
          foreground: Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = size * 0.18
            ..strokeJoin = StrokeJoin.round
            ..color = const Color(0xFF4A148C),
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout(),
    TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          fontSize: size,
          fontWeight: FontWeight.w900,
          foreground: Paint()
            ..shader = const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFFFFFFFF), Color(0xFFFFD600), Color(0xFFFF6D00)],
            ).createShader(Rect.fromLTWH(0, -size * 0.6, 1, size * 1.2)),
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout(),
  );
}

class _Flight {
  _Flight(this.from, this.to, this.color, this.bend);
  static const dur = 0.42;
  final Vector2 from, to;
  final Color color;
  final double bend; // -1..1: curve to one side or the other
  double t = 0;

  /// Position on a curved path (quadratic bezier), optionally a bit ahead in time.
  Vector2 pos(double cell, {double dt = 0}) {
    final p = Curves.easeInOut.transform(((t + dt) / dur).clamp(0.0, 1.0));
    final mid = (from + to) / 2;
    final d = to - from;
    final normal = Vector2(-d.y, d.x)..normalize();
    final ctrl =
        mid +
        normal * (cell * (1.5 + bend.abs()) * (bend >= 0 ? 1 : -1)) -
        Vector2(0, cell);
    final a = from + (ctrl - from) * p;
    final b = ctrl + (to - ctrl) * p;
    return a + (b - a) * p;
  }
}

class _Nova {
  _Nova(this.at, this.radius);
  static const dur = 0.7;
  final Vector2 at;
  final double radius;
  double t = 0;
}
