import 'dart:async' as async;
import 'dart:math';
import 'dart:ui' as ui;

import 'package:flame/components.dart';
import 'package:flame/game.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart' show Colors;
import 'package:flutter/widgets.dart';

import 'package:sk_core/core/content/foods.dart';

import 'package:sk_core/core/ui/palette.dart';

import '../engine/board.dart';
import 'fx_layer.dart';
import 'tile_component.dart';

class ClearInfo {
  ClearInfo(this.size, this.specials, this.created);
  final int size, specials, created;
}

/// Flame game: renders the board and runs swaps/cascades with animation.
/// Input comes from [Match3BoardView] (Flutter gestures) via [tapCell]/[swipe].
class Match3Game extends FlameGame {
  Match3Game({
    required this.types,
    this.speed = 1.0,
    this.idleHintMs = 7000,
    this.onClear,
    this.onSwap,
    this.onSettled,
    this.onInvalid,
    this.fxIntensity = 1.0,
    this.praise = const [],
    this.layout,
    Random? rng,
  }) : _rng = rng ?? _debugRng();

  /// Board shape + obstacles (see Board.fromLayout). Null = plain 7x7.
  final List<String>? layout;

  /// QA builds can pass --dart-define=SK_SEED=n for a repeatable board.
  static Random? _debugRng() {
    const seed = int.fromEnvironment('SK_SEED');
    return seed == 0 ? null : Random(seed);
  }

  final Random? _rng;
  final List<int> types;
  final double speed; // >1 = slower (calm mode)
  final int idleHintMs;

  /// 1.0 = full effects, ~0.4 = soft (parent setting / calm mode).
  final double fxIntensity;

  /// Praise words, from mild to strongest, e.g. ["Nice!", "Great!", "Awesome!", "Amazing!"].
  List<String> praise;
  void Function(Map<int, int> counts, int step, ClearInfo info)? onClear;
  VoidCallback? onSwap, onSettled, onInvalid;

  late final Board board = layout == null
      ? Board(types: types, rng: _rng)
      : Board.fromLayout(layout!, types: types, rng: _rng);
  int _mudClearedThisMove = 0;
  final Map<int, TileComponent> _comps = {};
  late final ClipComponent _clip;
  late final _BoardBackground _bg;
  late final FxLayer _fx;
  bool _parts = false;
  double _shake = 0, _clock = 0, _lastPraise = -10;
  final _shakeRng = Random();

  double cell = 40;
  Vector2 origin = Vector2.zero();
  bool busy = false, locked = false, destroyed = false;
  Cell? _selected;
  async.Timer? _idle;

  @override
  Color backgroundColor() => const Color(0x00000000);

  void _onFontsChanged() {
    TileComponent.clearCache();
    FxLayer.fontsChanged();
  }

  @override
  Future<void> onLoad() async {
    PaintingBinding.instance.systemFonts.addListener(_onFontsChanged);
    _bg = _BoardBackground();
    _clip = ClipComponent.rectangle();
    _fx = FxLayer()..intensity = fxIntensity;
    add(_bg);
    add(_clip);
    add(_fx);
    _parts = true;
    // QA build only (--dart-define=SK_SHOWCASE=true): one of each special in the top row.
    if (const bool.fromEnvironment('SK_SHOWCASE')) {
      final looks = [
        (Special.h, null),
        (Special.v, null),
        (Special.bomb, null),
        (Special.flyer, null),
        (Special.none, kRainbow),
        (Special.none, kNova),
      ];
      for (var c = 0; c < looks.length && c < board.cols; c++) {
        final t = board.g[0][c]!;
        t.special = looks[c].$1;
        if (looks[c].$2 != null) t.type = looks[c].$2!;
      }
    }
    _layout(size);
    _sync();
    _resetIdle();
  }

  @override
  void onGameResize(Vector2 size) {
    super.onGameResize(size);
    if (!_parts) return;
    _layout(size);
    _sync(snap: true);
  }

