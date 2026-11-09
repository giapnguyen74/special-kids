// Pure match-3 engine (no Flutter imports) — unit tested, also used by the level generator.
//
// Specials (created by the match shape):
//   4 in a line        -> line blaster  (Special.h / Special.v): clears its row / column
//   L or T shape       -> bomb          (Special.bomb): clears the 3x3 around it
//   2x2 square         -> flyer         (Special.flyer): 3 rockets clear 3 cells (needed foods / obstacles first)
//   5 in a line        -> rainbow       (kRainbow): swap with a food -> clears that food everywhere
//   6+ in a line       -> nova          (kNova): clears the whole board
//   rainbow + rainbow  -> clears the whole board
//
// Board shapes and obstacles (from a layout, see [Board.fromLayout]):
//   '.' hole (not part of the board)   'o' normal cell
//   'i' ice (1 layer)  'I' ice (2 layers) — under the fruit; cracks when a fruit on that cell clears
//   'w' wall (1 hit)   'W' rock (2 hits) — occupies the cell; hit by matches next to it or by blasts
//   'm' mud (1 hit)    — like a wall, but spreads to a neighbour if a move clears no mud
// Blockers never fall; fruits fall past holes and blockers (so nothing can get stuck).
import 'dart:math';

/// Wild tiles have no food type (they match nothing; swap them with any neighbor).
const int kRainbow = -1;
const int kNova = -2;

/// Blockers occupy a cell and cannot be moved.
const int kWall = -10;
const int kMud = -11;

enum Special { none, h, v, bomb, flyer }

class Tile {
  Tile(this.type, [this.special = Special.none, this.hp = 1]) : id = _nextId++;
  static int _nextId = 1;
  final int id;
  int type;
  Special special;

  /// Hits left (blockers only).
  int hp;
  bool get isRainbow => type == kRainbow;
  bool get isNova => type == kNova;
  bool get isWild => type == kRainbow || type == kNova;
  bool get isBlocker => type <= -10;
  bool get isWall => type == kWall;
  bool get isMud => type == kMud;
  bool get isFruit => type >= 0;
}

typedef Cell = (int, int);

int cellKey(int r, int c) => r * 16 + c;
Cell unkey(int k) => (k ~/ 16, k % 16);
bool adjacent(Cell a, Cell b) => (a.$1 - b.$1).abs() + (a.$2 - b.$2).abs() == 1;

class Run {
  Run(this.horizontal, this.type, this.cells);
  final bool horizontal;
  final int type;
  final List<Cell> cells;
}

class Matches {
  Matches(this.runs, this.squares);
  final List<Run> runs;

  /// 2x2 same-food blocks (non-overlapping).
  final List<List<Cell>> squares;
  bool get isEmpty => runs.isEmpty && squares.isEmpty;
  bool get isNotEmpty => !isEmpty;
}

class Create {
  Create(this.r, this.c, this.type, this.special, this.fromType);
  final int r, c, type, fromType;
  final Special special;
}

class ClearPlan {
  ClearPlan(this.clear, this.creates);
  final Set<int> clear;
  final List<Create> creates;
}

/// What one clear step did (for goals, effects and the mud rule).
class ClearResult {
  ClearResult(this.counts, this.ids, this.cells);

  /// Fruits cleared per food type.
  final Map<int, int> counts;

  /// Tile ids that left the board (fruits, wilds, destroyed blockers).
  final List<int> ids;

  /// Cleared fruit/wild cells with their type (for effects).
  final List<(int, int, int)> cells;

  /// Ice layers cracked: (row, col, layers left).
  final List<(int, int, int)> iceHits = [];

  /// Blockers hit: (row, col, type, destroyed?).
  final List<(int, int, int, bool)> blockerHits = [];

  /// Tile ids of blockers that were hit but survived (need a redraw).
  final List<int> damagedIds = [];

