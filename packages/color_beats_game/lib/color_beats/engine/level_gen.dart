// Level generator for Color Beats (pure Dart: used by tool/generate_levels.dart and tests).
//
// Every level = a starting picture made of blocks (heart, pyramid, smiley, towers, …, mirrored,
// thinned, colored in different ways) + a goal (clear lines / collect gems / reach a score, or a mix)
// + a set of shapes (small, classic, big). A play-test robot checks each level and makes the goal
// smaller until enough robot games win without help.
import 'dart:math';

import 'grid.dart';

/// A designed level as stored in levels_data.g.dart.
///
/// [board] = 8 rows of 8 chars: '.' empty, '0'..'7' block color, 'a' 'b' 'c' gem block (gem kind 0..2).
/// Gem goal = every gem on the board.
class LevelData {
  const LevelData({
    required this.tier,
    required this.lines,
    required this.score,
    required this.board,
    this.picture = '',
  });
  final int tier, lines, score;
  final List<String> board;

  /// Name of the starting picture (for QA and variety statistics).
  final String picture;

  List<int> get gems {
    final n = [0, 0, 0];
    for (final row in board) {
      for (final ch in row.split('')) {
        final k = 'abc'.indexOf(ch);
        if (k >= 0) n[k]++;
      }
    }
    while (n.isNotEmpty && n.last == 0) {
      n.removeLast();
    }
    return n;
  }

  /// Same level? (used to make sure all levels are different)
  String get signature => '$tier|$lines|$score|${board.join('/')}';
}

/// Starting pictures ('#' = block). Never fills a whole row or column (checked when generated).
const pictures = <String, List<String>>{
  'rubble': [], // random rows of rubble at the bottom (made in code)
  'heart': [
    '........',
    '........',
    '.##.##..',
    '#######.',
    '#######.',
    '.#####..',
    '..###...',
    '...#....',
  ],
  'pyramid': [
    '........',
    '........',
    '........',
    '........',
    '...##...',
    '..####..',
    '.######.',
    '.######.',
  ],
  'smiley': [
    '........',
    '........',
    '.##..##.',
    '.##..##.',
    '........',
    '#......#',
    '.#....#.',
    '..####..',
  ],
  'towers': [
    '........',
    '........',
    '#......#',
    '#......#',
    '##....##',
    '##....##',
    '###..###',
    '###..###',
  ],
  'stairs': [
    '........',
    '........',
    '.......#',
    '......##',
    '.....###',
    '....####',
    '...#####',
    '..######',
  ],
  'diamond': [
    '........',
    '...#....',
    '..###...',
    '.#####..',
    '#######.',
    '.#####..',
    '..###...',
    '...#....',
  ],
  'cross': [
    '........',
    '...##...',
    '...##...',
    '.######.',
    '.######.',
    '...##...',
    '...##...',
    '........',
  ],
  'frame': [
    '........',
    '.######.',
    '.#....#.',
    '.#....#.',
    '.#....#.',
    '.#....#.',
    '.######.',
    '........',
  ],
  'checker': [
    '........',
    '........',
    '........',
    '#.#.#.#.',
    '.#.#.#.#',
    '#.#.#.#.',
    '.#.#.#.#',
    '#.#.#.#.',
  ],
  'arrow': [
    '........',
    '...#....',
    '..###...',
    '.#####..',
    '#######.',
    '..###...',
    '..###...',
    '..###...',
  ],
  'house': [
    '........',
    '...##...',
    '..####..',
    '.######.',
    '.##..##.',
    '.##..##.',
    '.##..##.',
    '.######.',
  ],
  'tree': [
    '...#....',
    '..###...',
    '.#####..',
    '..###...',
    '.#####..',
    '#######.',
    '...#....',
    '...#....',
  ],
  'cup': [
    '........',
    '........',
    '#......#',
    '##....##',
    '.#....#.',
    '.##..##.',
    '..####..',
    '...##...',
  ],
  'zigzag': [
    '........',
    '........',
    '##......',
    '.##.....',
    '..##..##',
    '...####.',
    '....##..',
    '........',
  ],
  'corners': [
    '###..###',
    '##....##',
    '#......#',
    '........',
    '........',
    '#......#',
    '##....##',
    '###..###',
  ],
  'stripes': [
    '........',
    '........',
    '######..',
    '........',
    '..######',
    '........',
    '######..',
    '........',
  ],
  'columns': [
    '........',
    '........',
    '.#.#.#..',
    '.#.#.#..',
    '.#.#.#.#',
    '.#.#.#.#',
    '##.#.#.#',
    '##.#.#.#',
  ],
  'star': [
    '...#....',
    '...#....',
    '#######.',
    '.#####..',
    '..###...',
    '.##.##..',
    '.#...#..',
    '........',
  ],
  'robot': [
    '........',
    '.######.',
    '.#.##.#.',
    '.######.',
    '..#..#..',
    '.######.',
    '.#.##.#.',
    '.#....#.',
  ],
  'fish': [
    '........',
    '........',
    '..####..',
    '.######.',
    '##.####.',
    '.######.',
    '..####..',
    '........',
  ],
  'note': [
    '........',
    '...####.',
    '...#..#.',
    '...#..#.',
    '...#..#.',
    '.###.##.',
    '####.##.',
    '.##.....',
  ],
  'wave': [
    '........',
    '........',
    '........',
    '##....##',
    '###..###',
    '.######.',
    '..####..',
    '........',
  ],
  'island': [
    '........',
    '........',
    '........',
    '..####..',
    '.######.',
    '.######.',
    '..####..',
    '........',
  ],
};

