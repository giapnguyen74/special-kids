import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:color_beats_game/color_beats/engine/grid.dart';
import 'package:color_beats_game/color_beats/engine/levels.dart';

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

  test('levels: starting blocks never make a full line; goals exist', () {
    for (var i = 0; i < 200; i++) {
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
      expect(
        lv.lines + lv.gems.fold(0, (a, b) => a + b),
        greaterThan(0),
        reason: 'level $i',
      );
      expect(g.gems.length, lv.gems.fold(0, (a, b) => a + b));
    }
  });

  // Play-test robot: places the hint move (most lines, most neighbours). With the challenge
  // help (3 rescues), nearly every level should be won by a simple strategy.
  test('robot wins most levels', () {
    var wins = 0, winsNoHelp = 0;
    const n = 60, games = 6;
    for (var i = 0; i < n; i++) {
      for (var s = 0; s < games; s++) {
        final lv = blockLevel(i);
        final g = lv.newGrid();
        final dealer = PieceDealer(tier: lv.tier, rng: Random(i * 100 + s));
        var lines = lv.lines;
        final gems = [...lv.gems];
        var rescues = 0;
        var tray = <Piece?>[...dealer.deal(g)];
        var won = false;
        for (var step = 0; step < 400; step++) {
          final m = g.bestMove(tray);
          if (m == null) {
            if (rescues == 3) break;
            rescues++;
            final r = g.clearFullest(3);
            r.gems.forEach((k, v) => gems[k] = max(0, gems[k] - v));
            tray = [...dealer.deal(g)];
            continue;
          }
          final r = g.place(tray[m.$1]!, m.$2, m.$3);
          tray[m.$1] = null;
          lines = max(0, lines - r.lines);
          r.gems.forEach((k, v) => gems[k] = max(0, gems[k] - v));
          if (lines == 0 && gems.every((x) => x == 0)) {
            won = true;
            break;
          }
          if (tray.every((p) => p == null)) tray = [...dealer.deal(g)];
        }
        if (won) wins++;
        if (won && rescues == 0) winsNoHelp++;
      }
    }
    // ignore: avoid_print
    print(
      'robot: won ${wins / (n * games) * 100}% (without help ${winsNoHelp / (n * games) * 100}%)',
    );
    expect(wins / (n * games), greaterThan(0.9));
  });
}