  int iceCleared = 0;
  int wallsDestroyed = 0;
  int mudDestroyed = 0;
}

enum BlastKind { lineH, lineV, bomb, rainbow, nova, flyer }

/// A special tile that fired (for visual effects). [targets] = where flyer rockets go.
class Blast {
  Blast(this.kind, this.r, this.c, [this.targets = const []]);
  final BlastKind kind;
  final int r, c;
  final List<Cell> targets;
}

class Spawn {
  Spawn(this.tile, this.fromRow);
  final Tile tile;
  final int fromRow;
}

class Board {
  /// Full rectangular board, no obstacles.
  Board({required this.types, this.rows = 7, this.cols = 7, Random? rng})
    : rng = rng ?? Random() {
    mask = List.generate(rows, (_) => List.filled(cols, true));
    ice = List.generate(rows, (_) => List.filled(cols, 0));
    _create(const {});
  }

  /// Board from a layout (see file header for the characters).
  Board.fromLayout(List<String> layout, {required this.types, Random? rng})
    : rows = layout.length,
      cols = layout.first.length,
      rng = rng ?? Random() {
    mask = [
      for (final row in layout) [for (final ch in row.split('')) ch != '.'],
    ];
    ice = [
      for (final row in layout)
        [for (final ch in row.split('')) ch == 'I' ? 2 : (ch == 'i' ? 1 : 0)],
    ];
    final blockers = <int, Tile Function()>{};
    for (var r = 0; r < rows; r++) {
      for (var c = 0; c < cols; c++) {
        switch (layout[r][c]) {
          case 'w':
            blockers[cellKey(r, c)] = () => Tile(kWall, Special.none, 1);
          case 'W':
            blockers[cellKey(r, c)] = () => Tile(kWall, Special.none, 2);
          case 'm':
            blockers[cellKey(r, c)] = () => Tile(kMud, Special.none, 1);
        }
      }
    }
    _create(blockers);
  }

  /// Test helper: build from explicit types (values >= 100 never match each other).
  Board.fromTypes(List<List<int>> rowsTypes, {required this.types, Random? rng})
    : rows = rowsTypes.length,
      cols = rowsTypes.first.length,
      rng = rng ?? Random() {
    mask = List.generate(rows, (_) => List.filled(cols, true));
    ice = List.generate(rows, (_) => List.filled(cols, 0));
    g = [
      for (final row in rowsTypes) [for (final t in row) Tile(t)],
    ];
  }

  final int rows, cols;
  final List<int> types;
  final Random rng;
  late List<List<Tile?>> g;

  /// true = this square is part of the board (false = hole).
  late final List<List<bool>> mask;

  /// Ice layers under each cell (0 = none).
  late final List<List<int>> ice;

  /// Foods the level still needs — flyer rockets aim at these first.
  Set<int> preferTypes = {};

  /// Rockets also aim at ice / blockers while those missions are open.
  bool preferObstacles = false;

  Tile? at(Cell c) => g[c.$1][c.$2];
  int _pick() => types[rng.nextInt(types.length)];

  bool isCell(int r, int c) =>
      r >= 0 && r < rows && c >= 0 && c < cols && mask[r][c];

  /// A cell whose tile can be swapped (fruit or wild).
  bool isMovable(Cell p) {
    if (!isCell(p.$1, p.$2)) return false;
    final t = at(p);
    return t != null && !t.isBlocker;
  }

  bool canSwap(Cell a, Cell b) =>
      adjacent(a, b) && isMovable(a) && isMovable(b);

  // ------------------------------------------------------------------ counts
  int get iceLeft {
    var n = 0;
    for (var r = 0; r < rows; r++) {
      for (var c = 0; c < cols; c++) {
        if (mask[r][c] && ice[r][c] > 0) n++;
      }
    }
    return n;
  }

  int _countType(int type) {
    var n = 0;
    for (final row in g) {
      for (final t in row) {
        if (t?.type == type) n++;
      }
    }
    return n;
  }