/// Pictures unlocked over time: one new picture every ~20 levels; the first ones are simple.
const _pictureOrder = [
  'rubble',
  'pyramid',
  'heart',
  'stairs',
  'island',
  'smiley',
  'towers',
  'wave',
  'cross',
  'diamond',
  'cup',
  'frame',
  'arrow',
  'zigzag',
  'checker',
  'house',
  'tree',
  'fish',
  'corners',
  'stripes',
  'columns',
  'star',
  'note',
  'robot',
];

enum GoalKind { lines, gems, linesGems, score, scoreGems }

/// Builds candidate [attempt] for level [i]; higher attempts are easier.
LevelData generateLevel(int i, int attempt) {
  final rng = Random(91 * i + 7);
  final easy = i > 0 && (i + 1) % 5 == 0; // every 5th level is an easy one
  final chapter = i ~/ 25; // 20 chapters of 25 levels

  // Shapes: small ones first, then classic 4-block shapes, then big ones sometimes.
  final tier = i < 8 ? 0 : (easy || i < 60 ? 1 : (rng.nextInt(3) == 0 ? 2 : 1));

  // Starting picture.
  final unlocked = min(_pictureOrder.length, 2 + i ~/ 20);
  // Half the time one of the newest pictures, so new ones show up often.
  final pic = i < 3
      ? 'rubble'
      : _pictureOrder[rng.nextBool()
            ? max(0, unlocked - 1 - rng.nextInt(min(4, unlocked)))
            : rng.nextInt(unlocked)];

  // Goal kind.
  final kinds = <GoalKind>[
    GoalKind.lines,
    if (i >= 8) GoalKind.gems,
    if (i >= 20) GoalKind.linesGems,
    if (i >= 35) GoalKind.score,
    if (i >= 60) GoalKind.scoreGems,
  ];
  final kind = i < 8 ? GoalKind.lines : kinds[rng.nextInt(kinds.length)];
  final gemKinds = switch (kind) {
    GoalKind.gems ||
    GoalKind.linesGems ||
    GoalKind.scoreGems => 1 + rng.nextInt(min(3, 1 + chapter ~/ 3)),
    _ => 0,
  };

  // Difficulty grows slowly within the game, drops on easy levels; each attempt makes it easier.
  final level = (easy ? 0.35 : 1.0) * min(1.0, 0.25 + i / 300) - attempt * 0.12;
  final d = level.clamp(0.0, 1.0);

  // Board: picture cells (thinned on easier levels), random flip, colors.
  final cells = <Cell>{};
  if (pic == 'rubble') {
    final rows = i < 3 ? 0 : 1 + (d * 3).round();
    for (var k = 0; k < rows; k++) {
      final cols = [for (var c = 0; c < 8; c++) c]..shuffle(rng);
      for (final c in cols.take(3 + rng.nextInt(3))) {
        cells.add((7 - k, c));
      }
    }
  } else {
    final keep =
        0.75 +
        0.25 * d; // easier = fewer blocks (the picture stays recognizable)
    final art = pictures[pic]!;
    // Pictures with a clear top and bottom are only mirrored left-right.
    const anyWay = {
      'stairs',
      'zigzag',
      'wave',
      'corners',
      'stripes',
      'columns',
      'checker',
      'cross',
      'diamond',
      'frame',
      'island',
    };
    final flipH = rng.nextBool();
    final flipV = anyWay.contains(pic) && rng.nextInt(3) == 0;
    for (var r = 0; r < 8; r++) {
      for (var c = 0; c < 8; c++) {
        if (art[r][c] != '#') continue;
        if (rng.nextDouble() > keep) continue;
        cells.add((flipV ? 7 - r : r, flipH ? 7 - c : c));
      }
    }
  }
  // Never a full row or column at the start.
  for (var r = 0; r < 8; r++) {
    if ([for (var c = 0; c < 8; c++) (r, c)].every(cells.contains)) {
      cells.remove((r, rng.nextInt(8)));
    }
  }
  for (var c = 0; c < 8; c++) {
    if ([for (var r = 0; r < 8; r++) (r, c)].every(cells.contains)) {
      cells.remove((rng.nextInt(8), c));
    }
  }

  final colorMode = const [
    0,
    0,
    1,
    1,
    2,
    3,
  ][rng.nextInt(6)]; // 0 one color, 1 rows, 2 columns, 3 mixed
  final base = rng.nextInt(blockColors);
  int colorOf(Cell e) => switch (colorMode) {
    0 => base,
    1 => (base + e.$1) % blockColors,
    2 => (base + e.$2) % blockColors,
    _ => rng.nextInt(blockColors),
  };
  final board = [for (var r = 0; r < 8; r++) List.generate(8, (c) => '.')];
  for (final e in cells) {
    board[e.$1][e.$2] = '${colorOf(e)}';
  }

  // Gems: on picture blocks (or empty cells if there are too few blocks).
  if (gemKinds > 0) {
    final perKind = max(
      1,
      (2 + d * 3 + rng.nextInt(2)).round() - (gemKinds - 1),
    );
    final spots = cells.toList()..shuffle(rng);
    final empties = [
      for (var r = 2; r < 8; r++)
        for (var c = 0; c < 8; c++)
          if (!cells.contains((r, c))) (r, c),
    ]..shuffle(rng);
    final pool = [...spots, ...empties];
    var p = 0;
    for (var k = 0; k < gemKinds; k++) {
      for (var n = 0; n < perKind && p < pool.length; n++, p++) {
        final e = pool[p];
        board[e.$1][e.$2] = 'abc'[k];
      }
    }
    // Gems placed on empty cells must not complete a line either.
    for (var r = 0; r < 8; r++) {
      if (!board[r].contains('.')) board[r][rng.nextInt(8)] = '.';
    }
    for (var c = 0; c < 8; c++) {
      if (![for (var r = 0; r < 8; r++) board[r][c]].contains('.')) {
        board[rng.nextInt(8)][c] = '.';
      }
    }
  }

  final lines = switch (kind) {
    GoalKind.lines => max(2, (3 + d * 9 + rng.nextInt(3)).round()),
    GoalKind.linesGems => max(1, (2 + d * 5 + rng.nextInt(2)).round()),
    _ => 0,
  };
  final score = switch (kind) {
    GoalKind.score => max(
      60,
      ((120 + d * 380 + rng.nextInt(60)) / 10).round() * 10,
    ),
    GoalKind.scoreGems => max(
      40,
      ((80 + d * 220 + rng.nextInt(40)) / 10).round() * 10,
    ),
    _ => 0,
  };
  return LevelData(
    tier: tier,
    lines: lines,
    score: score,
    board: [for (final row in board) row.join()],
    picture: pic,
  );
}

