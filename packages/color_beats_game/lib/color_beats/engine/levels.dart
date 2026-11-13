import 'package:sk_core/core/content/lang.dart';
import 'package:sk_core/core/content/songs.dart';

import '../levels_data.g.dart';
import 'grid.dart';
import 'level_gen.dart';

/// One Color Beats level: clear [lines] lines, collect the gems hidden in the starting picture,
/// and/or reach [score] points. The 500 levels are made by tool/generate_levels.dart.
class BlockLevel {
  BlockLevel({required this.index, required this.data});

  /// Level number - 1 (keeps counting up forever; the content repeats after 500).
  final int index;
  final LevelData data;

  /// Lines to clear (0 = no line goal).
  int get lines => data.lines;

  /// Points to reach (0 = no score goal).
  int get score => data.score;

  /// Gems to collect per kind (index into [gemEmojis]); empty = no gem goal.
  late final List<int> gems = data.gems;

  /// Shape difficulty 0..2 (see [shapesForTier]).
  int get tier => data.tier;

  int get song => index % songs.length;

  /// Builds a fresh board for this level.
  Grid newGrid() => gridOf(data);
}

/// Number of designed levels.
int get designedLevelCount => levelData.length;

/// Level [i] (0-based). Never runs out: after the last designed level, levels 101–500 repeat
/// (the first 100 are the gentle introduction), while the level number keeps going up.
BlockLevel blockLevel(int i) {
  final n = levelData.length;
  final d = i < n ? levelData[i] : levelData[100 + (i - n) % (n - 100)];
  return BlockLevel(index: i, data: d);
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
  final parts = [
    if (lv.lines > 0) vi ? 'xóa ${lv.lines} hàng' : 'clear ${lv.lines} lines',
    if (gemParts.isNotEmpty)
      '${vi ? 'lấy' : 'get'} ${gemParts.join(vi ? ' và ' : ' and ')}',
    if (lv.score > 0) vi ? 'đạt ${lv.score} điểm' : 'score ${lv.score} points',
  ];
  final goal = parts.join(vi ? ' và ' : ' and ');
  return vi ? 'Xếp gạch để $goal nhé!' : 'Fit the blocks to $goal!';
}
