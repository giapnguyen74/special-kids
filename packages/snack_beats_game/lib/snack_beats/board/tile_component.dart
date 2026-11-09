import 'dart:math';
import 'dart:ui' as ui;

import 'package:flame/components.dart';
import 'package:flutter/animation.dart';
import 'package:flutter/painting.dart';
import 'package:sk_core/core/ui/palette.dart';

import 'package:sk_core/core/content/foods.dart';

import '../engine/board.dart';

/// One board piece. No box around foods (less visual noise): just a big food icon with a soft shadow.
///
/// Specials have their own look, while still showing which food they are:
///   line ↔ / ↕   food + glowing arrows sliding out on both sides
///   bomb          the fruit wrapped like a sweet (wrapper in the fruit's color, twisted ends), gently pulsing
///   flyer         the fruit with a spinning ring around it (3 arcs + sparkles); fires 3 rockets
///   rainbow 🌈    rainbow over a spinning color ring (matches any food)
///   nova 🌟       star with rotating golden rays (clears the board)
///
/// Performance: each static look is drawn once into a cached image and stamped every frame;
/// only animated parts (glows, arrows, rings, rays, sparks) are drawn live.
class TileComponent extends PositionComponent {
  TileComponent(this.tile) : _phase = Random().nextDouble() * 2 * pi;

  final Tile tile;
  final Vector2 target = Vector2.zero();
  bool selected = false, hint = false;
  double _popT = -1, _bornT = -1, _time = 0, _landT = -1;
  final double _phase;
  String _sig = '';
  bool _moving = false;

  static const _white = Color(0xFFFFFFFF);
  static const _gold = Color(0xFFFFD600);
  static const _rainbow = Pure.rainbow;
  static final Map<String, ui.Image> _baseCache = {};
  static final Map<String, ui.Image> _glowCache = {};

  /// Drop cached tile images (e.g. when web emoji fonts finish downloading,
  /// so pieces drawn before the font arrived are redrawn correctly).
  static void clearCache() {
    _baseCache.clear();
    _glowCache.clear();
  }

  static double get _dpr => ui
      .PlatformDispatcher
      .instance
      .views
      .first
      .devicePixelRatio
      .clamp(1.0, 3.0);

  bool get _hasFood => tile.type >= 0 && tile.type < foods.length;
  Color get color => _hasFood
      ? foods[tile.type].color
      : (tile.isMud ? const Color(0xFF6D4C41) : _gold);
  bool get _special => tile.special != Special.none || tile.isWild;

  void refresh() {
    final sig = '${tile.type}|${tile.special.name}|${tile.hp}';
    if (_sig.isNotEmpty && sig != _sig) _bornT = 0;
    _sig = sig;
  }

  void pop() => _popT = 0;
  void snap() => position.setFrom(target);

  @override
  void update(double dt) {
    _time += dt;
    final d = target - position;
    if (d.length2 < 0.25) {
      if (_moving) _landT = 0;
      _moving = false;
      position.setFrom(target);
    } else {
      _moving = d.length2 > 4;
      position.add(d..scale(1 - exp(-dt * 16)));
    }
    if (_popT >= 0) {
      _popT += dt;
      if (_popT >= 0.22) removeFromParent();
    }
    if (_bornT >= 0) {
      _bornT += dt;
      if (_bornT >= 0.45) _bornT = -1;
    }
    if (_landT >= 0) {
      _landT += dt;
      if (_landT >= 0.18) _landT = -1;
    }
  }