  int get wallsLeft => _countType(kWall);
  int get mudLeft => _countType(kMud);

  // ------------------------------------------------------------------ setup
  void _create(Map<int, Tile Function()> blockers) {
    for (var attempt = 0; attempt < 400; attempt++) {
      g = List.generate(rows, (_) => List<Tile?>.filled(cols, null));
      for (var r = 0; r < rows; r++) {
        for (var c = 0; c < cols; c++) {
          if (!mask[r][c]) continue;
          final b = blockers[cellKey(r, c)];
          if (b != null) {
            g[r][c] = b();
            continue;
          }
          var t = _pick();
          var guard = 0;
          bool same(int rr, int cc) => _typeAt(rr, cc) == t;
          while (guard++ < 50 &&
              ((same(r, c - 1) && same(r, c - 2)) ||
                  (same(r - 1, c) && same(r - 2, c)) ||
                  (same(r - 1, c - 1) && same(r - 1, c) && same(r, c - 1)))) {
            t = _pick();
          }
          g[r][c] = Tile(t);
        }
      }
      if (!hasMatch && findAnyMove() != null) return;
    }
    throw StateError('could not create board');
  }

  void swap(Cell a, Cell b) {
    final t = g[a.$1][a.$2];
    g[a.$1][a.$2] = g[b.$1][b.$2];
    g[b.$1][b.$2] = t;
  }

  /// Food type at a cell (null for holes, empty cells, wilds and blockers).
  int? _typeAt(int r, int c) {
    if (!isCell(r, c)) return null;
    final t = g[r][c];
    return (t != null && t.isFruit) ? t.type : null;
  }

  // ------------------------------------------------------------------ matching
  List<Run> findRuns() {
    final runs = <Run>[];
    for (var r = 0; r < rows; r++) {
      var c = 0;
      while (c < cols) {
        final t = _typeAt(r, c);
        var e = c + 1;
        if (t != null) {
          while (e < cols && _typeAt(r, e) == t) {
            e++;
          }
          if (e - c >= 3) {
            runs.add(Run(true, t, [for (var x = c; x < e; x++) (r, x)]));
          }
        }
        c = e;
      }
    }
    for (var c = 0; c < cols; c++) {
      var r = 0;
      while (r < rows) {
        final t = _typeAt(r, c);
        var e = r + 1;
        if (t != null) {
          while (e < rows && _typeAt(e, c) == t) {
            e++;
          }
          if (e - r >= 3) {
            runs.add(Run(false, t, [for (var y = r; y < e; y++) (y, c)]));
          }
        }
        r = e;
      }
    }
    return runs;
  }

  /// Non-overlapping 2x2 blocks of the same food.
  List<List<Cell>> findSquares() {
    final squares = <List<Cell>>[];
    final taken = <int>{};
    for (var r = 0; r < rows - 1; r++) {
      for (var c = 0; c < cols - 1; c++) {
        final t = _typeAt(r, c);
        if (t == null ||
            _typeAt(r, c + 1) != t ||
            _typeAt(r + 1, c) != t ||
            _typeAt(r + 1, c + 1) != t) {
          continue;
        }
        final cells = <Cell>[(r, c), (r, c + 1), (r + 1, c), (r + 1, c + 1)];
        if (cells.any((p) => taken.contains(cellKey(p.$1, p.$2)))) continue;
        for (final (y, x) in cells) {
          taken.add(cellKey(y, x));
        }
        squares.add(cells);
      }
    }
    return squares;
  }

  Matches findMatches() => Matches(findRuns(), findSquares());

  bool get hasMatch => findRuns().isNotEmpty || findSquares().isNotEmpty;

