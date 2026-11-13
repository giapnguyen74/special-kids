import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../engine/grid.dart';
import 'block_game.dart';

/// Block colors (index = color), the last one is the cream "gem" block.
const blockPalette = <Color>[
  Color(0xFFFF1744), // red
  Color(0xFFFF6D00), // orange
  Color(0xFFFFC400), // yellow
  Color(0xFF00C853), // green
  Color(0xFF00B8D4), // cyan
  Color(0xFF2979FF), // blue
  Color(0xFFAA00FF), // purple
  Color(0xFFF50057), // pink
  Color(0xFFFFE0B2), // gem block
];

/// Board on top, the tray of 3 pieces below. Drag a piece onto the board,
/// or tap a piece and then tap the board.
class BlockBoardView extends StatefulWidget {
  const BlockBoardView({super.key, required this.game});
  final BlockGame game;
  @override
  State<BlockBoardView> createState() => _BlockBoardViewState();
}

class _Layout {
  _Layout(Size s) {
    // Board + tray (3.4 board cells high) use ~1.48 x the board side; centred a bit above the middle.
    side = min(s.width, s.height / 1.48).floorToDouble();
    cell = side / 8;
    final top = max(0.0, (s.height - side * 1.48) / 3).floorToDouble();
    board = Rect.fromLTWH((s.width - side) / 2, top, side, side);
    final trayTop = board.bottom + cell * 0.45;
    trayMid = trayTop + cell * 1.7;
    final slotW = s.width / 3;
    // Touch area: the whole column below the board.
    slots = [
      for (var i = 0; i < 3; i++)
        Rect.fromLTWH(
          slotW * i,
          trayTop,
          slotW,
          max(cell * 3.4, s.height - trayTop),
        ),
    ];
  }
  late final double side, cell, trayMid;
  late final Rect board;
  late final List<Rect> slots;

  /// Pieces in the tray are drawn smaller; wide or tall ones shrink to fit their slot.
  double trayCell(Piece p) =>
      min(cell * 0.8, min(slots[0].width * 0.92 / p.cols, cell * 3.2 / p.rows));

  /// How far above the finger a dragged piece floats (so the finger never hides it).
  double lift(Piece p) => cell * (p.rows / 2 + 1.3);
}

class _BlockBoardViewState extends State<BlockBoardView>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  final _frame = ValueNotifier<int>(0);
  _Layout? _l;
  Offset? _finger;
  Offset? _downAt;
  int? _downSlot;
  bool _moved = false;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker((_) {
      widget.game.tick();
      _frame.value++;
    })..start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    _frame.dispose();
    super.dispose();
  }

  int? _slotAt(Offset p) {
    final l = _l!;
    for (var i = 0; i < 3; i++) {
      // Generous touch area: the whole slot column below the board.
      if (l.slots[i].inflate(4).contains(p)) return i;
    }
    return null;
  }

  void _down(Offset p) {
    final g = widget.game;
    g.touched();
    _downAt = p;
    _finger = p;
    _moved = false;
    _downSlot = _slotAt(p);
    if (_downSlot != null && g.tray[_downSlot!] != null && !g.locked) {
      g.startDrag(_downSlot!);
      _update(p);
    }
  }

  void _update(Offset p) {
    final g = widget.game;
    _finger = p;
    if (_downAt != null && (p - _downAt!).distance > 12) _moved = true;
    final i = g.dragging;
    if (i == null) return;
    final piece = g.tray[i]!;
    final l = _l!;
    final topLeft =
        p -
        Offset(
          piece.cols * l.cell / 2,
          piece.rows * l.cell / 2 + l.lift(piece),
        );
    g.dragTo(
      (topLeft.dy - l.board.top) / l.cell,
      (topLeft.dx - l.board.left) / l.cell,
    );
  }

  void _up() {
    final g = widget.game;
    final slot = _downSlot;
    if (g.dragging != null) {
      if (!_moved && slot != null) {
        // A tap on a piece: select it (tap mode).
        g.cancelDrag();
        g.select(slot);
      } else {
        g.endDrag();
        g.selected = null;
      }
    } else if (!_moved && g.selected != null && _downAt != null) {
      final l = _l!;
      if (l.board.contains(_downAt!)) {
        g.tapBoard(
          (_downAt!.dy - l.board.top) / l.cell,
          (_downAt!.dx - l.board.left) / l.cell,
        );
      }
    }
    _finger = null;
    _downAt = null;
    _downSlot = null;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, box) {
        final l = _l = _Layout(box.biggest);
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onPanDown: (d) => _down(d.localPosition),
          onPanUpdate: (d) => _update(d.localPosition),
          onPanEnd: (_) => _up(),
          onPanCancel: _up,
          child: CustomPaint(
            size: box.biggest,
            painter: _BoardPainter(widget.game, l, () => _finger, _frame),
          ),
        );
      },
    );
  }
}

