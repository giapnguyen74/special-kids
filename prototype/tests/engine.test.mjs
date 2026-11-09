import assert from 'node:assert/strict';
import * as E from '../js/engine.js';

const T = [0, 1, 2, 3, 4, 5];
let seed = 42;
const rng = () => ((seed = (seed * 1103515245 + 12345) % 2147483648) / 2147483648);

// Build a grid from a string map ('.' = filler that never matches)
function fromRows(rows) {
  let filler = 100;
  return rows.map(r => [...r].map(ch => E.makeTile(ch === '.' ? filler++ : Number(ch))));
}

// 1) New grids: no ready-made matches, at least one move
for (let i = 0; i < 200; i++) {
  const g = E.createGrid(7, 7, T.slice(0, 5), rng);
  assert.equal(E.findRuns(g).length, 0);
  assert.ok(E.findAnyMove(g));
}

// 2) 4 in a row -> line special at pivot
{
  const g = fromRows(['0000...', '.......', '.......']);
  const runs = E.findRuns(g);
  assert.equal(runs.length, 1);
  const { clear, creates } = E.planClear(g, runs, [[0, 1]]);
  assert.equal(creates.length, 1);
  assert.equal(creates[0].special, 'h');
  assert.deepEqual([creates[0].r, creates[0].c], [0, 1]);
  assert.equal(clear.size, 3);
}

// 3) 5 in a row -> rainbow
{
  const g = fromRows(['00000..', '.......', '.......']);
  const { creates } = E.planClear(g, E.findRuns(g));
  assert.equal(creates.length, 1);
  assert.equal(creates[0].type, E.RAINBOW);
}

// 4) L shape -> bomb at intersection
{
  const g = fromRows(['000....', '0......', '0......']);
  const { creates, clear } = E.planClear(g, E.findRuns(g));
  assert.equal(creates.length, 1);
  assert.equal(creates[0].special, 'bomb');
  assert.deepEqual([creates[0].r, creates[0].c], [0, 0]);
  assert.equal(clear.size, 4);
}

// 5) Line special fires its whole row
{
  const g = fromRows(['111....', '.......']);
  g[0][1].special = 'h';
  const { clear } = E.planClear(g, E.findRuns(g));
  E.expandSpecials(g, clear);
  assert.equal(clear.size, 7);
}

// 6) Rainbow swap clears all of the neighbor's type
{
  const g = fromRows(['2.2.2..', '.2.....']);
  g[1][0].type = E.RAINBOW;
  const { clear } = E.rainbowClear(g, [1, 0], [1, 1]);
  assert.equal(clear.size, 5); // 4 twos + rainbow
}

// 7) Fuzz: random valid moves, full cascade simulation; grid must stay full and stable
{
  const g = E.createGrid(7, 7, T, rng);
  for (let move = 0; move < 3000; move++) {
    const m = E.findAnyMove(g);
    assert.ok(m, 'always a move');
    const [a, b] = m;
    E.swap(g, a, b);
    const ta = g[a[0]][a[1]], tb = g[b[0]][b[1]];
    let pivots = [a, b];
    if (ta.type === E.RAINBOW || tb.type === E.RAINBOW) {
      const { clear, fired } = E.rainbowClear(g, a, b);
      E.expandSpecials(g, clear, new Set(), fired);
      E.applyClear(g, clear);
      E.gravity(g); E.refill(g, T, rng);
      pivots = [];
    }
    let guard = 0;
    while (true) {
      const runs = E.findRuns(g);
      if (!runs.length) break;
      const { clear, creates } = E.planClear(g, runs, pivots);
      const protect = new Set(creates.map(c => E.key(c.r, c.c)));
      E.expandSpecials(g, clear, protect);
      const { counts } = E.applyClear(g, clear);
      E.applyCreates(g, creates, counts);
      E.gravity(g);
      E.refill(g, T, rng);
      pivots = [];
      assert.ok(++guard < 200, 'cascade terminates');
    }
    assert.ok(g.every(row => row.every(Boolean)), 'grid full');
    if (!E.findAnyMove(g)) assert.ok(E.shuffle(g, T, rng));
    const ids = new Set(g.flat().map(t => t.id));
    assert.equal(ids.size, 49, 'unique tiles');
  }
}

console.log('engine tests passed');
