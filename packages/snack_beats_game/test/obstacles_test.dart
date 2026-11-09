import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:snack_beats_game/snack_beats/engine/board.dart';
import 'package:snack_beats_game/snack_beats/engine/level_gen.dart';
import 'package:snack_beats_game/snack_beats/levels_data.g.dart';

const all = [0, 1, 2, 3, 4, 5];

/// Applies one full clear step the same way the game does.
ClearResult clearStep(Board b) {
  final plan = b.planClear(b.findMatches());
  final protect = {for (final cr in plan.creates) cellKey(cr.r, cr.c)};
  b.expandSpecials(plan.clear, protect: protect);
  b.addAdjacentHits(plan.clear);
  final res = b.applyClear(plan.clear);
  b.applyCreates(plan.creates, res.counts);
  return res;
}

void main() {
  test('holes are never filled, fruits fall past holes and blockers', () {
    final b = Board.fromLayout(
      ['o.o', 'ooo', 'owo', 'ooo'],
      types: all,
      rng: Random(1),
    );
    expect(b.g[0][1], isNull); // hole
    expect(b.g[2][1]!.isWall, isTrue);
    // empty the middle column's fruits, then gravity + refill
    b.g[1][1] = null;
    b.g[3][1] = null;
    b.gravity();
    b.refill();
    expect(b.g[0][1], isNull); // still a hole
    expect(b.g[2][1]!.isWall, isTrue); // wall did not move
    expect(b.g[1][1]!.isFruit && b.g[3][1]!.isFruit, isTrue);
  });

  test('blockers and holes cannot be swapped', () {
    final b = Board.fromLayout(
      ['owo', 'o.o', 'ooo'],
      types: all,
      rng: Random(2),
    );
    expect(b.canSwap((0, 0), (0, 1)), isFalse); // wall
    expect(b.canSwap((1, 0), (1, 1)), isFalse); // hole
    expect(b.canSwap((2, 0), (2, 1)), isTrue);
  });

  test('ice cracks one layer per clear under it', () {
    final b = Board.fromTypes([
      [0, 0, 0, 101],
      [102, 103, 104, 105],
    ], types: all);
    b.ice[0][1] = 2;
    var res = clearStep(b);
    expect(res.iceHits.single.$3, 1);
    expect(b.iceLeft, 1);
    // put a fruit back and clear again -> ice gone
    b.g[0][0] = Tile(0);
    b.g[0][1] = Tile(0);
    b.g[0][2] = Tile(0);
    res = clearStep(b);
    expect(res.iceCleared, 1);
    expect(b.iceLeft, 0);
  });

  test(
    'a match next to a rock hits it twice over two matches; wall breaks',
    () {
      final b = Board.fromTypes([
        [0, 0, 0, 101],
        [102, 103, 104, 105],
      ], types: all);
      b.g[1][1] = Tile(kWall, Special.none, 2); // rock under the middle fruit
      var res = clearStep(b);
      expect(res.blockerHits.single.$4, isFalse); // damaged, not destroyed
      expect(b.g[1][1]!.hp, 1);
      b.g[0][0] = Tile(0);
      b.g[0][1] = Tile(0);
      b.g[0][2] = Tile(0);
      res = clearStep(b);
      expect(res.wallsDestroyed, 1);
      expect(b.g[1][1], isNull);
    },
  );

  test('mud spreads into a neighbouring fruit', () {
    final b = Board.fromLayout(
      ['moooo', 'ooooo', 'ooooo', 'ooooo'],
      types: all,
      rng: Random(3),
    );
    expect(b.mudLeft, 1);
    final grown = b.spreadMud();
    expect(grown, isNotNull);
    expect(b.mudLeft, 2);
  });

  test('blasts hit blockers in range', () {
    final b = Board.fromTypes([
      [101, 102, 103, 104, 105],
      [1, 1, 1, 106, 107],
    ], types: all);
    b.g[1][1]!.special = Special.h; // line blaster clears row 1
    b.g[1][4] = Tile(kMud);
    final plan = b.planClear(b.findMatches());
    b.expandSpecials(plan.clear);
    final res = b.applyClear(plan.clear);
    expect(res.mudDestroyed, 1);
  });

  test('all 200 generated levels are valid and playable', () {
    expect(levelData, hasLength(200));
    final shapes = <String>{};
    for (var i = 0; i < levelData.length; i++) {
      final l = levelData[i];
      shapes.add(l.shape);
      expect(
        l.layout.every((r) => r.length == l.layout.first.length),
        isTrue,
        reason: 'level ${i + 1} not rectangular',
      );
      expect(
        l.layout.join().split('').every('.oiIwWm'.contains),
        isTrue,
        reason: 'level ${i + 1} bad char',
      );
      expect(l.moves, inInclusiveRange(12, 45));
      expect(
        l.goals.isNotEmpty || l.iceCells + l.wallCells + l.mudCells > 0,
        isTrue,
        reason: 'level ${i + 1} has no mission',
      );
      for (final g in l.goals) {
        expect(g[0], lessThan(l.nTypes));
      }
      final b = Board.fromLayout(
        l.layout,
        types: List.generate(l.nTypes, (t) => t),
        rng: Random(i),
      );
      expect(b.findAnyMove(), isNotNull, reason: 'level ${i + 1} has no move');
    }
    expect(shapes.length, greaterThanOrEqualTo(10));
  });

  test(
    'sampled levels are winnable within their moves by the play-test robot',
    () {
      for (final i in [0, 30, 55, 66, 90, 120, 150, 199]) {
        final l = levelData[i];
        final plan = LevelPlan(l.shape, l.layout, l.nTypes, l.goals);
        final rng = Random(1000 + i);
        final wins = [
          for (var g = 0; g < 10; g++) simulate(plan, rng, maxMoves: l.moves),
        ].where((m) => m <= l.moves).length;
        expect(
          wins,
          greaterThanOrEqualTo(5),
          reason: 'level ${i + 1}: only $wins/10 robot wins',
        );
      }
    },
  );

  test('fuzz on an obstacle board: no crashes, board stays consistent', () {
    final b = Board.fromLayout(
      [
        '.ooooo.',
        'oiiwiio',
        'oowmwoo',
        'oIoooIo',
        'ooWoWoo',
        'ooooooo',
        '..ooo..',
      ],
      types: all,
      rng: Random(9),
    );
    for (var move = 0; move < 1500; move++) {
      final m = b.findAnyMove();
      if (m == null) {
        expect(b.shuffle(), isTrue);
        continue;
      }
      final (a, c) = m;
      b.swap(a, c);
      if (b.at(a)!.isWild || b.at(c)!.isWild) {
        final (clear, fired, _) = b.wildClear(a, c);
        b.expandSpecials(clear, fired: fired);
        b.addAdjacentHits(clear);
        b.applyClear(clear);
        b.gravity();
        b.refill();
      }
      var mud = 0;
      while (b.findMatches().isNotEmpty) {
        mud += clearStep(b).mudDestroyed;
        b.gravity();
        b.refill();
      }
      if (b.mudLeft > 0 && mud == 0) b.spreadMud();
      for (var r = 0; r < b.rows; r++) {
        for (var col = 0; col < b.cols; col++) {
          expect(
            b.g[r][col] == null,
            !b.mask[r][col],
            reason: 'cell ($r,$col) at move $move',
          );
        }
      }
    }
  });
}