/// Builds the playable grid for a level.
Grid gridOf(LevelData d) {
  final g = Grid();
  for (var r = 0; r < 8; r++) {
    for (var c = 0; c < 8; c++) {
      final ch = d.board[r][c];
      if (ch == '.') continue;
      final k = 'abc'.indexOf(ch);
      if (k >= 0) {
        g.set(r, c, blockColors); // gem block
        g.gems[(r, c)] = k;
      } else {
        g.set(r, c, int.parse(ch));
      }
    }
  }
  return g;
}

/// Robot plays [d] once (hint move every time, like a careful child with help).
/// [rescues] = challenge help allowed. Returns true if it reaches the goal.
bool robotWins(LevelData d, int seed, {int rescues = 0}) {
  final g = gridOf(d);
  final dealer = PieceDealer(tier: d.tier, rng: Random(seed));
  var lines = d.lines;
  final gems = [...d.gems];
  var help = rescues;
  var tray = <Piece?>[...dealer.deal(g)];
  bool done() => lines == 0 && gems.every((x) => x == 0) && g.score >= d.score;
  void take(Map<int, int> got) =>
      got.forEach((k, v) => gems[k] = max(0, gems[k] - v));
  for (var step = 0; step < 300; step++) {
    final m = g.bestMove(tray);
    if (m == null) {
      if (help == 0) return false;
      help--;
      take(g.clearFullest(3).gems);
      tray = [...dealer.deal(g)];
      continue;
    }
    final r = g.place(tray[m.$1]!, m.$2, m.$3);
    tray[m.$1] = null;
    lines = max(0, lines - r.lines);
    take(r.gems);
    if (done()) return true;
    if (tray.every((p) => p == null)) tray = [...dealer.deal(g)];
  }
  return false;
}

/// Share of robot games won without help that a level must reach (early levels: almost all).
double targetWinRate(int i) {
  final easy = i > 0 && (i + 1) % 5 == 0;
  if (easy || i < 20) return 0.9;
  return max(0.6, 0.85 - i / 2000);
}

/// Picks the hardest candidate for level [i] that the robot still wins often enough,
/// and that is different from every level made so far ([seen] signatures).
LevelData calibrate(int i, Set<String> seen, {int games = 10}) {
  LevelData? last;
  for (var attempt = 0; attempt < 12; attempt++) {
    final d = generateLevel(i, attempt);
    last = d;
    if (seen.contains(d.signature)) continue;
    var wins = 0;
    for (var s = 0; s < games; s++) {
      if (robotWins(d, i * 1000 + s)) wins++;
    }
    if (wins / games >= targetWinRate(i)) return d;
  }
  // Fallback: the easiest candidate, made unique if needed.
  var d = last!;
  var bump = 0;
  while (seen.contains(d.signature)) {
    bump++;
    d = LevelData(
      tier: d.tier,
      lines: d.lines + bump,
      score: d.score,
      board: d.board,
      picture: d.picture,
    );
  }
  return d;
}