  void _layout(Vector2 s) {
    // Leave a margin for the board frame.
    final margin = min(s.x, s.y) * 0.035;
    cell = min(
      (s.x - 2 * margin) / board.cols,
      (s.y - 2 * margin) / board.rows,
    );
    origin = Vector2(
      (s.x - cell * board.cols) / 2,
      (s.y - cell * board.rows) / 2,
    );
    final boardSize = Vector2(cell * board.cols, cell * board.rows);
    _bg
      ..position = origin.clone()
      ..size = boardSize
      ..cell = cell
      ..rows = board.rows
      ..cols = board.cols
      ..board = board;
    _clip
      ..position = origin.clone()
      ..size = boardSize.clone();
    _fx
      ..position = origin.clone()
      ..size = boardSize.clone()
      ..cell = cell;
  }

  @override
  void update(double dt) {
    super.update(dt);
    _clock += dt;
    if (!_parts) return;
    // Screen shake for bombs / rainbow (skipped in soft mode).
    final offset = _shake > 0 && fxIntensity >= 0.7
        ? Vector2(
                (_shakeRng.nextDouble() - 0.5),
                (_shakeRng.nextDouble() - 0.5),
              ) *
              (cell * 0.22 * _shake)
        : Vector2.zero();
    _shake = max(0, _shake - dt * 2.5);
    final p = origin + offset;
    _bg.position.setFrom(p);
    _clip.position.setFrom(p);
    _fx.position.setFrom(p);
  }

  Vector2 _center(int r, int c) => Vector2((c + 0.5) * cell, (r + 0.5) * cell);

  static Color foodColor(int type) => type >= 0 && type < foods.length
      ? foods[type].color
      : const Color(0xFFFFD600);

  /// Foods the level still needs: flyer rockets aim at these.
  set preferTypes(Set<int> v) {
    board.preferTypes = v;
    board.preferObstacles = board.iceLeft + board.wallsLeft + board.mudLeft > 0;
  }

  void _effects(
    ClearResult res,
    List<Create> creates,
    List<Blast> blasts,
    int step,
  ) {
    const gold = Color(0xFFFFD600);
    for (final b in blasts) {
      final at = _center(b.r, b.c);
      switch (b.kind) {
        case BlastKind.lineH:
          _fx.beam(horizontal: true, at: at.y, color: Pure.orange);
          _shake = max(_shake, 0.35);
        case BlastKind.lineV:
          _fx.beam(horizontal: false, at: at.x, color: Pure.orange);
          _shake = max(_shake, 0.35);
        case BlastKind.bomb:
          _fx
            ..ring(at, radius: cell * 2.4, color: Pure.red, width: 18)
            ..ring(at, radius: cell * 1.5, color: Pure.orange)
            ..burst(at, gold, count: 30, speed: 1.5);
          _shake = max(_shake, 0.9);
        case BlastKind.rainbow:
          _fx
            ..rays(at, [
              for (final (r, c, _) in res.cells)
                if (r != b.r || c != b.c) _center(r, c),
            ])
            ..ring(
              at,
              radius: cell * 3,
              color: const Color(0xFFFF1744),
              width: 16,
            )
            ..burst(at, const Color(0xFF2979FF), count: 30, speed: 1.5);
          _shake = max(_shake, 0.8);
        case BlastKind.nova:
          // Shockwave already shown before the clear (see _doClear); add a golden finale.
          _fx.burst(at, gold, count: 40, speed: 2);
        case BlastKind.flyer:
          _fx.burst(at, foodColor(board.at((b.r, b.c))?.type ?? -1), count: 16);
      }
    }
    final many = res.cells.length > 12;
    for (final (r, c, type) in res.cells) {
      final color = foodColor(type);
      final at = _center(r, c);
      _fx
        ..ring(at, radius: cell * 0.85, color: color, width: 10)
        ..burst(at, color, count: many ? 7 : 14);
    }
    for (final cr in creates) {
      final at = _center(cr.r, cr.c);
      _fx
        ..ring(at, radius: cell * 1.0, color: gold, width: 8)
        ..burst(at, gold, count: 16, speed: 0.8);
    }
    // Praise grows with combos, big matches and specials.
    final level =
        step +
        (blasts.isNotEmpty ? 1 : 0) +
        (res.ids.length >= 5 ? 1 : 0) +
        (creates.isNotEmpty ? 1 : 0);
    if (level >= 1 && praise.isNotEmpty && _clock - _lastPraise > 0.4) {
      _lastPraise = _clock;
      _fx.praise(
        praise[min(level, praise.length) - 1],
        Vector2(cell * board.cols / 2, cell * board.rows * 0.42),
      );
    }
  }

