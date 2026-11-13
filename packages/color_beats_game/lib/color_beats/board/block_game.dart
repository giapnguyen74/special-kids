import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';

import '../engine/grid.dart';

/// A short-lived visual effect on the board (time in seconds since the game started).
class Fx {
  Fx(
    this.kind,
    this.t0, {
    this.cell,
    this.line,
    this.color = 0,
    this.text,
    this.x = 0,
    this.y = 0,
    this.big = false,
  });
  final FxKind kind;
  final double t0;
  final Cell? cell;

  /// Row (>= 0) or column (encoded as -1 - col) for line beams.
  final int? line;
  final int color;
  final String? text;

  /// Board coordinates in cells (for texts and sparkles).
  final double x, y;
  final bool big;

  double get life => switch (kind) {
    FxKind.pop => 0.18,
    FxKind.clear => 0.45,
    FxKind.beam => 0.5,
    FxKind.text => 1.1,
    FxKind.spark => 0.7,
  };
}

enum FxKind { pop, clear, beam, text, spark }

/// Game state + rules glue for the block board. The view only draws it and forwards touches.
class BlockGame extends ChangeNotifier {
  BlockGame({
    required this.grid,
    required this.dealer,
    this.fxIntensity = 1,
    this.idleHintMs = 10000,
    this.onPlaced,
    this.onStuck,
    this.onTap,
  }) {
    tray = <Piece?>[...dealer.deal(grid)];
    _checkStuck();
    _armHint();
  }

  final Grid grid;
  final PieceDealer dealer;
  final double fxIntensity;

  /// After this long without a move, a placement is suggested (help that only shows when needed).
  final int idleHintMs;

  final void Function(PlaceResult r)? onPlaced;

  /// No piece in the tray fits anywhere.
  final VoidCallback? onStuck;

  /// Any touch (for sounds).
  final VoidCallback? onTap;

  List<String> praise = const ['Nice!', 'Great!', 'Awesome!', 'Amazing!'];

  late List<Piece?> tray;
  bool locked = false;
  bool _disposed = false;

  final Stopwatch _clock = Stopwatch()..start();
  double get now => _clock.elapsedMicroseconds / 1e6;
  final List<Fx> fx = [];

  /// Piece being dragged / selected (tray index).
  int? dragging;
  int? selected;

  /// Where the dragged piece would land (top-left cell), if it fits.
  Cell? target;

  /// Suggested move (tray index, r, c) shown after a long idle time.
  (int, int, int)? hint;
  Timer? _hintTimer;

  /// Moves since the hint was last needed: the hint waits longer as the child plays on their own.
  int _movesSinceHint = 0;

  bool fitsAnywhere(int i) => tray[i] != null && grid.fits(tray[i]!);

  void _armHint() {
    _hintTimer?.cancel();
    hint = null;
    if (locked || idleHintMs <= 0) return;
    final wait = idleHintMs + min(_movesSinceHint, 10) * 1000;
    _hintTimer = Timer(Duration(milliseconds: wait), () {
      if (_disposed || locked || dragging != null) return;
      hint = grid.bestMove(tray);
      _movesSinceHint = 0;
      notifyListeners();
    });
  }

  /// Child touched something: hide the hint and restart the idle timer.
  void touched() {
    if (hint != null) {
      hint = null;
      notifyListeners();
    }
    _armHint();
  }

  void startDrag(int i) {
    if (locked || tray[i] == null) return;
    dragging = i;
    target = null;
    onTap?.call();
    touched();
    notifyListeners();
  }

  /// [r], [c]: wanted top-left cell (may be fractional). Snaps to the nearest cell where the piece fits.
  void dragTo(double r, double c) {
    final p = dragging == null ? null : tray[dragging!];
    if (p == null) return;
    final t = _snap(p, r, c);
    if (t != target) {
      target = t;
      notifyListeners();
    }
  }

  Cell? _snap(Piece p, double r, double c) {
    final r0 = r.round(), c0 = c.round();
    if (grid.canPlace(p, r0, c0)) return (r0, c0);
    // Forgiving: look one cell around for the closest spot that fits.
    Cell? best;
    var bestD = 1.6;
    for (var dr = -1; dr <= 1; dr++) {
      for (var dc = -1; dc <= 1; dc++) {
        final rr = r0 + dr, cc = c0 + dc;
        if (!grid.canPlace(p, rr, cc)) continue;
        final d = sqrt(pow(rr - r, 2) + pow(cc - c, 2));
        if (d < bestD) {
          bestD = d;
          best = (rr, cc);
        }
      }
    }
    return best;
  }