  /// Fast local check: does the fruit at (r,c) form a line of 3 or a 2x2 square?
  bool _matchAround(int r, int c) {
    final t = _typeAt(r, c);
    if (t == null) return false;
    int count(int dr, int dc) {
      var n = 0, y = r + dr, x = c + dc;
      while (_typeAt(y, x) == t) {
        n++;
        y += dr;
        x += dc;
      }
      return n;
    }

    if (1 + count(0, 1) + count(0, -1) >= 3) return true;
    if (1 + count(1, 0) + count(-1, 0) >= 3) return true;
    for (final (dr, dc) in const [(0, 0), (0, -1), (-1, 0), (-1, -1)]) {
      final y = r + dr, x = c + dc;
      if (_typeAt(y, x) == t &&
          _typeAt(y, x + 1) == t &&
          _typeAt(y + 1, x) == t &&
          _typeAt(y + 1, x + 1) == t) {
        return true;
      }
    }
    return false;
  }

  /// Would swapping a and b make a match (or fire a wild tile)?
  bool isValidMove(Cell a, Cell b) {
    if (!canSwap(a, b)) return false;
    if (at(a)!.isWild || at(b)!.isWild) return true;
    swap(a, b);
    final ok = _matchAround(a.$1, a.$2) || _matchAround(b.$1, b.$2);
    swap(a, b);
    return ok;
  }

  /// All valid moves.
  List<(Cell, Cell)> validMoves() {
    final moves = <(Cell, Cell)>[];
    for (var r = 0; r < rows; r++) {
      for (var c = 0; c < cols; c++) {
        for (final (dr, dc) in const [(0, 1), (1, 0)]) {
          final a = (r, c), b = (r + dr, c + dc);
          if (isValidMove(a, b)) moves.add((a, b));
        }
      }
    }
    return moves;
  }

  /// A valid move, or null if the board is stuck.
  (Cell, Cell)? findAnyMove() {
    for (var r = 0; r < rows; r++) {
      for (var c = 0; c < cols; c++) {
        for (final (dr, dc) in const [(0, 1), (1, 0)]) {
          final a = (r, c), b = (r + dr, c + dc);
          if (isValidMove(a, b)) return (a, b);
        }
      }
    }
    return null;
  }

  // ------------------------------------------------------------------ clearing
  /// Decide which cells clear and which specials get created (see header for the rules).
  ClearPlan planClear(Matches m, [List<Cell> pivots = const []]) {
    final runs = m.runs;
    final clear = <int>{},
        count = <int, int>{},
        used = <int>{},
        consumed = <int>{};
    final creates = <Create>[];
    for (final run in runs) {
      for (final (r, c) in run.cells) {
        final k = cellKey(r, c);
        clear.add(k);
        count[k] = (count[k] ?? 0) + 1;
      }
    }
    for (final sq in m.squares) {
      for (final (r, c) in sq) {
        clear.add(cellKey(r, c));
      }
    }
    final pivotKeys = {for (final (r, c) in pivots) cellKey(r, c)};
    Cell pivotIn(List<Cell> cells, Cell fallback) => cells.firstWhere(
      (p) => pivotKeys.contains(cellKey(p.$1, p.$2)),
      orElse: () => fallback,
    );
    Cell pivotOf(Run run) =>
        pivotIn(run.cells, run.cells[run.cells.length ~/ 2]);
    void consume(List<Cell> cells) {
      for (final (r, c) in cells) {
        consumed.add(cellKey(r, c));
      }
    }

    void add(Cell at, int type, Special special, int fromType) {
      final k = cellKey(at.$1, at.$2);
      if (used.contains(k)) return;
      creates.add(Create(at.$1, at.$2, type, special, fromType));
      used.add(k);
    }

    final sorted = [...runs]..sort((a, b) => b.cells.length - a.cells.length);
    for (final run in sorted) {
      if (run.cells.length < 5) continue;
      add(
        pivotOf(run),
        run.cells.length >= 6 ? kNova : kRainbow,
        Special.none,
        run.type,
      );
      consume(run.cells);
    }
    for (final MapEntry(key: k, value: n) in count.entries) {
      if (n < 2 || consumed.contains(k) || used.contains(k)) continue;
      final (r, c) = unkey(k);
      final type = g[r][c]!.type;
      add((r, c), type, Special.bomb, type);
      for (final run in runs) {
        if (run.cells.any((p) => cellKey(p.$1, p.$2) == k)) consume(run.cells);
      }
    }
    for (final run in runs) {
      if (run.cells.length != 4 ||
          run.cells.any((p) => consumed.contains(cellKey(p.$1, p.$2)))) {
        continue;
      }
      add(
        pivotOf(run),
        run.type,
        run.horizontal ? Special.h : Special.v,
        run.type,
      );
      consume(run.cells);
    }
    for (final sq in m.squares) {
      if (sq.any((p) => consumed.contains(cellKey(p.$1, p.$2)))) continue;
      final type = g[sq.first.$1][sq.first.$2]!.type;
      add(pivotIn(sq, sq.first), type, Special.flyer, type);
      consume(sq);
    }
    for (final cr in creates) {
      clear.remove(cellKey(cr.r, cr.c));
    }
    return ClearPlan(clear, creates);
  }

