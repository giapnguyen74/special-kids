import 'dart:math';

/// A cell position on the board.
typedef Cell = (int r, int c);

/// One block shape the child can place. [cells] are normalized (min row/col = 0).
class Piece {
  Piece(this.cells, this.color)
    : rows = cells.map((e) => e.$1).reduce(max) + 1,
      cols = cells.map((e) => e.$2).reduce(max) + 1;

  final List<Cell> cells;
  final int color;
  final int rows, cols;

  int get size => cells.length;

  /// Shape key (ignores color), e.g. for tests and logs.
  String get key => cells.map((e) => '${e.$1}${e.$2}').join(',');
}

/// Shapes grouped by difficulty tier. A tier includes all lower tiers.
/// Written as rows of '#' / '.' so they are easy to read.
const _tierShapes = <List<String>>[
  // tier 0: small, friendly shapes
  [
    '#',
    '##',
    '#|#',
    '###',
    '#|#|#',
    '##|##',
    '##|#.',
    '##|.#',
    '#.|##',
    '.#|##',
  ],
  // tier 1: classic 4-block shapes
  [
    '####',
    '#|#|#|#',
    '###|.#.',
    '.#.|###',
    '#.|##|#.',
    '.#|##|.#',
    '##.|.##',
    '.##|##.',
    '#.|#.|##',
    '.#|.#|##',
    '##|#.|#.',
    '##|.#|.#',
    '###|#..',
    '###|..#',
    '#..|###',
    '..#|###',
  ],
  // tier 2: big shapes
  [
    '#####',
    '#|#|#|#|#',
    '###|###|###',
    '###|#..|#..',
    '###|..#|..#',
    '#..|#..|###',
    '..#|..#|###',
    '##|##|##',
    '###|###',
  ],
];

List<Cell> parseShape(String s) {
  final rows = s.split('|');
  return [
    for (var r = 0; r < rows.length; r++)
      for (var c = 0; c < rows[r].length; c++)
        if (rows[r][c] == '#') (r, c),
  ];
}

/// All shapes up to and including [tier] (0..2).
List<List<Cell>> shapesForTier(int tier) => [
  for (var t = 0; t <= tier.clamp(0, _tierShapes.length - 1); t++)
    for (final s in _tierShapes[t]) parseShape(s),
];

/// Number of block colors (see the board painter).
const blockColors = 8;

/// Gem kinds hidden in blocks: clear the row or column to collect them.
const gemEmojis = ['💎', '⭐', '🎵'];

/// Result of placing a piece.
class PlaceResult {
  PlaceResult({
    required this.cells,
    required this.rows,
    required this.cols,
    required this.cleared,
    required this.gems,
    required this.points,
    required this.combo,
  });

  /// Cells the piece now covers.
  final List<Cell> cells;

  /// Full rows / columns that were cleared.
  final List<int> rows, cols;

  /// Every cell that was emptied by the clear, with the color it had (for effects).
  final Map<Cell, int> cleared;

  /// Gems collected: kind -> count.
  final Map<int, int> gems;
  final int points;

  /// Clearing streak (1 = first clear in a row of moves, 0 = no clear).
  final int combo;

  int get lines => rows.length + cols.length;
}

/// The 8x8 block board. Pure logic (no Flutter), so it is easy to test.
class Grid {
  Grid({this.size = 8}) : _cells = List.filled(size * size, -1);

  final int size;

  /// -1 = empty, otherwise a color index.
  final List<int> _cells;

  /// Gems sit inside filled cells.
  final Map<Cell, int> gems = {};

  int score = 0;

  /// Moves in a row that cleared at least one line.
  int streak = 0;

  int at(int r, int c) => _cells[r * size + c];
  bool isEmpty(int r, int c) => at(r, c) < 0;
  void set(int r, int c, int v) => _cells[r * size + c] = v;

  int get filled => _cells.where((v) => v >= 0).length;

  bool inside(int r, int c) => r >= 0 && c >= 0 && r < size && c < size;

  bool canPlace(Piece p, int r, int c) {
    for (final (dr, dc) in p.cells) {
      final rr = r + dr, cc = c + dc;
      if (!inside(rr, cc) || !isEmpty(rr, cc)) return false;
    }
    return true;
  }

  /// Every top-left position where [p] fits.
  Iterable<Cell> placements(Piece p) sync* {
    for (var r = 0; r <= size - p.rows; r++) {
      for (var c = 0; c <= size - p.cols; c++) {
        if (canPlace(p, r, c)) yield (r, c);
      }
    }
  }

  bool fits(Piece p) => placements(p).isNotEmpty;

  /// Rows and columns that would be full if [p] were placed at (r, c).
  (List<int>, List<int>) wouldClear(Piece p, int r, int c) {
    final mine = {for (final (dr, dc) in p.cells) (r + dr, c + dc)};
    bool full(int rr, int cc) => !isEmpty(rr, cc) || mine.contains((rr, cc));
    final rows =
        <int>{for (final (dr, _) in p.cells) r + dr}
            .where(
              (rr) =>
                  [for (var cc = 0; cc < size; cc++) cc]
                      .every((cc) => full(rr, cc)),
            )
            .toList()
          ..sort();
    final cols =
        <int>{for (final (_, dc) in p.cells) c + dc}
            .where(
              (cc) =>
                  [for (var rr = 0; rr < size; rr++) rr]
                      .every((rr) => full(rr, cc)),
            )
            .toList()
          ..sort();
    return (rows, cols);
  }

