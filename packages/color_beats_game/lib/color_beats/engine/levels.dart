import 'dart:math';

import 'package:sk_core/core/content/lang.dart';
import 'package:sk_core/core/content/songs.dart';

import 'grid.dart';

/// One Color Beats level: clear [lines] lines and/or collect gems hidden in starting blocks.
///
/// Levels are made from the index (no data file): every level is the same for every child,
/// so parents and helpers can talk about "level 7".
class BlockLevel {
  BlockLevel({
    required this.index,
    required this.lines,
    required this.gems,
    required this.tier,
    required this.start,
    required this.startGems,
  });

  final int index;

  /// Lines to clear (0 = no line goal).
  final int lines;

  /// Gems to collect per kind (index into [gemEmojis]); empty = no gem goal.
  final List<int> gems;

  /// Shape difficulty 0..2 (see [shapesForTier]).
  final int tier;

  /// Starting blocks: cell -> color.
  final Map<Cell, int> start;

  /// Gems inside starting blocks: cell -> gem kind.
  final Map<Cell, int> startGems;

  int get song => index % songs.length;

  /// Builds a fresh board for this level.
  Grid newGrid() {
    final g = Grid();
    for (final MapEntry(key: (r, c), value: color) in start.entries) {
      g.set(r, c, color);
    }
    g.gems.addAll(startGems);
    return g;
  }
}

/// Level [i] (0-based). Gentle start, then new things one at a time:
///   1–5   clear a few lines with small shapes
///   6+    classic 4-block shapes; gems appear (one kind, then two, then three)
///   16+   big shapes now and then; every 5th level is an easy one.
BlockLevel blockLevel(int i) {
  final rng = Random(1000 + i * 7919);
  final easy = i > 0 && (i + 1) % 5 == 0;
  final tier = i < 5 ? 0 : (i < 15 || easy ? 1 : 2);
  final gemKinds = i < 5 || easy ? 0 : min(3, 1 + (i - 5) ~/ 6);
  final lines = gemKinds == 0
      ? (easy ? 3 : min(3 + i ~/ 2, 12))
      : (i.isEven ? min(2 + i ~/ 6, 8) : 0);

  // Starting blocks: a few scattered rows of rubble at the bottom, never a full line.
  final start = <Cell, int>{};
  final rubbleRows = i < 3 ? 0 : min(1 + i ~/ 8, 4);
  for (var k = 0; k < rubbleRows; k++) {
    final r = 7 - k;
    final want = 3 + rng.nextInt(3); // 3..5 of 8
    final cols = [for (var c = 0; c < 8; c++) c]..shuffle(rng);
    for (final c in cols.take(want)) {
      start[(r, c)] = rng.nextInt(blockColors);
    }
  }
  // Gem blocks: on top of the rubble (or anywhere in the lower half), never completing a line.
  final startGems = <Cell, int>{};
  final gems = <int>[];
  for (var kind = 0; kind < gemKinds; kind++) {
    final n = min(2 + i ~/ 10 + rng.nextInt(2), 5);
    var placed = 0;
    for (var tries = 0; tries < 200 && placed < n; tries++) {
      final cell = (3 + rng.nextInt(5), rng.nextInt(8));
      if (start.containsKey(cell)) continue;
      final rowCount = start.keys.where((e) => e.$1 == cell.$1).length;
      final colCount = start.keys.where((e) => e.$2 == cell.$2).length;
      if (rowCount >= 6 || colCount >= 6) continue;
      start[cell] = blockColors; // gem blocks use the special "gem" color
      startGems[cell] = kind;
      placed++;
    }
    gems.add(placed);
  }
  return BlockLevel(
    index: i,
    lines: lines,
    gems: gems,
    tier: tier,
    start: start,
    startGems: startGems,
  );
}

/// What the game says before the level starts.
String levelSentence(BlockLevel lv, Lang lang) {
  final vi = lang == Lang.vi;
  // "get 3 diamonds and 3 stars": the verb only once.
  final gemParts = <String>[
    for (var k = 0; k < lv.gems.length; k++)
      if (lv.gems[k] > 0)
        vi
            ? '${lv.gems[k]} ${const ['viên kim cương', 'ngôi sao', 'nốt nhạc'][k]}'
            : '${lv.gems[k]} ${const ['diamonds', 'stars', 'music notes'][k]}',
  ];
  final gems = gemParts.isEmpty
      ? ''
      : '${vi ? 'lấy' : 'get'} ${gemParts.join(vi ? ' và ' : ' and ')}';
  final parts = [
    if (lv.lines > 0) vi ? 'xóa ${lv.lines} hàng' : 'clear ${lv.lines} lines',
    if (gems.isNotEmpty) gems,
  ];
  final goal = parts.join(vi ? ' và ' : ' and ');
  return vi ? 'Xếp gạch để $goal nhé!' : "Fit the blocks to $goal!";
}