  @override
  void render(Canvas canvas) {
    final s = size.x;
    var sx = 1.0, sy = 1.0, alpha = 1.0, rot = 0.0, dy = 0.0;
    if (_popT >= 0) {
      final p = (_popT / 0.22).clamp(0.0, 1.0);
      sx = sy = 1 + 0.5 * p;
      alpha = 1 - p;
    }
    if (_bornT >= 0) {
      final b =
          0.5 +
          0.5 * Curves.elasticOut.transform((_bornT / 0.45).clamp(0.0, 1.0));
      sx *= b;
      sy *= b;
    }
    if (_landT >= 0) {
      final q = sin(pi * _landT / 0.18) * 0.12;
      sx *= 1 + q;
      sy *= 1 - q;
    }
    if (selected) {
      final b = 1.14 + 0.04 * sin(_time * 8);
      sx *= b;
      sy *= b;
    }
    if (hint) {
      rot = sin(_time * 2 * pi) * 0.18;
      sx *= 1.08;
      sy *= 1.08;
    }

    if (tile.special == Special.bomb) {
      final b = 1 + 0.04 * sin(_time * 6 + _phase);
      sx *= b;
      sy *= b;
    }

    final pivotY = s * (_landT >= 0 ? 0.65 : 0.5);
    canvas.save();
    canvas.translate(s / 2, pivotY + dy);
    canvas.rotate(rot);
    canvas.scale(sx, sy);
    canvas.translate(-s / 2, -pivotY);

    final a = Color.fromRGBO(255, 255, 255, alpha);

    // Selection: yellow disc + orange ring behind the piece (visible on the light board).
    if (selected) {
      canvas.drawCircle(
        Offset(s / 2, s / 2),
        s * 0.46,
        Paint()..color = Pure.yellow.withValues(alpha: 0.55 * alpha),
      );
      canvas.drawCircle(
        Offset(s / 2, s / 2),
        s * 0.46,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 4
          ..color = Pure.orange.withValues(alpha: alpha),
      );
    }

    // Special glow (pre-blurred, pulsing; no strobing).
    if (_special) {
      final pulse = 0.55 + 0.45 * sin(_time * 3 + _phase);
      final glowColor = tile.isRainbow
          ? _rainbow[((_time * 2).floor()) % 6]
          : color;
      _drawImage(
        canvas,
        _glowImage(s, glowColor),
        Rect.fromLTWH(-s * 0.3, -s * 0.3, s * 1.6, s * 1.6),
        Paint()..color = Color.fromRGBO(255, 255, 255, alpha * pulse * 0.85),
      );
    }

    if (tile.isNova) _paintRays(canvas, s, alpha);
    if (tile.isRainbow) _paintRainbowRing(canvas, s, alpha);

    _drawImage(
      canvas,
      _baseImage(s),
      Rect.fromLTWH(0, 0, s, s),
      Paint()..color = a,
    );

    if (tile.special == Special.h || tile.special == Special.v) {
      _paintArrows(canvas, s, alpha);
    }
    if (tile.special == Special.flyer) _paintSpinRing(canvas, s, alpha);

    canvas.restore();
  }

  // ---------------------------------------------------------------- live parts
  void _paintArrows(Canvas canvas, double s, double alpha) {
    final horizontal = tile.special == Special.h;
    final slide = (_time * 1.6) % 1.0; // 0..1, arrows slide outward and fade
    final fill = Paint()
      ..color = color.withValues(alpha: alpha * (1 - slide * 0.5));
    final glow = Paint()
      ..color = _white.withValues(alpha: alpha * 0.95)
      ..style = PaintingStyle.stroke
      ..strokeWidth = s * 0.05
      ..strokeJoin = StrokeJoin.round;
    for (final dir in const [-1.0, 1.0]) {
      final off = s * (0.3 + 0.06 * slide);
      final w = s * 0.11, h = s * 0.15;
      canvas.save();
      canvas.translate(s / 2, s / 2);
      if (!horizontal) canvas.rotate(pi / 2);
      final x = dir * off;
      final path = Path()
        ..moveTo(x + dir * w, 0)
        ..lineTo(x, -h)
        ..lineTo(x, h)
        ..close();
      canvas.drawPath(path, glow);
      canvas.drawPath(path, fill);
      canvas.restore();
    }
  }

  void _paintRainbowRing(Canvas canvas, double s, double alpha) {
    final rect = Rect.fromCircle(
      center: Offset(s / 2, s / 2),
      radius: s * 0.43,
    );
    canvas.drawCircle(
      rect.center,
      s * 0.43,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = s * 0.09
        ..shader = SweepGradient(
          colors: _rainbow,
          transform: GradientRotation(_time * 3),
        ).createShader(rect)
        ..color = _white.withValues(alpha: alpha),
    );
  }