  /// Places [p] at (r, c) (must fit), clears full lines, scores.
  PlaceResult place(Piece p, int r, int c) {
    assert(canPlace(p, r, c));
    final placed = <Cell>[];
    for (final (dr, dc) in p.cells) {
      set(r + dr, c + dc, p.color);
      placed.add((r + dr, c + dc));
    }
    final fullRows = [
      for (var rr = 0; rr < size; rr++)
        if ([for (var cc = 0; cc < size; cc++) at(rr, cc)].every((v) => v >= 0))
          rr,
    ];
    final fullCols = [
      for (var cc = 0; cc < size; cc++)
        if ([for (var rr = 0; rr < size; rr++) at(rr, cc)].every((v) => v >= 0))
          cc,
    ];
    final cleared = <Cell, int>{};
    for (final rr in fullRows) {
      for (var cc = 0; cc < size; cc++) {
        cleared[(rr, cc)] = at(rr, cc);
      }
    }
    for (final cc in fullCols) {
      for (var rr = 0; rr < size; rr++) {
        cleared[(rr, cc)] = at(rr, cc);
      }
    }
    final got = _empty(cleared.keys);
    final lines = fullRows.length + fullCols.length;
    streak = lines > 0 ? streak + 1 : 0;
    // Points: 1 per block placed; lines are worth more together and in a streak.
    final points = p.size + lines * 10 * lines * max<int>(1, streak);
    score += points;
    return PlaceResult(
      cells: placed,
      rows: fullRows,
      cols: fullCols,
      cleared: cleared,
      gems: got,
      points: points,
      combo: lines > 0 ? streak : 0,
    );
  }

  Map<int, int> _empty(Iterable<Cell> cells) {
    final got = <int, int>{};
    for (final cell in cells) {
      set(cell.$1, cell.$2, -1);
      final g = gems.remove(cell);
      if (g != null) got[g] = (got[g] ?? 0) + 1;
    }
    return got;
  }

  /// Help after a challenge (or in calm mode): empties the [n] fullest rows.
  /// Gems in those rows are collected too (generous on purpose).
  PlaceResult clearFullest(int n) {
    final order = [for (var r = 0; r < size; r++) r]
      ..sort((a, b) => _rowCount(b).compareTo(_rowCount(a)));
    final rows = order.take(n).where((r) => _rowCount(r) > 0).toList()..sort();
    final cleared = <Cell, int>{
      for (final r in rows)
        for (var c = 0; c < size; c++)
          if (!isEmpty(r, c)) (r, c): at(r, c),
    };
    final got = _empty(cleared.keys);
    return PlaceResult(
      cells: const [],
      rows: rows,
      cols: const [],
      cleared: cleared,
      gems: got,
      points: 0,
      combo: 0,
    );
  }

  int _rowCount(int r) =>
      [for (var c = 0; c < size; c++) at(r, c)].where((v) => v >= 0).length;

  /// The most helpful placement for a hint: most lines cleared, then most neighbours touched.
  (int piece, int r, int c)? bestMove(List<Piece?> tray) {
    (int, int, int)? best;
    var bestScore = -1;
    for (var i = 0; i < tray.length; i++) {
      final p = tray[i];
      if (p == null) continue;
      for (final (r, c) in placements(p)) {
        final (rows, cols) = wouldClear(p, r, c);
        var s = (rows.length + cols.length) * 100;
        for (final (dr, dc) in p.cells) {
          for (final (nr, nc) in [
            (r + dr - 1, c + dc),
            (r + dr + 1, c + dc),
            (r + dr, c + dc - 1),
            (r + dr, c + dc + 1),
          ]) {
            if (!inside(nr, nc) || !isEmpty(nr, nc)) s++;
          }
        }
        if (s > bestScore) {
          bestScore = s;
          best = (i, r, c);
        }
      }
    }
    return best;
  }
}

/// Deals trays of 3 pieces. Every new tray has at least one piece that fits
/// (the child is never handed a tray that is stuck from the start).
class PieceDealer {
  PieceDealer({required this.tier, required this.rng, this.kind = true})
    : _shapes = shapesForTier(tier);

  final int tier;
  final Random rng;

  /// Kind dealing: two of the three pieces fit when possible (easier games).
  final bool kind;
  final List<List<Cell>> _shapes;

  Piece _random() {
    // Small shapes a bit more often so the board stays playable.
    final shape = _shapes[rng.nextInt(_shapes.length)];
    final alt = _shapes[rng.nextInt(_shapes.length)];
    final pick = alt.length < shape.length && rng.nextBool() ? alt : shape;
    return Piece(pick, rng.nextInt(blockColors));
  }

  List<Piece> deal(Grid g) {
    final need = kind ? 2 : 1;
    List<Piece> best = [_random(), _random(), _random()];
    var bestFit = best.where(g.fits).length;
    for (var tries = 0; tries < 40 && bestFit < need; tries++) {
      final t = [_random(), _random(), _random()];
      final f = t.where(g.fits).length;
      if (f > bestFit) {
        best = t;
        bestFit = f;
      }
    }
    if (bestFit == 0) {
      // Last resort: a single block always fits if any cell is empty.
      best[0] = Piece(const [(0, 0)], rng.nextInt(blockColors));
    }
    return best;
  }
}