  Vector2 _pos(num r, num c) => Vector2(c * cell, r * cell);

  void _sync({List<Spawn> spawns = const [], bool snap = false}) {
    final from = {for (final s in spawns) s.tile.id: s.fromRow};
    final seen = <int>{};
    for (var r = 0; r < board.rows; r++) {
      for (var c = 0; c < board.cols; c++) {
        final t = board.g[r][c];
        if (t == null) continue;
        seen.add(t.id);
        var comp = _comps[t.id];
        if (comp == null) {
          comp = TileComponent(t)
            ..position = _pos(from[t.id] ?? (r - board.rows - 1), c);
          _comps[t.id] = comp;
          _clip.add(comp);
        }
        comp
          ..size = Vector2.all(cell)
          ..target.setFrom(_pos(r, c))
          ..refresh();
        if (snap) comp.snap();
      }
    }
    _comps.removeWhere((id, comp) {
      if (seen.contains(id)) return false;
      comp.removeFromParent();
      return true;
    });
  }

  Future<void> _wait(int ms) =>
      Future.delayed(Duration(milliseconds: (ms * speed).round()));

  /// Ice cracking and blocker hits.
  void _obstacleEffects(ClearResult res) {
    const iceBlue = Color(0xFF4FC3F7);
    for (final (r, c, layersLeft) in res.iceHits) {
      final at = _center(r, c);
      _fx
        ..ring(at, radius: cell * 0.8, color: iceBlue, width: 10)
        ..burst(at, iceBlue, count: layersLeft == 0 ? 14 : 8, speed: 0.9);
    }
    for (final (r, c, type, destroyed) in res.blockerHits) {
      final at = _center(r, c);
      final color = type == kMud
          ? const Color(0xFF6D4C41)
          : const Color(0xFFD84315);
      _fx.burst(
        at,
        color,
        count: destroyed ? 18 : 9,
        speed: destroyed ? 1.2 : 0.7,
      );
      if (destroyed) _fx.ring(at, radius: cell * 0.9, color: color, width: 10);
      _shake = max(_shake, destroyed ? 0.3 : 0.15);
    }
  }

  // ---------- input ----------
  Cell? cellAt(Offset p) {
    final c = ((p.dx - origin.x) / cell).floor();
    final r = ((p.dy - origin.y) / cell).floor();
    return (r >= 0 && r < board.rows && c >= 0 && c < board.cols)
        ? (r, c)
        : null;
  }

  void interact() => _resetIdle();

  void tapCell(Cell cell) {
    if (busy || locked) return;
    if (!board.isMovable(cell)) {
      _select(null);
      return;
    }
    final s = _selected;
    if (s != null) {
      _select(null);
      if (s == cell) return;
      if (adjacent(s, cell)) {
        trySwap(s, cell);
        return;
      }
    }
    _select(cell);
  }

  void swipe(Cell from, Offset delta) {
    final (r, c) = from;
    final Cell to = delta.dx.abs() > delta.dy.abs()
        ? (r, c + delta.dx.sign.toInt())
        : (r + delta.dy.sign.toInt(), c);
    if (to.$1 < 0 || to.$1 >= board.rows || to.$2 < 0 || to.$2 >= board.cols) {
      return;
    }
    trySwap(from, to);
  }

  void _select(Cell? cell) {
    for (final comp in _comps.values) {
      comp.selected = false;
    }
    _selected = cell;
    if (cell != null) _compAt(cell)?.selected = true;
  }

