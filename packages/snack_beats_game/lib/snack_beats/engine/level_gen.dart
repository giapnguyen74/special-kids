// Level design + automatic difficulty calibration (pure Dart; used by tool/generate_levels.dart and tests).
//
// Each level = board shape + obstacles (layout) + food goals. Obstacle missions are implicit:
// if the layout has ice / walls / mud, the child must clear all of them.
// The number of moves is calibrated by a "typical child" robot: half of its moves aim at what the
// level needs (ice, walls, mud, goal fruits), the other half are random valid moves:
// moves = 80th percentile of moves the robot needed (+2), so most children can win.
import 'dart:math';

import 'board.dart';

/// One level (generated, stored in levels_data.g.dart).
class LevelData {
  const LevelData({
    required this.shape,
    required this.layout,
    required this.nTypes,
    required this.goals,
    required this.moves,
  });

  final String shape;

  /// Board layout ('.' hole, 'o' cell, 'i'/'I' ice, 'w' wall, 'W' rock, 'm' mud).
  final List<String> layout;

  /// Number of different fruits on the board (4..6).
  final int nTypes;

  /// Food goals as [food index, amount].
  final List<List<int>> goals;
  final int moves;

  int _count(String chars) =>
      layout.fold(0, (a, r) => a + r.split('').where(chars.contains).length);
  int get iceCells => _count('iI');
  int get wallCells => _count('wW');
  int get mudCells => _count('m');
}

/// Board shapes (7 columns; 7–8 rows). 'o' = cell, '.' = hole.
const boardShapes = <String, List<String>>{
  'square': [
    'ooooooo',
    'ooooooo',
    'ooooooo',
    'ooooooo',
    'ooooooo',
    'ooooooo',
    'ooooooo',
  ],
  'octagon': [
    '..ooo..',
    '.ooooo.',
    'ooooooo',
    'ooooooo',
    'ooooooo',
    '.ooooo.',
    '..ooo..',
  ],
  'cross': [
    '..ooo..',
    '..ooo..',
    'ooooooo',
    'ooooooo',
    'ooooooo',
    '..ooo..',
    '..ooo..',
  ],
  'heart': [
    '.oo.oo.',
    'ooooooo',
    'ooooooo',
    'ooooooo',
    '.ooooo.',
    '..ooo..',
    '...o...',
  ],
  'hourglass': [
    'ooooooo',
    '.ooooo.',
    '..ooo..',
    '..ooo..',
    '..ooo..',
    '.ooooo.',
    'ooooooo',
  ],
  'donut': [
    'ooooooo',
    'ooooooo',
    'oo...oo',
    'oo...oo',
    'oo...oo',
    'ooooooo',
    'ooooooo',
  ],
  'arch': [
    'ooooooo',
    'ooooooo',
    'ooooooo',
    'ooo.ooo',
    'ooo.ooo',
    'ooo.ooo',
    'ooo.ooo',
  ],
  'stairs': [
    'ooo....',
    'oooo...',
    'ooooo..',
    'oooooo.',
    'ooooooo',
    'ooooooo',
    'ooooooo',
  ],
  'butterfly': [
    'oo...oo',
    'ooo.ooo',
    'ooooooo',
    'ooooooo',
    'ooooooo',
    'ooo.ooo',
    'oo...oo',
  ],
  'castle': [
    'o.o.o.o',
    'ooooooo',
    'ooooooo',
    'ooooooo',
    'ooooooo',
    'ooooooo',
    'ooooooo',
  ],
  'tall': [
    'ooooooo',
    'ooooooo',
    'ooooooo',
    'ooooooo',
    'ooooooo',
    'ooooooo',
    'ooooooo',
    'ooooooo',
  ],
  'towers': [
    'ooo.ooo',
    'ooo.ooo',
    'ooo.ooo',
    'ooo.ooo',
    'ooo.ooo',
    'ooooooo',
    'ooooooo',
  ],
};

/// Shapes unlocked chapter by chapter (20 levels per chapter).
const _shapesByChapter = [
  ['square', 'octagon', 'cross', 'heart'],
  ['square', 'octagon', 'cross', 'heart', 'hourglass', 'donut'],
  [
    'square',
    'octagon',
    'cross',
    'heart',
    'hourglass',
    'donut',
    'arch',
    'stairs',
  ],
  [
    'square',
    'octagon',
    'cross',
    'heart',
    'hourglass',
    'donut',
    'arch',
    'stairs',
    'butterfly',
    'castle',
  ],
];