  /// Finger lifted. Returns true if the piece was placed.
  bool endDrag() {
    final i = dragging;
    final t = target;
    dragging = null;
    target = null;
    if (i != null && t != null) {
      _place(i, t.$1, t.$2);
      return true;
    }
    notifyListeners();
    return false;
  }

  void cancelDrag() {
    dragging = null;
    target = null;
    notifyListeners();
  }

  /// Tap mode (easier for some hands): tap a piece, then tap the board.
  void select(int i) {
    if (locked || tray[i] == null) return;
    selected = selected == i ? null : i;
    onTap?.call();
    touched();
    notifyListeners();
  }

  /// Board tapped at fractional cell (r, c) with a piece selected: centre the piece there.
  bool tapBoard(double r, double c) {
    final i = selected;
    if (locked || i == null) return false;
    final p = tray[i]!;
    final t = _snap(p, r - p.rows / 2, c - p.cols / 2);
    if (t == null) return false;
    selected = null;
    _place(i, t.$1, t.$2);
    return true;
  }

  void _place(int i, int r, int c) {
    final p = tray[i]!;
    final res = grid.place(p, r, c);
    tray[i] = null;
    _movesSinceHint++;
    final t = now;
    for (final cell in res.cells) {
      fx.add(Fx(FxKind.pop, t, cell: cell, color: p.color));
    }
    _addClearFx(res, t);
    if (res.lines > 0) {
      final words = praise;
      final word =
          words[min(
            res.lines + res.combo - 2,
            words.length - 1,
          ).clamp(0, words.length - 1)];
      final (cy, cx) = res.cells.isEmpty ? (3.5, 3.5) : _centre(res.cells);
      fx.add(
        Fx(FxKind.text, t, text: '+${res.points}', x: cx, y: cy, color: 0),
      );
      if (res.combo >= 2) {
        fx.add(
          Fx(
            FxKind.text,
            t + 0.1,
            text: 'Combo ${res.combo}',
            x: 4,
            y: 2.2,
            big: true,
            color: 1,
          ),
        );
      } else if (res.lines >= 2) {
        fx.add(
          Fx(
            FxKind.text,
            t + 0.1,
            text: word,
            x: 4,
            y: 2.2,
            big: true,
            color: 2,
          ),
        );
      }
    }
    if (tray.every((e) => e == null)) tray = <Piece?>[...dealer.deal(grid)];
    onPlaced?.call(res);
    _checkStuck();
    _armHint();
    notifyListeners();
  }

  (double, double) _centre(List<Cell> cells) {
    var r = 0.0, c = 0.0;
    for (final (rr, cc) in cells) {
      r += rr;
      c += cc;
    }
    return (r / cells.length + 0.5, c / cells.length + 0.5);
  }

  void _addClearFx(PlaceResult res, double t) {
    for (final rr in res.rows) {
      fx.add(Fx(FxKind.beam, t, line: rr));
    }
    for (final cc in res.cols) {
      fx.add(Fx(FxKind.beam, t, line: -1 - cc));
    }
    final rnd = Random();
    for (final MapEntry(key: cell, value: color) in res.cleared.entries) {
      // Sweep along the line so it plays like a little run of notes.
      final delay = (res.rows.contains(cell.$1) ? cell.$2 : cell.$1) * 0.025;
      fx.add(Fx(FxKind.clear, t + delay, cell: cell, color: color));
      if (fxIntensity >= 0.9 && rnd.nextDouble() < 0.5) {
        fx.add(
          Fx(
            FxKind.spark,
            t + delay,
            x: cell.$2 + 0.5,
            y: cell.$1 + 0.5,
            color: color,
          ),
        );
      }
    }
  }

  void _checkStuck() {
    if (tray.any((p) => p != null && grid.fits(p))) return;
    locked = true;
    _hintTimer?.cancel();
    hint = null;
    Timer(const Duration(milliseconds: 700), () {
      if (!_disposed) onStuck?.call();
    });
  }

  /// Help: empty the [rows] fullest rows, give a fresh tray that fits, carry on.
  PlaceResult rescue({int rows = 3}) {
    final res = grid.clearFullest(rows);
    _addClearFx(res, now);
    tray = <Piece?>[...dealer.deal(grid)];
    locked = false;
    selected = null;
    _checkStuck();
    _armHint();
    notifyListeners();
    return res;
  }

  void lock() {
    locked = true;
    _hintTimer?.cancel();
    hint = null;
    dragging = null;
    selected = null;
    notifyListeners();
  }

  /// Drops finished effects. Called by the view each frame.
  void tick() {
    final t = now;
    fx.removeWhere((f) => t > f.t0 + f.life);
  }

  @override
  void dispose() {
    _disposed = true;
    _hintTimer?.cancel();
    super.dispose();
  }
}