  TileComponent? _compAt(Cell c) {
    final t = board.at(c);
    return t == null ? null : _comps[t.id];
  }

  void _clearHint() {
    for (final comp in _comps.values) {
      comp.hint = false;
    }
  }

  void _resetIdle() {
    _idle?.cancel();
    _clearHint();
    if (locked || destroyed) return;
    _idle = async.Timer(Duration(milliseconds: idleHintMs), () {
      if (busy || locked || destroyed) return;
      final m = board.findAnyMove();
      if (m == null) return;
      _compAt(m.$1)?.hint = true;
      _compAt(m.$2)?.hint = true;
    });
  }

  // ---------- game flow ----------
  Future<void> trySwap(Cell a, Cell b) async {
    if (busy || locked || destroyed || !board.canSwap(a, b)) return;
    _mudClearedThisMove = 0;
    busy = true;
    _select(null);
    _idle?.cancel();
    _clearHint();

    board.swap(a, b);
    _sync();
    await _wait(180);
    if (destroyed) return;

    if (board.at(a)!.isWild || board.at(b)!.isWild) {
      onSwap?.call();
      final (clear, fired, blast) = board.wildClear(a, b);
      final blasts = board.expandSpecials(clear, fired: fired);
      board.addAdjacentHits(clear);
      await _doClear(clear, const [], 0, [blast, ...blasts]);
      await _cascade(const [], 1);
    } else if (!board.hasMatch) {
      // Not a match: gently swap back. No move is used.
      board.swap(a, b);
      _sync();
      await _wait(180);
      onInvalid?.call();
      busy = false;
      _resetIdle();
      return;
    } else {
      onSwap?.call();
      await _cascade([a, b], 0);
    }
    if (destroyed) return;

    // Mud grows if this move cleaned none of it.
    if (board.mudLeft > 0 && _mudClearedThisMove == 0) {
      final grown = board.spreadMud();
      if (grown != null) {
        _sync();
        _fx.burst(
          _center(grown.$1, grown.$2),
          const Color(0xFF6D4C41),
          count: 10,
          speed: 0.6,
        );
        await _wait(350);
        if (destroyed) return;
      }
    }

    if (board.findAnyMove() == null) {
      board.shuffle();
      _sync();
      await _wait(350);
    }
    busy = false;
    onSettled?.call();
    _resetIdle();
  }

  Future<void> _cascade(List<Cell> pivots, int step) async {
    while (!destroyed) {
      final found = board.findMatches();
      if (found.isEmpty) break;
      final plan = board.planClear(found, pivots);
      final protect = {for (final cr in plan.creates) cellKey(cr.r, cr.c)};
      final blasts = board.expandSpecials(plan.clear, protect: protect);
      board.addAdjacentHits(plan.clear);
      await _doClear(plan.clear, plan.creates, step++, blasts);
      pivots = const [];
    }
  }

  Future<void> _doClear(
    Set<int> clear,
    List<Create> creates,
    int step,
    List<Blast> blasts,
  ) async {
    // Rockets fly to their targets before those tiles pop.
    final flyers = blasts.where((b) => b.kind == BlastKind.flyer).toList();
    if (flyers.isNotEmpty) {
      for (final f in flyers) {
        final from = _center(f.r, f.c);
        final color = foodColor(board.at((f.r, f.c))?.type ?? -1);
        for (var i = 0; i < f.targets.length; i++) {
          _fx.flight(
            from,
            _center(f.targets[i].$1, f.targets[i].$2),
            color,
            bend: i - 1.0,
          );
        }
      }
      await _wait(420);
      if (destroyed) return;
    }
    // Whole-board clear: a big golden wave first.
    final nova = blasts.where((b) => b.kind == BlastKind.nova).firstOrNull;
    if (nova != null) {
      _fx.nova(_center(nova.r, nova.c), radius: cell * board.cols * 1.2);
      _shake = 1;
      await _wait(320);
      if (destroyed) return;
    }
    final res = board.applyClear(clear);
    board.applyCreates(creates, res.counts);
    _mudClearedThisMove += res.mudDestroyed;
    _obstacleEffects(res);
    onClear?.call(
      res.counts,
      step,
      ClearInfo(res.ids.length, blasts.length, creates.length),
    );
    if (blasts.isNotEmpty) _bg.flash();
    _effects(res, creates, blasts, step);
    for (final id in res.ids) {
      _comps.remove(id)?.pop();
    }
    _sync();
    await _wait(230);
    if (destroyed) return;
    board.gravity();
    final spawns = board.refill();
    _sync(spawns: spawns);
    await _wait(300);
  }

