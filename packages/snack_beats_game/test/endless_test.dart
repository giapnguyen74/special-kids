import 'package:flutter_test/flutter_test.dart';
import 'package:snack_beats_game/snack_beats/levels.dart';
import 'package:snack_beats_game/snack_beats/levels_data.g.dart';

void main() {
  test('levels never run out: after 200, levels 101-200 repeat and the number keeps going', () {
    expect(designedLevelCount, 200);
    expect(snackLevel(200).layout, levelData[100].layout);
    expect(snackLevel(299).moves, levelData[199].moves);
    expect(snackLevel(300).layout, levelData[100].layout);
    final far = snackLevel(54321);
    expect(far.index, 54321);
    expect(far.goals, isNotEmpty);
  });
}