  void _paintRays(Canvas canvas, double s, double alpha) {
    final paint = Paint()..color = _gold.withValues(alpha: alpha * 0.9);
    canvas.save();
    canvas.translate(s / 2, s / 2);
    canvas.rotate(_time * 1.5);
    for (var i = 0; i < 10; i++) {
      final a = i * 2 * pi / 10;
      final path = Path()
        ..moveTo(cos(a - 0.12) * s * 0.18, sin(a - 0.12) * s * 0.18)
        ..lineTo(cos(a) * s * 0.52, sin(a) * s * 0.52)
        ..lineTo(cos(a + 0.12) * s * 0.18, sin(a + 0.12) * s * 0.18)
        ..close();
      canvas.drawPath(path, paint);
    }
    canvas.restore();
  }

  // ---------------------------------------------------------------- cached parts
  static void _drawImage(Canvas canvas, ui.Image img, Rect dst, Paint paint) {
    canvas.drawImageRect(
      img,
      Rect.fromLTWH(0, 0, img.width.toDouble(), img.height.toDouble()),
      dst,
      paint..filterQuality = FilterQuality.medium,
    );
  }

  ui.Image _baseImage(double s) {
    final key = '${tile.type}|${tile.special.name}|${tile.hp}|${s.round()}';
    return _baseCache.putIfAbsent(key, () {
      final rec = ui.PictureRecorder();
      final c = Canvas(rec);
      final d = _dpr;
      c.scale(d);
      _paintStatic(c, s);
      return rec.endRecording().toImageSync((s * d).ceil(), (s * d).ceil());
    });
  }