  /// Continue playing after a pause (e.g. extra moves were earned).
  void unlock() {
    if (destroyed) return;
    locked = false;
    _resetIdle();
  }

  void lock() {
    locked = true;
    _idle?.cancel();
    _clearHint();
  }

  void destroy() {
    PaintingBinding.instance.systemFonts.removeListener(_onFontsChanged);
    destroyed = true;
    lock();
  }
}

/// Solid (opaque) board in the level's shape: blue frame + one rounded cell per board square.
/// Holes stay empty (the sky shows through). Ice is drawn live on top of the cells.
/// The static part (shadow, frame, cells) is cached as an image and redrawn only on resize.
class _BoardBackground extends PositionComponent {
  double _flash = 0;
  double cell = 40;
  int rows = 7, cols = 7;
  Board? board;
  ui.Image? _cache;
  double _cacheCell = -1;

  void flash() => _flash = 1;

  static const _frameTop = Color(0xFF448AFF);
  static const _frameBottom = Color(0xFF2962FF);
  static const _cellA = Color(0xFFFFFFFF);
  static const _cellB = Color(0xFFE3F2FD);

  bool _isCell(int r, int c) => board == null || board!.isCell(r, c);

  @override
  void update(double dt) {
    if (_flash > 0) _flash = max(0, _flash - dt * 3);
  }

  /// Extra space around the board for the frame and shadow.
  double get _pad => cell * 0.3;

