import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:snack_beats_game/snack_beats/engine/board.dart';

const all = [0, 1, 2, 3, 4, 5];

/// '.' = filler that never matches (unique type >= 100).
Board fromRows(List<String> rows) {
  var filler = 100;
  return Board.fromTypes([
    for (final r in rows)
      [for (final ch in r.split('')) ch == '.' ? filler++ : int.parse(ch)],
  ], types: all);
}

void main() {
  test('new boards have no ready-made matches (incl. squares) and a move', () {
    final rng = Random(1);
    for (var i = 0; i < 200; i++) {
      final b = Board(types: const [0, 1, 2, 3, 4], rng: rng);
      expect(b.hasMatch, isFalse);
      expect(b.findAnyMove(), isNotNull);
    }
  });

  test('4 in a row creates a line blaster at the swapped cell', () {
    final b = fromRows(['0000...', '.......', '.......']);
    final plan = b.planClear(b.findMatches(), [(0, 1)]);
    expect(plan.creates.single.special, Special.h);
    expect((plan.creates.single.r, plan.creates.single.c), (0, 1));
    expect(plan.clear, hasLength(3));
  });

  test('5 in a row creates a rainbow, 6 in a row creates a nova', () {
    final b5 = fromRows(['00000..', '.......', '.......']);
    expect(b5.planClear(b5.findMatches()).creates.single.type, kRainbow);
    final b6 = fromRows(['000000.', '.......', '.......']);
    expect(b6.planClear(b6.findMatches()).creates.single.type, kNova);
  });

  test('L shape creates a bomb at the corner', () {
    final b = fromRows(['000....', '0......', '0......']);
    final plan = b.planClear(b.findMatches());
    expect(plan.creates.single.special, Special.bomb);
    expect((plan.creates.single.r, plan.creates.single.c), (0, 0));
    expect(plan.clear, hasLength(4));
  });

  test('2x2 square creates a flyer', () {
    final b = fromRows(['00.....', '00.....', '.......']);
    final m = b.findMatches();
    expect(m.runs, isEmpty);
    expect(m.squares, hasLength(1));
    final plan = b.planClear(m, [(1, 1)]);
    expect(plan.creates.single.special, Special.flyer);
    expect((plan.creates.single.r, plan.creates.single.c), (1, 1));
    expect(plan.clear, hasLength(3));
  });

  test('flyer rockets clear 3 extra cells, preferring needed foods', () {
    final b = fromRows(['111....', '.......', '.5...5.', '...5...']);
    b.g[0][1]!.special = Special.flyer;
    b.preferTypes = {5};
    final plan = b.planClear(b.findMatches());
    final blasts = b.expandSpecials(plan.clear);
    final flyer = blasts.singleWhere((x) => x.kind == BlastKind.flyer);
    expect(flyer.targets, hasLength(3));
    expect(flyer.targets.every((p) => b.at(p)!.type == 5), isTrue);
    expect(plan.clear, hasLength(6));
  });

  test('line blaster clears its whole row', () {
    final b = fromRows(['111....', '.......']);
    b.g[0][1]!.special = Special.h;
    final plan = b.planClear(b.findMatches());
    b.expandSpecials(plan.clear);
    expect(plan.clear, hasLength(7));
  });

  test('rainbow swap clears every tile of the neighbor type', () {
    final b = fromRows(['2.2.2..', '.2.....']);
    b.g[1][0]!.type = kRainbow;
    final (clear, _, blast) = b.wildClear((1, 0), (1, 1));
    expect(clear, hasLength(5)); // 4 twos + rainbow
    expect(blast.kind, BlastKind.rainbow);
  });

  test('nova swap, and rainbow + rainbow, clear the whole board', () {
    final b = fromRows(['.......', '.......']);
    b.g[0][0]!.type = kNova;
    final (clear, _, blast) = b.wildClear((0, 0), (0, 1));
    expect(clear, hasLength(14));
    expect(blast.kind, BlastKind.nova);

    final b2 = fromRows(['.......', '.......']);
    b2.g[0][0]!.type = kRainbow;
    b2.g[0][1]!.type = kRainbow;
    expect(b2.wildClear((0, 0), (0, 1)).$1, hasLength(14));
  });

  test('fuzz: 3000 moves keep the board full, unique and playable', () {
    final b = Board(types: all, rng: Random(42))..preferTypes = {0, 3};
    final seen = <Special>{};
    var wilds = 0;
    for (var move = 0; move < 3000; move++) {
      final m = b.findAnyMove();
      expect(m, isNotNull);
      final (a, c) = m!;
      b.swap(a, c);
      var pivots = <Cell>[a, c];
      if (b.at(a)!.isWild || b.at(c)!.isWild) {
        wilds++;
        final (clear, fired, _) = b.wildClear(a, c);
        b.expandSpecials(clear, fired: fired);
        b.applyClear(clear);
        b.gravity();
        b.refill();
        pivots = [];
      }
      var guard = 0;
      while (true) {
        final found = b.findMatches();
        if (found.isEmpty) break;
        final plan = b.planClear(found, pivots);
        for (final cr in plan.creates) {
          seen.add(cr.special);
        }
        final protect = {for (final cr in plan.creates) cellKey(cr.r, cr.c)};
        b.expandSpecials(plan.clear, protect: protect);
        final res = b.applyClear(plan.clear);
        b.applyCreates(plan.creates, res.counts);
        b.gravity();
        b.refill();
        pivots = [];
        expect(++guard, lessThan(200));
      }
      expect(b.g.every((row) => row.every((t) => t != null)), isTrue);
      if (b.findAnyMove() == null) expect(b.shuffle(), isTrue);
      expect({
        for (final row in b.g)
          for (final t in row) t!.id,
      }, hasLength(49));
    }
    // The fuzz run should exercise every special kind.
    expect(
      seen,
      containsAll([Special.h, Special.v, Special.bomb, Special.flyer]),
    );
    expect(wilds, greaterThan(0));
  });
}
