import 'package:sk_core/core/content/foods.dart';
import 'package:sk_core/core/content/lang.dart';
import 'package:sk_core/core/content/sentences.dart';
import 'package:sk_core/core/content/songs.dart';

import 'engine/level_gen.dart';
import 'levels_data.g.dart';

/// What the child must do in a level. Obstacle missions = clear all of them.
enum Mission { ice, walls, mud }

class SnackLevel {
  SnackLevel({
    required this.index,
    required this.goals,
    required this.moves,
    required this.song,
    required this.sentence,
    required this.customer,
    required this.types,
    required this.layout,
    required this.shape,
    required this.ice,
    required this.walls,
    required this.mud,
  });
  final int index, moves, song, sentence;
  final List<FoodGoal> goals;
  final String customer, shape;
  final List<int> types; // fruits on the board
  final List<String> layout;

  /// Starting obstacle counts (0 = not part of this level).
  final int ice, walls, mud;

  List<Mission> get missions => [
    if (ice > 0) Mission.ice,
    if (walls > 0) Mission.walls,
    if (mud > 0) Mission.mud,
  ];
}

/// Number of designed levels. Levels never run out: after 200, levels 101–200 repeat (the level number keeps going up).
int get designedLevelCount => levelData.length;

SnackLevel snackLevel(int i) {
  final LevelData d = i < levelData.length
      ? levelData[i]
      : levelData[100 + (i - levelData.length) % (levelData.length - 100)];
  return SnackLevel(
    index: i,
    goals: [for (final g in d.goals) FoodGoal(g[0], g[1])],
    moves: d.moves,
    song: i % songs.length,
    sentence: i % sentenceTemplates.length,
    customer: customers[i % customers.length],
    types: List.generate(d.nTypes, (t) => t),
    layout: d.layout,
    shape: d.shape,
    ice: d.iceCells,
    walls: d.wallCells,
    mud: d.mudCells,
  );
}

/// What the customer says at the start, e.g. "Hi! I need 8 strawberries. Please break 6 ice!"
String levelSentence(SnackLevel lv, Lang lang) {
  final parts = <String>[];
  if (lv.goals.isNotEmpty) parts.add(goalSentence(lv.goals, lang));
  final m = <String>[
    if (lv.ice > 0)
      lang == Lang.vi ? 'phá ${lv.ice} ô băng' : 'break ${lv.ice} ice',
    if (lv.walls > 0)
      lang == Lang.vi ? 'đập ${lv.walls} bức tường' : 'smash ${lv.walls} walls',
    if (lv.mud > 0) lang == Lang.vi ? 'dọn hết bùn' : 'clean up all the mud',
  ];
  if (m.isNotEmpty) {
    final joined = m.join(lang == Lang.vi ? ' và ' : ' and ');
    if (parts.isEmpty) {
      parts.add(
        lang == Lang.vi
            ? 'Xin chào! Bạn giúp tôi $joined nhé!'
            : 'Hi! Please help me $joined!',
      );
    } else {
      parts.add(
        lang == Lang.vi ? 'Bạn giúp tôi $joined nhé!' : 'Please $joined too!',
      );
    }
  }
  return parts.join(' ');
}