  int? _mostCommonType() {
    final counts = <int, int>{};
    for (final row in g) {
      for (final t in row) {
        if (t != null && t.isFruit) {
          counts[t.type] = (counts[t.type] ?? 0) + 1;
        }
      }
    }
    int? best;
    var bestN = -1;
    counts.forEach((t, n) {
      if (n > bestN) {
        best = t;
        bestN = n;
      }
    });
    return best;
  }

  /// Up to [n] random cells not already clearing; needed foods / obstacles first.
  List<Cell> _pickTargets(int n, Set<int> exclude) {
    final preferred = <Cell>[], others = <Cell>[];
    for (var r = 0; r < rows; r++) {
      for (var c = 0; c < cols; c++) {
        final t = g[r][c];
        if (!mask[r][c] || t == null || exclude.contains(cellKey(r, c))) {
          continue;
        }
        final wanted =
            preferTypes.contains(t.type) ||
            (preferObstacles && (t.isBlocker || ice[r][c] > 0));
        (wanted ? preferred : others).add((r, c));
      }
    }
    preferred.shuffle(rng);
    others.shuffle(rng);
    return [...preferred, ...others].take(n).toList();
  }

  /// Fire specials inside [clear] (chain reactions). Mutates [clear]; returns the blasts that fired.
  /// Blockers inside a blast are added to [clear] (they get hit).
  List<Blast> expandSpecials(
    Set<int> clear, {
    Set<int> protect = const {},
    Set<int>? fired,
  }) {
    fired ??= <int>{};
    final effects = <Blast>[];
    final queue = [...clear];
    void add(int y, int x) {
      if (!isCell(y, x)) return;
      final k = cellKey(y, x);
      if (!clear.contains(k) && !protect.contains(k)) {
        clear.add(k);
        queue.add(k);
      }
    }

    while (queue.isNotEmpty) {
      final k = queue.removeAt(0);
      if (fired.contains(k)) continue;
      final (r, c) = unkey(k);
      final t = g[r][c];
      if (t == null || t.isBlocker) continue;
      if (t.special == Special.h) {
        fired.add(k);
        effects.add(Blast(BlastKind.lineH, r, c));
        for (var x = 0; x < cols; x++) {
          add(r, x);
        }
      } else if (t.special == Special.v) {
        fired.add(k);
        effects.add(Blast(BlastKind.lineV, r, c));
        for (var y = 0; y < rows; y++) {
          add(y, c);
        }
      } else if (t.special == Special.bomb) {
        fired.add(k);
        effects.add(Blast(BlastKind.bomb, r, c));
        for (var y = r - 1; y <= r + 1; y++) {
          for (var x = c - 1; x <= c + 1; x++) {
            add(y, x);
          }
        }
      } else if (t.special == Special.flyer) {
        fired.add(k);
        final targets = _pickTargets(3, {...clear, ...protect});
        effects.add(Blast(BlastKind.flyer, r, c, targets));
        for (final (y, x) in targets) {
          add(y, x);
        }
      } else if (t.isRainbow) {
        fired.add(k);
        effects.add(Blast(BlastKind.rainbow, r, c));
        final tt = _mostCommonType();
        for (var y = 0; y < rows; y++) {
          for (var x = 0; x < cols; x++) {
            if (g[y][x]?.type == tt) add(y, x);
          }
        }
      } else if (t.isNova) {
        fired.add(k);
        effects.add(Blast(BlastKind.nova, r, c));
        for (var y = 0; y < rows; y++) {
          for (var x = 0; x < cols; x++) {
            add(y, x);
          }
        }
      }
    }
    return effects;
  }