class _BoardPainter extends CustomPainter {
  _BoardPainter(this.g, this.l, this.finger, Listenable repaint)
    : super(repaint: repaint);
  final BlockGame g;
  final _Layout l;
  final Offset? Function() finger;

  static final Map<String, TextPainter> _textCache = {};

  @override
  void paint(Canvas canvas, Size size) {
    final t = g.now;
    final b = l.board;
    final cell = l.cell;
    final grid = g.grid;

    // Board background.
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        b.inflate(cell * 0.12),
        Radius.circular(cell * 0.3),
      ),
      Paint()..color = const Color(0xFF1A1F4E),
    );
    final emptyPaint = Paint()..color = const Color(0xFF262D66);
    for (var r = 0; r < 8; r++) {
      for (var c = 0; c < 8; c++) {
        final rect = _cellRect(r, c).deflate(cell * 0.04);
        canvas.drawRRect(
          RRect.fromRectAndRadius(rect, Radius.circular(cell * 0.12)),
          emptyPaint,
        );
      }
    }

    // Lines that the dragged piece would clear light up in its color.
    final dragI = g.dragging ?? g.selected;
    final dragPiece = dragI == null ? null : g.tray[dragI];
    final tgt = g.target;
    final glowLines = <Cell>{};
    if (dragPiece != null && tgt != null) {
      final (rows, cols) = grid.wouldClear(dragPiece, tgt.$1, tgt.$2);
      for (final rr in rows) {
        for (var cc = 0; cc < 8; cc++) {
          glowLines.add((rr, cc));
        }
      }
      for (final cc in cols) {
        for (var rr = 0; rr < 8; rr++) {
          glowLines.add((rr, cc));
        }
      }
    }

    // Blocks.
    final popping = {
      for (final f in g.fx)
        if (f.kind == FxKind.pop && f.cell != null) f.cell!: f,
    };
    for (var r = 0; r < 8; r++) {
      for (var c = 0; c < 8; c++) {
        final v = grid.at(r, c);
        if (v < 0) continue;
        var rect = _cellRect(r, c);
        final pop = popping[(r, c)];
        if (pop != null) {
          final k = ((t - pop.t0) / pop.life).clamp(0.0, 1.0);
          rect = _scale(rect, 0.75 + 0.25 * Curves.easeOutBack.transform(k));
        }
        final color = glowLines.contains((r, c)) && dragPiece != null
            ? dragPiece.color
            : v;
        drawBlock(canvas, rect, blockPalette[color]);
        final gem = grid.gems[(r, c)];
        if (gem != null) {
          _emoji(canvas, gemEmojis[gem], rect.center, cell * 0.58);
        }
      }
    }
    if (glowLines.isNotEmpty) {
      final pulse = 0.25 + 0.15 * sin(t * 8);
      for (final (r, c) in glowLines) {
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            _cellRect(r, c),
            Radius.circular(cell * 0.14),
          ),
          Paint()..color = Colors.white.withValues(alpha: pulse),
        );
      }
    }

    // Ghost of where the piece will land.
    if (dragPiece != null && tgt != null) {
      for (final (dr, dc) in dragPiece.cells) {
        drawBlock(
          canvas,
          _cellRect(tgt.$1 + dr, tgt.$2 + dc),
          blockPalette[dragPiece.color],
          alpha: 0.45,
        );
      }
    }

    // Hint: a gently pulsing ghost of a good move.
    final h = g.hint;
    if (h != null && g.tray[h.$1] != null) {
      final p = g.tray[h.$1]!;
      final a = 0.25 + 0.25 * (0.5 + 0.5 * sin(t * 5));
      for (final (dr, dc) in p.cells) {
        drawBlock(
          canvas,
          _cellRect(h.$2 + dr, h.$3 + dc),
          blockPalette[p.color],
          alpha: a,
        );
      }
    }

    _paintFx(canvas, t);
    _paintTray(canvas, t);

    // The dragged piece follows the finger (floating above it).
    final f = finger();
    if (g.dragging != null && f != null && dragPiece != null) {
      final origin =
          f -
          Offset(
            dragPiece.cols * cell / 2,
            dragPiece.rows * cell / 2 + l.lift(dragPiece),
          );
      for (final (dr, dc) in dragPiece.cells) {
        final rect = Rect.fromLTWH(
          origin.dx + dc * cell,
          origin.dy + dr * cell,
          cell,
          cell,
        );
        drawBlock(canvas, rect, blockPalette[dragPiece.color], shadow: true);
      }
    }
  }

  Rect _cellRect(int r, int c) => Rect.fromLTWH(
    l.board.left + c * l.cell,
    l.board.top + r * l.cell,
    l.cell,
    l.cell,
  );

  Rect _scale(Rect r, double k) => Rect.fromCenter(
    center: r.center,
    width: r.width * k,
    height: r.height * k,
  );

  void _paintTray(Canvas canvas, double t) {
    for (var i = 0; i < 3; i++) {
      final p = g.tray[i];
      if (p == null || g.dragging == i) continue;
      final slot = l.slots[i];
      final centre = Offset(slot.center.dx, l.trayMid);
      final fits = g.grid.fits(p);
      final isHint = g.hint?.$1 == i;
      final isSel = g.selected == i;
      var k = 1.0;
      if (isHint) k = 1 + 0.08 * sin(t * 6);
      if (isSel) k = 1.15;
      final c = l.trayCell(p) * k;
      final origin = centre - Offset(p.cols * c / 2, p.rows * c / 2);
      if (isSel) {
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(
              origin.dx,
              origin.dy,
              p.cols * c,
              p.rows * c,
            ).inflate(c * 0.4),
            Radius.circular(c * 0.5),
          ),
          Paint()..color = Colors.white.withValues(alpha: 0.55),
        );
      }
      for (final (dr, dc) in p.cells) {
        drawBlock(
          canvas,
          Rect.fromLTWH(origin.dx + dc * c, origin.dy + dr * c, c, c),
          blockPalette[p.color],
          // Pieces that fit nowhere are dimmed so the child sees which ones can still go.
          alpha: fits ? 1 : 0.35,
        );
      }
    }
  }

  void _paintFx(Canvas canvas, double t) {
    final cell = l.cell;
    for (final f in g.fx) {
      final k = (t - f.t0) / f.life;
      if (k < 0 || k > 1) continue;
      switch (f.kind) {
        case FxKind.pop:
          break;
        case FxKind.clear:
          final rect = _cellRect(f.cell!.$1, f.cell!.$2);
          final s = 1 - Curves.easeIn.transform(k);
          drawBlock(
            canvas,
            _scale(rect, 0.2 + 0.8 * s),
            blockPalette[f.color],
            alpha: s,
          );
          canvas.drawRRect(
            RRect.fromRectAndRadius(
              _scale(rect, 1 + 0.2 * k),
              Radius.circular(cell * 0.2),
            ),
            Paint()..color = Colors.white.withValues(alpha: 0.7 * (1 - k)),
          );
        case FxKind.beam:
          final line = f.line!;
          final b = l.board;
          final rect = line >= 0
              ? Rect.fromLTWH(b.left, b.top + line * cell, b.width, cell)
              : Rect.fromLTWH(
                  b.left + (-1 - line) * cell,
                  b.top,
                  cell,
                  b.height,
                );
          final grow = Curves.easeOut.transform(k);
          final beam = line >= 0
              ? Rect.fromCenter(
                  center: rect.center,
                  width: rect.width * (0.3 + 0.8 * grow),
                  height: cell * (1 - 0.6 * k),
                )
              : Rect.fromCenter(
                  center: rect.center,
                  width: cell * (1 - 0.6 * k),
                  height: rect.height * (0.3 + 0.8 * grow),
                );
          canvas.drawRRect(
            RRect.fromRectAndRadius(beam, Radius.circular(cell * 0.5)),
            Paint()
              ..shader = LinearGradient(
                begin: line >= 0 ? Alignment.centerLeft : Alignment.topCenter,
                end: line >= 0 ? Alignment.centerRight : Alignment.bottomCenter,
                colors: [
                  for (final c in const [
                    0xFFFF1744,
                    0xFFFFC400,
                    0xFF00E676,
                    0xFF00B8D4,
                    0xFFAA00FF,
                  ])
                    Color(c).withValues(alpha: 0.85 * (1 - k)),
                ],
              ).createShader(beam)
              ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
          );
        case FxKind.spark:
          final b = l.board;
          final rnd = Random(f.t0.hashCode ^ f.x.hashCode ^ f.y.hashCode);
          final ang = rnd.nextDouble() * pi * 2;
          final dist =
              cell *
              (0.6 + rnd.nextDouble() * 1.4) *
              Curves.easeOut.transform(k);
          final pos = Offset(
            b.left + f.x * cell + cos(ang) * dist,
            b.top + f.y * cell + sin(ang) * dist - k * cell * 0.5,
          );
          _star(
            canvas,
            pos,
            cell * 0.18 * (1 - k * 0.6),
            Color.lerp(
              blockPalette[f.color],
              Colors.white,
              0.4,
            )!.withValues(alpha: 1 - k),
          );
        case FxKind.text:
          final b = l.board;
          final pos = Offset(
            b.left + f.x * cell,
            b.top + f.y * cell - k * cell * 0.9,
          );
          final a = k < 0.75 ? 1.0 : (1 - k) / 0.25;
          final pop = 0.6 + 0.4 * Curves.elasticOut.transform(min(1, k * 3));
          _label(
            canvas,
            f.text!,
            pos,
            (f.big ? cell * 0.75 : cell * 0.5) * pop,
            f.color,
            a,
          );
      }
    }
  }

  void _star(Canvas canvas, Offset c, double r, Color color) {
    final path = Path();
    for (var i = 0; i < 10; i++) {
      final rr = i.isEven ? r : r * 0.45;
      final a = -pi / 2 + i * pi / 5;
      final p = c + Offset(cos(a) * rr, sin(a) * rr);
      i == 0 ? path.moveTo(p.dx, p.dy) : path.lineTo(p.dx, p.dy);
    }
    canvas.drawPath(path..close(), Paint()..color = color);
  }

  void _emoji(Canvas canvas, String e, Offset centre, double size) {
    final key = '$e@${size.round()}';
    final tp = _textCache[key] ??= TextPainter(
      text: TextSpan(
        text: e,
        style: TextStyle(fontSize: size),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, centre - Offset(tp.width / 2, tp.height / 2));
  }

  /// Outlined game text: 0 = score (white), 1 = combo (gold), 2 = praise (pink).
  void _label(
    Canvas canvas,
    String s,
    Offset centre,
    double size,
    int style,
    double alpha,
  ) {
    final fill = const [
      Color(0xFFFFFFFF),
      Color(0xFFFFD600),
      Color(0xFFFF80AB),
    ][style];
    TextPainter make(Paint? stroke, Color? color) => TextPainter(
      text: TextSpan(
        text: s,
        style: TextStyle(
          fontSize: size,
          fontWeight: FontWeight.w900,
          foreground: stroke,
          color: color,
          fontStyle: style == 1 ? FontStyle.italic : FontStyle.normal,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    final outline = make(
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = size * 0.16
        ..strokeJoin = StrokeJoin.round
        ..color = const Color(0xFF1A1F4E).withValues(alpha: alpha),
      null,
    );
    final front = make(null, fill.withValues(alpha: alpha));
    final o = centre - Offset(front.width / 2, front.height / 2);
    outline.paint(canvas, o);
    front.paint(canvas, o);
  }

  @override
  bool shouldRepaint(covariant _BoardPainter old) => true;
}

/// A glossy bevelled block (also used for the home screen and icon-like decorations).
void drawBlock(
  Canvas canvas,
  Rect rect,
  Color base, {
  double alpha = 1,
  bool shadow = false,
}) {
  final r = rect.deflate(rect.width * 0.03);
  final w = r.width;
  Color a(Color c) => c.withValues(alpha: alpha * c.a);
  if (shadow) {
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        r.shift(Offset(0, w * 0.12)),
        Radius.circular(w * 0.14),
      ),
      Paint()
        ..color = Colors.black.withValues(alpha: 0.25 * alpha)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
    );
  }
  final rr = RRect.fromRectAndRadius(r, Radius.circular(w * 0.14));
  canvas.save();
  canvas.clipRRect(rr);
  canvas.drawRect(r, Paint()..color = a(base));
  final bevel = w * 0.14;
  final light = Color.lerp(base, Colors.white, 0.45)!;
  final lightSide = Color.lerp(base, Colors.white, 0.22)!;
  final dark = Color.lerp(base, Colors.black, 0.28)!;
  final darkSide = Color.lerp(base, Colors.black, 0.16)!;
  Path quad(Offset p1, Offset p2, Offset p3, Offset p4) => Path()
    ..moveTo(p1.dx, p1.dy)
    ..lineTo(p2.dx, p2.dy)
    ..lineTo(p3.dx, p3.dy)
    ..lineTo(p4.dx, p4.dy)
    ..close();
  final tl = r.topLeft, tr = r.topRight, bl = r.bottomLeft, br = r.bottomRight;
  final itl = tl + Offset(bevel, bevel), itr = tr + Offset(-bevel, bevel);
  final ibl = bl + Offset(bevel, -bevel), ibr = br + Offset(-bevel, -bevel);
  canvas.drawPath(quad(tl, tr, itr, itl), Paint()..color = a(light));
  canvas.drawPath(quad(tl, itl, ibl, bl), Paint()..color = a(lightSide));
  canvas.drawPath(quad(bl, ibl, ibr, br), Paint()..color = a(dark));
  canvas.drawPath(quad(tr, br, ibr, itr), Paint()..color = a(darkSide));
  final inner = Rect.fromPoints(itl, ibr);
  canvas.drawRect(
    inner,
    Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [a(Color.lerp(base, Colors.white, 0.12)!), a(base)],
      ).createShader(inner),
  );
  // Small shine.
  canvas.drawCircle(
    itl + Offset(w * 0.1, w * 0.1),
    w * 0.05,
    Paint()..color = Colors.white.withValues(alpha: 0.7 * alpha),
  );
  canvas.restore();
}