enum _Obs { ice, ice2, wall, rock, mud }

/// A level before move calibration.
class LevelPlan {
  LevelPlan(this.shape, this.layout, this.nTypes, this.goals);
  final String shape;
  final List<String> layout;
  final int nTypes;
  final List<List<int>> goals;
}

/// Deterministic design for level [index] (0-based). [ease] < 1 makes it easier.
LevelPlan designLevel(int index, {double ease = 1.0, int variant = 0}) {
  final n = index + 1;
  final ch = index ~/ 20, k = index % 20;
  final rng = Random(index * 9973 + 17 + variant * 104729);
  final relax = n % 5 == 0 && n > 5; // every 5th level is a gentle one
  final e = ease * (relax ? 0.6 : 1.0);

  // Shape
  final String shape;
  if (n <= 3) {
    shape = 'square';
  } else if (ch < _shapesByChapter.length) {
    final pool = _shapesByChapter[ch];
    shape = pool[(k + rng.nextInt(2)) % pool.length];
  } else {
    final all = boardShapes.keys.toList();
    shape = all[(index * 7 + rng.nextInt(all.length)) % all.length];
  }

  // Missions
  final obs = <_Obs, int>{};
  final foods = <int>[]; // amounts (food chosen later)
  final t = ((index - 100) / 100).clamp(0.0, 1.0); // late-game intensity
  int sc(num v) => max(1, (v * e).round());
  switch (ch) {
    case 0:
      if (k < 10) {
        foods.add(sc(8 + k));
      } else {
        foods
          ..add(sc(7 + (k - 10) ~/ 2))
          ..add(sc(7 + (k - 10) ~/ 2));
      }
    case 1:
      obs[_Obs.ice] = sc(6 + k ~/ 2);
      if (k >= 10) foods.add(sc(10));
    case 2:
      obs[_Obs.wall] = sc(4 + k ~/ 3);
      if (k < 10) foods.add(sc(10));
      if (k >= 10) obs[_Obs.ice] = sc(6);
    case 3:
      obs[_Obs.ice2] = sc(4 + k ~/ 4);
      if (k >= 6) obs[_Obs.rock] = sc(2 + k ~/ 6);
      if (k >= 14) foods.add(sc(10));
    case 4:
      obs[_Obs.mud] = sc(2 + k ~/ 7);
      if (k < 10) foods.add(sc(9));
      if (k >= 10) obs[_Obs.ice] = sc(6);
    default:
      const combos = [
        ['food', 'food'],
        ['ice'],
        ['wall'],
        ['mud', 'food'],
        ['ice', 'wall'],
        ['ice', 'mud'],
        ['wall', 'mud'],
        ['food', 'ice'],
        ['food', 'wall'],
        ['ice2', 'rock'],
        ['food', 'ice', 'wall'],
        ['ice', 'rock'],
      ];
      final combo = relax
          ? combos[rng.nextInt(3)]
          : combos[rng.nextInt(combos.length)];
      for (final m in combo) {
        switch (m) {
          case 'food':
            foods.add(sc(10 + 4 * t));
          case 'ice':
            obs[_Obs.ice] = sc(8 + 6 * t);
          case 'ice2':
            obs[_Obs.ice2] = sc(6 + 4 * t);
          case 'wall':
            obs[_Obs.wall] = sc(5 + 4 * t);
          case 'rock':
            obs[_Obs.rock] = sc(3 + 3 * t);
          case 'mud':
            obs[_Obs.mud] = sc(2 + 2 * t);
        }
      }
  }

  // Fruit kinds: fewer kinds = easier (more matches)
  var nTypes = n <= 8 ? 4 : (n <= 30 ? 5 : 6);
  if (relax ||
      obs.containsKey(_Obs.mud) ||
      shape == 'heart' ||
      shape == 'hourglass') {
    nTypes = min(nTypes, 5);
  }

  final layout = _placeObstacles(boardShapes[shape]!, obs, rng);
  final pickFoods = List.generate(nTypes, (i) => i)..shuffle(rng);
  final goals = [
    for (var i = 0; i < foods.length; i++) [pickFoods[i], foods[i]],
  ];
  return LevelPlan(shape, layout, nTypes, goals);
}