  /// Blockers next to any clearing fruit get hit too (added to [clear]; each at most once per step).
  void addAdjacentHits(Set<int> clear) {
    final hits = <int>{};
    for (final k in clear) {
      final (r, c) = unkey(k);
      final t = g[r][c];
      if (t == null || t.isBlocker) continue;
      for (final (dr, dc) in const [(0, 1), (0, -1), (1, 0), (-1, 0)]) {
        final y = r + dr, x = c + dc;
        if (isCell(y, x) && (g[y][x]?.isBlocker ?? false)) {
          hits.add(cellKey(y, x));
        }
      }
    }
    clear.addAll(hits);
  }

  /// Swapping a wild tile with a neighbor:
  ///  rainbow + food -> clears that food everywhere; nova + anything or rainbow + rainbow -> whole board.
  /// Returns cells to clear, already-fired wild cells, and the blast to show.
  (Set<int>, Set<int>, Blast) wildClear(Cell a, Cell b) {
    final ta = at(a)!, tb = at(b)!;
    final clear = <int>{}, fired = <int>{};
    final wild = ta.isWild ? a : b;
    final other = ta.isWild ? b : a;
    final whole = ta.isNova || tb.isNova || (ta.isRainbow && tb.isRainbow);
    if (whole) {
      for (var r = 0; r < rows; r++) {
        for (var c = 0; c < cols; c++) {
          if (mask[r][c]) clear.add(cellKey(r, c));
        }
      }
      for (final p in [a, b]) {
        if (at(p)!.isWild) fired.add(cellKey(p.$1, p.$2));
      }
      return (clear, fired, Blast(BlastKind.nova, wild.$1, wild.$2));
    }
    final target = at(other)!.type;
    clear.add(cellKey(wild.$1, wild.$2));
    fired.add(cellKey(wild.$1, wild.$2));
    for (var r = 0; r < rows; r++) {
      for (var c = 0; c < cols; c++) {
        if (g[r][c]?.type == target) clear.add(cellKey(r, c));
      }
    }
    return (clear, fired, Blast(BlastKind.rainbow, wild.$1, wild.$2));
  }

  /// Apply a clear: fruits leave (and crack the ice under them), blockers lose one hit.
  ClearResult applyClear(Set<int> clear) {
    final res = ClearResult(<int, int>{}, <int>[], <(int, int, int)>[]);
    for (final k in clear) {
      final (r, c) = unkey(k);
      if (!isCell(r, c)) continue;
      final t = g[r][c];
      if (t == null) continue;
      if (t.isBlocker) {
        t.hp--;
        final destroyed = t.hp <= 0;
        res.blockerHits.add((r, c, t.type, destroyed));
        if (destroyed) {
          if (t.isMud) {
            res.mudDestroyed++;
          } else {
            res.wallsDestroyed++;
          }
          res.ids.add(t.id);
          g[r][c] = null;
        } else {
          res.damagedIds.add(t.id);
        }
        continue;
      }
      if (t.isFruit) res.counts[t.type] = (res.counts[t.type] ?? 0) + 1;
      res.ids.add(t.id);
      res.cells.add((r, c, t.type));
      g[r][c] = null;
      if (ice[r][c] > 0) {
        ice[r][c]--;
        res.iceHits.add((r, c, ice[r][c]));
        if (ice[r][c] == 0) res.iceCleared++;
      }
    }
    return res;
  }

