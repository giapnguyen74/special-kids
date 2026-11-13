import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:color_beats_game/color_beats/engine/grid.dart';
import 'package:color_beats_game/color_beats/engine/level_gen.dart';
import 'package:color_beats_game/color_beats/engine/levels.dart';
import 'package:color_beats_game/color_beats/levels_data.g.dart';

Piece shape(String s, [int color = 0]) => Piece(parseShape(s), color);

void main() {
  test('pieces are normalized and sized', () {
    final p = shape('.#|##');
    expect(p.rows, 2);
    expect(p.cols, 2);
    expect(p.size, 3);
  });

  test('a full row and a full column clear together', () {
    final g = Grid();
    for (var c = 0; c < 7; c++) {
      g.set(0, c, 1);
    }
    for (var r = 1; r < 8; r++) {
      g.set(r, 7, 2);
    }
    g.gems[(3, 7)] = 1;
    final res = g.place(shape('#'), 0, 7);
    expect(res.rows, [0]);
    expect(res.cols, [7]);
    expect(res.lines, 2);
    expect(res.gems, {1: 1});
    expect(g.filled, 0);
    expect(res.points, greaterThan(20));
  });

  test('cannot place outside or on top of blocks', () {
    final g = Grid()..set(2, 2, 0);
    final p = shape('##');
    expect(g.canPlace(p, 0, 7), isFalse);
    expect(g.canPlace(p, 2, 1), isFalse);
    expect(g.canPlace(p, 2, 3), isTrue);
  });

  test('wouldClear predicts the clear', () {
    final g = Grid();
    for (var c = 0; c < 6; c++) {
      g.set(4, c, 3);
    }
    final (rows, cols) = g.wouldClear(shape('##'), 4, 6);
    expect(rows, [4]);
    expect(cols, isEmpty);
  });

  test('streak grows only with consecutive clears', () {
    final g = Grid();
    for (var c = 0; c < 7; c++) {
      g.set(0, c, 1);
      g.set(1, c, 1);
    }
    expect(g.place(shape('#'), 0, 7).combo, 1);
    expect(g.place(shape('#'), 1, 7).combo, 2);
    expect(g.place(shape('#'), 5, 5).combo, 0);
  });

  test('every dealt tray has a piece that fits', () {
    final rng = Random(3);
    for (var trial = 0; trial < 200; trial++) {
      final g = Grid();
      // Random clutter, at most 60 blocks.
      for (var k = 0; k < rng.nextInt(60); k++) {
        g.set(rng.nextInt(8), rng.nextInt(8), 0);
      }
      if (g.filled == 64) continue;
      final tray = PieceDealer(tier: 2, rng: rng).deal(g);
      expect(tray.any(g.fits), isTrue);
    }
  });

  test('rescue empties the fullest rows', () {
    final g = Grid();
    for (var c = 0; c < 7; c++) {
      g.set(5, c, 1);
    }
    for (var c = 0; c < 3; c++) {
      g.set(2, c, 1);
    }
    g.set(7, 0, 1);
    final res = g.clearFullest(2);
    expect(res.rows, [2, 5]);
    expect(g.filled, 1);
  });

  test(
    '500 different levels; no full line at the start; every level has a goal',
    () {
      expect(levelData, hasLength(500));
      expect(levelData.map((d) => d.signature).toSet(), hasLength(500));
      for (var i = 0; i < 500; i++) {
        final lv = blockLevel(i);
        final g = lv.newGrid();
        for (var r = 0; r < 8; r++) {
          expect(
            [for (var c = 0; c < 8; c++) g.at(r, c)].any((v) => v < 0),
            isTrue,
            reason: 'level $i row $r',
          );
        }
        for (var c = 0; c < 8; c++) {
          expect(
            [for (var r = 0; r < 8; r++) g.at(r, c)].any((v) => v < 0),
            isTrue,
            reason: 'level $i col $c',
          );
        }
        final gemTotal = lv.gems.fold(0, (a, b) => a + b);
        expect(
          lv.lines + gemTotal + lv.score,
          greaterThan(0),
          reason: 'level $i',
        );
        expect(g.gems.length, gemTotal);
      }
    },
  );

  test('levels never run out: after 500, levels 101-500 repeat', () {
    expect(blockLevel(500).data, same(levelData[100]));
    expect(blockLevel(899).data, same(levelData[499]));
    expect(blockLevel(900).data, same(levelData[100]));
    final far = blockLevel(123456);
    expect(far.index, 123456);
    expect(levelData.contains(far.data), isTrue);
  });

  // Play-test robot (hint move every time). With the challenge help (3 rescues) every
  // sampled level should be won; without help most of them.
  test('robot wins levels across the whole game', () {
    var wins = 0, winsNoHelp = 0, n = 0;
    for (var i = 0; i < 500; i += 7) {
      for (var s = 0; s < 3; s++) {
        n++;
        if (robotWins(levelData[i], 5000 + s, rescues: 3)) wins++;
        if (robotWins(levelData[i], 5000 + s)) winsNoHelp++;
      }
    }
    // ignore: avoid_print
    print(
      'robot: ${(100 * wins / n).round()}% with help, ${(100 * winsNoHelp / n).round()}% without',
    );
    expect(wins / n, greaterThan(0.95));
    expect(winsNoHelp / n, greaterThan(0.75));
  });
}