  ui.Image _staticImage() {
    if (_cache != null && _cacheCell == cell) return _cache!;
    final dpr = ui.PlatformDispatcher.instance.views.first.devicePixelRatio
        .clamp(1.0, 3.0);
    final rec = ui.PictureRecorder();
    final canvas = Canvas(rec);
    canvas.scale(dpr);
    canvas.translate(_pad, _pad);
    final framePad = cell * 0.16;
    final cellsRects = <Rect>[
      for (var r = 0; r < rows; r++)
        for (var c = 0; c < cols; c++)
          if (_isCell(r, c)) Rect.fromLTWH(c * cell, r * cell, cell, cell),
    ];
    // Shadow + frame: the union of slightly bigger squares around every board cell.
    final shadow = Paint()
      ..color = const Color(0x55000000)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, cell * 0.12);
    final union = Path();
    for (final rc in cellsRects) {
      union.addRRect(
        RRect.fromRectAndRadius(
          rc.inflate(framePad),
          Radius.circular(cell * 0.32),
        ),
      );
    }
    canvas.drawPath(union.shift(Offset(0, cell * 0.08)), shadow);
    canvas.drawPath(
      union,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [_frameTop, _frameBottom],
        ).createShader(Rect.fromLTWH(0, 0, cols * cell, rows * cell)),
    );
    final gap = cell * 0.035;
    final a = Paint()..color = _cellA, b = Paint()..color = _cellB;
    for (var r = 0; r < rows; r++) {
      for (var c = 0; c < cols; c++) {
        if (!_isCell(r, c)) continue;
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(
              c * cell + gap,
              r * cell + gap,
              cell - 2 * gap,
              cell - 2 * gap,
            ),
            Radius.circular(cell * 0.2),
          ),
          (r + c).isEven ? a : b,
        );
      }
    }
    final w = cols * cell + 2 * _pad, h = rows * cell + 2 * _pad;
    _cache?.dispose();
    _cache = rec.endRecording().toImageSync((w * dpr).ceil(), (h * dpr).ceil());
    _cacheCell = cell;
    return _cache!;
  }

  @override
  void render(Canvas canvas) {
    final img = _staticImage();
    canvas.drawImageRect(
      img,
      Rect.fromLTWH(0, 0, img.width.toDouble(), img.height.toDouble()),
      Rect.fromLTWH(
        -_pad,
        -_pad,
        cols * cell + 2 * _pad,
        rows * cell + 2 * _pad,
      ),
      Paint()..filterQuality = FilterQuality.medium,
    );
    // Ice (under the fruits): 1 layer = light, 2 layers = thick with a frosty border.
    final b = board;
    if (b != null) {
      final gap = cell * 0.035;
      for (var r = 0; r < rows; r++) {
        for (var c = 0; c < cols; c++) {
          final layers = b.mask[r][c] ? b.ice[r][c] : 0;
          if (layers == 0) continue;
          final rr = RRect.fromRectAndRadius(
            Rect.fromLTWH(
              c * cell + gap,
              r * cell + gap,
              cell - 2 * gap,
              cell - 2 * gap,
            ),
            Radius.circular(cell * 0.2),
          );
          canvas.drawRRect(
            rr,
            Paint()
              ..color = layers >= 2
                  ? const Color(0xFF0288D1)
                  : const Color(0xFF4FC3F7),
          );
          canvas.drawRRect(
            rr.deflate(2),
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = layers >= 2 ? 4 : 2.5
              ..color = Colors.white.withValues(alpha: 0.95),
          );
          // frosty shine
          final shine = Paint()
            ..color = Colors.white.withValues(alpha: 0.8)
            ..strokeWidth = cell * 0.05
            ..strokeCap = StrokeCap.round;
          canvas.drawLine(
            Offset(c * cell + cell * 0.18, r * cell + cell * 0.38),
            Offset(c * cell + cell * 0.38, r * cell + cell * 0.18),
            shine,
          );
          if (layers >= 2) {
            canvas.drawLine(
              Offset(c * cell + cell * 0.62, r * cell + cell * 0.82),
              Offset(c * cell + cell * 0.82, r * cell + cell * 0.62),
              shine,
            );
          }
        }
      }
    }
    if (_flash > 0) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(0, 0, cols * cell, rows * cell),
          Radius.circular(cell * 0.3),
        ),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 5
          ..color = const Color(0xFFFFD600).withValues(alpha: _flash),
      );
    }
  }
}

/// Flutter widget hosting the board: swipe or tap-tap to swap.
class Match3BoardView extends StatefulWidget {
  const Match3BoardView({super.key, required this.game});
  final Match3Game game;
  @override
  State<Match3BoardView> createState() => _Match3BoardViewState();
}

class _Match3BoardViewState extends State<Match3BoardView> {
  Offset? _start;
  Cell? _startCell;
  bool _swiped = false;

  void _down(Offset p) {
    _start = p;
    _startCell = widget.game.cellAt(p);
    _swiped = false;
    widget.game.interact();
  }

  @override
  Widget build(BuildContext context) {
    final game = widget.game;
    return AspectRatio(
      aspectRatio: 1,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        dragStartBehavior: DragStartBehavior.down,
        onPanDown: (d) => _down(d.localPosition),
        onPanStart: (d) {
          if (_start == null) _down(d.localPosition);
        },
        onPanUpdate: (d) {
          if (_swiped || _start == null || _startCell == null) return;
          final delta = d.localPosition - _start!;
          if (delta.distance < game.cell * 0.3) return;
          _swiped = true;
          game.swipe(_startCell!, delta);
        },
        onPanEnd: (_) => _start = null,
        onPanCancel: () => _start = null,
        onTapUp: (d) {
          final c = game.cellAt(d.localPosition);
          if (c != null) game.tapCell(c);
        },
        child: GameWidget(game: game),
      ),
    );
  }
}