  static ui.Image _glowImage(double s, Color color) {
    final key = '${color.toARGB32()}|${s.round()}';
    return _glowCache.putIfAbsent(key, () {
      final rec = ui.PictureRecorder();
      final c = Canvas(rec);
      final d = _dpr;
      c.scale(d);
      c.drawCircle(
        Offset(s * 0.8, s * 0.8),
        s * 0.5,
        Paint()
          ..color = color
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, s * 0.16),
      );
      return rec.endRecording().toImageSync(
        (s * 1.6 * d).ceil(),
        (s * 1.6 * d).ceil(),
      );
    });
  }

  static void _emoji(
    Canvas c,
    String e,
    double size,
    Offset center, {
    bool shadow = true,
  }) {
    final tp = TextPainter(
      text: TextSpan(
        text: e,
        style: TextStyle(
          fontSize: size,
          shadows: shadow
              ? [
                  Shadow(
                    color: const Color(0x66000000),
                    offset: Offset(0, size * 0.06),
                    blurRadius: size * 0.08,
                  ),
                ]
              : null,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(c, center - Offset(tp.width / 2, tp.height / 2));
  }

  /// Static look of the piece (cached).
  void _paintStatic(Canvas c, double s) {
    final center = Offset(s / 2, s / 2 + s * 0.02);
    if (tile.isWall) {
      // Rock needs 2 hits: rock -> bricks -> gone.
      _emoji(c, tile.hp >= 2 ? '🪨' : '🧱', s * 0.72, center);
      return;
    }
    if (tile.isMud) {
      _paintMud(c, s);
      return;
    }
    final food = _hasFood ? foods[tile.type].emoji : null;
    switch (tile.special) {
      case Special.bomb:
        _paintWrapper(c, s);
        if (food != null) _emoji(c, food, s * 0.5, center);
      case Special.flyer:
        if (food != null) _emoji(c, food, s * 0.54, center);
      case Special.none || Special.h || Special.v:
        if (tile.isRainbow) {
          _emoji(c, '🌈', s * 0.56, center);
        } else if (tile.isNova) {
          _emoji(c, '🌟', s * 0.66, center);
        } else if (food != null) {
          _emoji(
            c,
            food,
            s * (tile.special == Special.none ? 0.74 : 0.54),
            center,
          );
        }
    }
  }

  /// Sweet wrapper in the fruit's color: rounded body + two twisted ends + shine.
  void _paintWrapper(Canvas c, double s) {
    final base = color;
    final dark = Color.lerp(base, const Color(0xFF000000), 0.25)!;
    final light = Color.lerp(base, _white, 0.55)!;
    // twisted ends (left / right)
    for (final dir in const [-1.0, 1.0]) {
      final x0 = s / 2 + dir * s * 0.3;
      final ear = Path()
        ..moveTo(x0, s * 0.5)
        ..lineTo(x0 + dir * s * 0.2, s * 0.3)
        ..quadraticBezierTo(
          x0 + dir * s * 0.13,
          s * 0.5,
          x0 + dir * s * 0.2,
          s * 0.7,
        )
        ..close();
      c.drawPath(ear, Paint()..color = dark);
      c.drawPath(
        ear,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = s * 0.025
          ..strokeJoin = StrokeJoin.round
          ..color = _white,
      );
    }
    // body
    final body = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(s / 2, s / 2),
        width: s * 0.66,
        height: s * 0.66,
      ),
      Radius.circular(s * 0.22),
    );
    c.drawRRect(
      body.shift(Offset(0, s * 0.03)),
      Paint()..color = const Color(0x40000000),
    );
    c.drawRRect(
      body,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [light, base, dark],
        ).createShader(body.outerRect),
    );
    // diagonal stripes on the wrapper
    c.save();
    c.clipRRect(body);
    final stripe = Paint()
      ..color = _white.withValues(alpha: 0.35)
      ..strokeWidth = s * 0.06;
    for (var k = -s; k < s; k += s * 0.2) {
      c.drawLine(Offset(k, s), Offset(k + s, 0), stripe);
    }
    c.restore();
    c.drawRRect(
      body,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = s * 0.035
        ..color = _white,
    );
  }

  /// Spinning ring around a flyer fruit: 3 arcs in the fruit color + sparkles riding the ring.
  void _paintSpinRing(Canvas canvas, double s, double alpha) {
    final center = Offset(s / 2, s / 2);
    final r = s * 0.42;
    final rect = Rect.fromCircle(center: center, radius: r);
    final spin = _time * 4;
    final arc = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = s * 0.09
      ..strokeCap = StrokeCap.round
      ..color = color.withValues(alpha: alpha);
    final edge = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = s * 0.13
      ..strokeCap = StrokeCap.round
      ..color = _white.withValues(alpha: alpha);
    for (var i = 0; i < 3; i++) {
      final start = spin + i * 2 * pi / 3;
      canvas.drawArc(rect, start, 1.4, false, edge);
      canvas.drawArc(rect, start, 1.4, false, arc);
      // sparkle at the head of each arc
      final hx = center.dx + cos(start + 1.4) * r,
          hy = center.dy + sin(start + 1.4) * r;
      canvas.drawCircle(
        Offset(hx, hy),
        s * 0.06,
        Paint()..color = Pure.yellow.withValues(alpha: alpha),
      );
      canvas.drawCircle(
        Offset(hx, hy),
        s * 0.03,
        Paint()..color = _white.withValues(alpha: alpha),
      );
    }
  }

  /// Brown mud puddle with bubbles.
  static void _paintMud(Canvas c, double s) {
    final rect = Rect.fromLTWH(s * 0.08, s * 0.14, s * 0.84, s * 0.74);
    final blob = Path()
      ..addRRect(RRect.fromRectAndRadius(rect, Radius.circular(s * 0.3)))
      ..addOval(
        Rect.fromCircle(center: Offset(s * 0.3, s * 0.2), radius: s * 0.14),
      )
      ..addOval(
        Rect.fromCircle(center: Offset(s * 0.68, s * 0.22), radius: s * 0.12),
      );
    c.drawPath(
      blob.shift(Offset(0, s * 0.04)),
      Paint()..color = const Color(0x55000000),
    );
    c.drawPath(
      blob,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF8D6E63), Color(0xFF4E342E)],
        ).createShader(rect),
    );
    final bubble = Paint()..color = const Color(0xFFA1887F);
    c.drawCircle(Offset(s * 0.36, s * 0.55), s * 0.08, bubble);
    c.drawCircle(Offset(s * 0.62, s * 0.66), s * 0.06, bubble);
    c.drawCircle(Offset(s * 0.58, s * 0.42), s * 0.045, bubble);
    c.drawOval(
      Rect.fromLTWH(s * 0.2, s * 0.24, s * 0.3, s * 0.1),
      Paint()..color = const Color(0x55FFFFFF),
    );
  }
}