List<String> _placeObstacles(
  List<String> shape,
  Map<_Obs, int> obs,
  Random rng,
) {
  final rows = shape.length, cols = shape.first.length;
  final grid = [for (final r in shape) r.split('')];
  bool open(int r, int c) =>
      r >= 0 && r < rows && c >= 0 && c < cols && shape[r][c] != '.';
  // Only cells with room around them (>= 3 neighbouring cells), so the child can match next to them.
  final cells = <Cell>[
    for (var r = 0; r < rows; r++)
      for (var c = 0; c < cols; c++)
        if (grid[r][c] == 'o' &&
            [
                  open(r - 1, c),
                  open(r + 1, c),
                  open(r, c - 1),
                  open(r, c + 1),
                ].where((x) => x).length >=
                3)
          (r, c),
  ];
  final cr = (rows - 1) / 2, cc = (cols - 1) / 2;
  double dist(Cell p) => sqrt(pow(p.$1 - cr, 2) + pow(p.$2 - cc, 2));

  // Symmetric patterns: ordered candidate lists.
  List<Cell> pattern(int which) {
    final list = [...cells];
    switch (which % 7) {
      case 0: // bottom rows
        list.sort((a, b) => b.$1.compareTo(a.$1));
      case 1: // center
        list.sort((a, b) => dist(a).compareTo(dist(b)));
      case 2: // outer ring
        list.sort((a, b) => dist(b).compareTo(dist(a)));
      case 3: // checker, bottom first
        list.sort((a, b) {
          final ca = (a.$1 + a.$2).isEven ? 0 : 1,
              cb = (b.$1 + b.$2).isEven ? 0 : 1;
          return ca != cb ? ca - cb : b.$1.compareTo(a.$1);
        });
      case 4: // middle band
        list.sort((a, b) => (a.$1 - cr).abs().compareTo((b.$1 - cr).abs()));
      case 5: // columns 1 and 5 first
        int col(Cell p) => (p.$2 == 1 || p.$2 == cols - 2) ? 0 : 1;
        list.sort(
          (a, b) => col(a) != col(b) ? col(a) - col(b) : b.$1.compareTo(a.$1),
        );
      default: // diagonals
        int d(Cell p) => (p.$1 == p.$2 || p.$1 + p.$2 == cols - 1) ? 0 : 1;
        list.sort(
          (a, b) => d(a) != d(b) ? d(a) - d(b) : dist(a).compareTo(dist(b)),
        );
    }
    return list;
  }

  final maxBlockers = (cells.length * 0.3).floor();
  var blockers = 0;
  final order = [_Obs.ice, _Obs.ice2, _Obs.rock, _Obs.wall, _Obs.mud];
  for (final kind in order) {
    final want = obs[kind];
    if (want == null) continue;
    final isBlocker =
        kind == _Obs.wall || kind == _Obs.rock || kind == _Obs.mud;
    final ch = switch (kind) {
      _Obs.ice => 'i',
      _Obs.ice2 => 'I',
      _Obs.wall => 'w',
      _Obs.rock => 'W',
      _Obs.mud => 'm',
    };
    var placed = 0;
    final cand = pattern(rng.nextInt(7));
    for (final (r, c) in cand) {
      if (placed >= want) break;
      if (isBlocker && blockers >= maxBlockers) break;
      for (final (y, x) in [(r, c), (r, cols - 1 - c)]) {
        if (placed >= want) break;
        if (grid[y][x] != 'o') continue;
        // Keep the top row free of blockers so play never looks stuck at the start.
        if (isBlocker && y == 0) continue;
        grid[y][x] = ch;
        placed++;
        if (isBlocker) blockers++;
      }
    }
  }
  return [for (final r in grid) r.join()];
}