  void applyCreates(List<Create> creates, Map<int, int> counts) {
    for (final cr in creates) {
      final t = g[cr.r][cr.c];
      if (t == null) continue;
      t.type = cr.type;
      t.special = cr.special;
      counts[cr.fromType] = (counts[cr.fromType] ?? 0) + 1;
    }
  }

  /// Rows of a column that hold fruits (board cells that are not blockers), top to bottom.
  List<int> _slots(int c) => [
    for (var r = 0; r < rows; r++)
      if (mask[r][c] && !(g[r][c]?.isBlocker ?? false)) r,
  ];

  /// Fruits fall to the lowest free slot (passing holes and blockers).
  void gravity() {
    for (var c = 0; c < cols; c++) {
      final slots = _slots(c);
      final tiles = [for (final r in slots) ?g[r][c]];
      final empties = slots.length - tiles.length;
      for (var i = 0; i < slots.length; i++) {
        g[slots[i]][c] = i < empties ? null : tiles[i - empties];
      }
    }
  }

  /// New fruits drop into the empty top slots.
  List<Spawn> refill() {
    final spawns = <Spawn>[];
    for (var c = 0; c < cols; c++) {
      final slots = _slots(c);
      final empty = [
        for (final r in slots)
          if (g[r][c] == null) r,
      ];
      for (var i = 0; i < empty.length; i++) {
        final t = Tile(_pick());
        g[empty[i]][c] = t;
        spawns.add(Spawn(t, i - empty.length));
      }
    }
    return spawns;
  }

  /// Mud grows: one mud turns a neighbouring plain fruit into mud. Returns the new mud cell.
  Cell? spreadMud() {
    final muds = <Cell>[];
    for (var r = 0; r < rows; r++) {
      for (var c = 0; c < cols; c++) {
        if (g[r][c]?.isMud ?? false) muds.add((r, c));
      }
    }
    muds.shuffle(rng);
    for (final (r, c) in muds) {
      final around = <Cell>[
        for (final (dr, dc) in const [(0, 1), (0, -1), (1, 0), (-1, 0)])
          if (isCell(r + dr, c + dc) &&
              (g[r + dr][c + dc]?.isFruit ?? false) &&
              g[r + dr][c + dc]!.special == Special.none)
            (r + dr, c + dc),
      ]..shuffle(rng);
      if (around.isEmpty) continue;
      final (y, x) = around.first;
      g[y][x]!
        ..type = kMud
        ..hp = 1;
      if (findAnyMove() == null) {
        // Never let mud lock the board: undo.
        g[y][x]!.type = _pick();
        return null;
      }
      return (y, x);
    }
    return null;
  }

  /// Rearrange movable tiles until there's no ready-made match and at least one move.
  bool shuffle() {
    final cells = <Cell>[];
    final tiles = <Tile>[];
    for (var r = 0; r < rows; r++) {
      for (var c = 0; c < cols; c++) {
        final t = g[r][c];
        if (mask[r][c] && t != null && !t.isBlocker) {
          cells.add((r, c));
          tiles.add(t);
        }
      }
    }
    for (var attempt = 0; attempt < 300; attempt++) {
      tiles.shuffle(rng);
      if (attempt > 100) {
        for (final t in tiles) {
          if (t.special == Special.none && t.isFruit) t.type = _pick();
        }
      }
      for (var i = 0; i < cells.length; i++) {
        g[cells[i].$1][cells[i].$2] = tiles[i];
      }
      if (!hasMatch && findAnyMove() != null) return true;
    }
    return false;
  }
}