/// Plays one game with random valid moves. Returns moves needed, or [maxMoves] + 1 if not finished.
int simulate(LevelPlan plan, Random rng, {int maxMoves = 70}) {
  final b = Board.fromLayout(
    plan.layout,
    types: List.generate(plan.nTypes, (i) => i),
    rng: rng,
  );
  final left = {for (final g in plan.goals) g[0]: g[1]};
  bool done() =>
      left.values.every((v) => v <= 0) &&
      b.iceLeft == 0 &&
      b.wallsLeft == 0 &&
      b.mudLeft == 0;
  void tally(ClearResult res) {
    res.counts.forEach((t, n) {
      if (left.containsKey(t)) left[t] = left[t]! - n;
    });
  }

  for (var move = 1; move <= maxMoves; move++) {
    b.preferTypes = {
      for (final e in left.entries)
        if (e.value > 0) e.key,
    };
    b.preferObstacles = b.iceLeft + b.wallsLeft + b.mudLeft > 0;
    final moves = b.validMoves();
    if (moves.isEmpty) {
      b.shuffle();
      continue;
    }
    final (a, c) = rng.nextBool()
        ? moves[rng.nextInt(moves.length)]
        : _bestMove(b, moves, left);
    b.swap(a, c);
    var mudCleared = 0;
    var pivots = <Cell>[a, c];
    if (b.at(a)!.isWild || b.at(c)!.isWild) {
      final (clear, fired, _) = b.wildClear(a, c);
      b.expandSpecials(clear, fired: fired);
      b.addAdjacentHits(clear);
      final res = b.applyClear(clear);
      tally(res);
      mudCleared += res.mudDestroyed;
      b.gravity();
      b.refill();
      pivots = [];
    }
    for (var guard = 0; guard < 100; guard++) {
      final found = b.findMatches();
      if (found.isEmpty) break;
      final p = b.planClear(found, pivots);
      final protect = {for (final cr in p.creates) cellKey(cr.r, cr.c)};
      b.expandSpecials(p.clear, protect: protect);
      b.addAdjacentHits(p.clear);
      final res = b.applyClear(p.clear);
      b.applyCreates(p.creates, res.counts);
      tally(res);
      mudCleared += res.mudDestroyed;
      b.gravity();
      b.refill();
      pivots = [];
    }
    if (b.mudLeft > 0 && mudCleared == 0) b.spreadMud();
    if (b.findAnyMove() == null) b.shuffle();
    if (done()) return move;
  }
  return maxMoves + 1;
}

/// The move whose match touches the most needed things (ice, blockers, goal fruits).
(Cell, Cell) _bestMove(Board b, List<(Cell, Cell)> moves, Map<int, int> left) {
  var best = moves.first;
  var bestScore = -1;
  for (final m in moves) {
    final (a, c) = m;
    if (b.at(a)!.isWild || b.at(c)!.isWild) return m;
    b.swap(a, c);
    final cells = <Cell>{..._matchCells(b, a), ..._matchCells(b, c)};
    var score = cells.length;
    for (final (r, col) in cells) {
      if (b.ice[r][col] > 0) score += 4;
      final t = b.g[r][col];
      if (t != null && (left[t.type] ?? 0) > 0) score += 2;
      for (final (dr, dc) in const [(0, 1), (0, -1), (1, 0), (-1, 0)]) {
        if (b.isCell(r + dr, col + dc) &&
            (b.g[r + dr][col + dc]?.isBlocker ?? false)) {
          score += 4;
        }
      }
    }
    b.swap(a, c);
    if (score > bestScore) {
      bestScore = score;
      best = m;
    }
  }
  return best;
}

/// Cells of the line(s) through [p] made of the same fruit (length >= 3).
List<Cell> _matchCells(Board b, Cell p) {
  final t = b.g[p.$1][p.$2];
  if (t == null || !t.isFruit) return const [];
  final out = <Cell>[];
  for (final (dr, dc) in const [(0, 1), (1, 0)]) {
    final line = <Cell>[p];
    for (final s in const [1, -1]) {
      var y = p.$1 + dr * s, x = p.$2 + dc * s;
      while (b.isCell(y, x) && b.g[y][x]?.type == t.type) {
        line.add((y, x));
        y += dr * s;
        x += dc * s;
      }
    }
    if (line.length >= 3) out.addAll(line);
  }
  return out;
}

/// Designs level [index] and sets its moves from robot play-tests (eases the level if too hard).
LevelData calibrate(int index, {int games = 16}) {
  for (final (variant, ease) in const [
    (0, 1.0),
    (1, 1.0),
    (2, 1.0),
    (0, 0.85),
    (1, 0.85),
    (0, 0.7),
    (1, 0.7),
    (0, 0.55),
    (0, 0.4),
    (3, 0.4),
  ]) {
    final plan = designLevel(index, ease: ease, variant: variant);
    final rng = Random(index * 31 + 7);
    final needed = <int>[];
    try {
      for (var g = 0; g < games; g++) {
        needed.add(simulate(plan, rng));
      }
    } on StateError {
      continue; // board could not be created with these obstacles: ease off
    }
    needed.sort();
    final p80 =
        needed[(needed.length * 0.8).floor().clamp(0, needed.length - 1)];
    if (p80 <= 40) {
      return LevelData(
        shape: plan.shape,
        layout: plan.layout,
        nTypes: plan.nTypes,
        goals: plan.goals,
        moves: (p80 + 2).clamp(12, 45),
      );
    }
  }
  throw StateError('level ${index + 1} could not be calibrated');
}
