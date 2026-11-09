// Pure match-3 engine (no DOM). Grid is grid[row][col] = tile | null.
// tile = { id, type, special }  type: food index (0..5) or RAINBOW; special: null | 'h' | 'v' | 'bomb'

export const RAINBOW = 'R';
let nextId = 1;

export function makeTile(type, special = null) {
  return { id: nextId++, type, special };
}

export const key = (r, c) => r * 16 + c; // cols < 16
export const unkey = k => [Math.floor(k / 16), k % 16];

const pick = (arr, rng) => arr[Math.floor(rng() * arr.length)];

export function swap(g, [r1, c1], [r2, c2]) {
  const t = g[r1][c1];
  g[r1][c1] = g[r2][c2];
  g[r2][c2] = t;
}

export const adjacent = (a, b) => Math.abs(a[0] - b[0]) + Math.abs(a[1] - b[1]) === 1;

export function createGrid(rows, cols, types, rng = Math.random) {
  for (let attempt = 0; attempt < 200; attempt++) {
    const g = [];
    for (let r = 0; r < rows; r++) {
      const row = [];
      g.push(row);
      for (let c = 0; c < cols; c++) {
        let t, guard = 0;
        do {
          t = pick(types, rng);
          guard++;
        } while (
          guard < 50 &&
          ((c >= 2 && row[c - 1].type === t && row[c - 2].type === t) ||
            (r >= 2 && g[r - 1][c].type === t && g[r - 2][c].type === t))
        );
        row.push(makeTile(t));
      }
    }
    if (findRuns(g).length === 0 && findAnyMove(g)) return g;
  }
  throw new Error('could not create grid');
}

export function findRuns(g) {
  const rows = g.length, cols = g[0].length, runs = [];
  const typeAt = (r, c) => {
    const t = g[r][c];
    return t && t.type !== RAINBOW ? t.type : null;
  };
  for (let r = 0; r < rows; r++) {
    let c = 0;
    while (c < cols) {
      const t = typeAt(r, c);
      let e = c + 1;
      if (t !== null) while (e < cols && typeAt(r, e) === t) e++;
      if (t !== null && e - c >= 3) {
        runs.push({ dir: 'h', type: t, cells: Array.from({ length: e - c }, (_, i) => [r, c + i]) });
      }
      c = e;
    }
  }
  for (let c = 0; c < cols; c++) {
    let r = 0;
    while (r < rows) {
      const t = typeAt(r, c);
      let e = r + 1;
      if (t !== null) while (e < rows && typeAt(e, c) === t) e++;
      if (t !== null && e - r >= 3) {
        runs.push({ dir: 'v', type: t, cells: Array.from({ length: e - r }, (_, i) => [r + i, c]) });
      }
      r = e;
    }
  }
  return runs;
}

/** Returns a valid move [[r,c],[r2,c2]] or null. */
export function findAnyMove(g) {
  const rows = g.length, cols = g[0].length;
  for (let r = 0; r < rows; r++) {
    for (let c = 0; c < cols; c++) {
      if (g[r][c] && g[r][c].type === RAINBOW) {
        const n = c + 1 < cols ? [r, c + 1] : c > 0 ? [r, c - 1] : r + 1 < rows ? [r + 1, c] : [r - 1, c];
        return [[r, c], n];
      }
    }
  }
  for (let r = 0; r < rows; r++) {
    for (let c = 0; c < cols; c++) {
      for (const [dr, dc] of [[0, 1], [1, 0]]) {
        const r2 = r + dr, c2 = c + dc;
        if (r2 >= rows || c2 >= cols) continue;
        swap(g, [r, c], [r2, c2]);
        const ok = findRuns(g).length > 0;
        swap(g, [r, c], [r2, c2]);
        if (ok) return [[r, c], [r2, c2]];
      }
    }
  }
  return null;
}

/**
 * Decide which cells clear and which specials get created.
 * 5+ in a line -> rainbow (music note), L/T intersection -> bomb, 4 in a line -> line blaster.
 */
export function planClear(g, runs, pivots = []) {
  const clear = new Set(), count = new Map(), creates = [], used = new Set(), consumed = new Set();
  for (const run of runs) {
    for (const [r, c] of run.cells) {
      const k = key(r, c);
      clear.add(k);
      count.set(k, (count.get(k) || 0) + 1);
    }
  }
  const pivotKeys = new Set(pivots.map(([r, c]) => key(r, c)));
  const pivotOf = run =>
    run.cells.find(([r, c]) => pivotKeys.has(key(r, c))) || run.cells[Math.floor(run.cells.length / 2)];
  const consume = run => run.cells.forEach(([r, c]) => consumed.add(key(r, c)));

  for (const run of [...runs].sort((a, b) => b.cells.length - a.cells.length)) {
    if (run.cells.length < 5) continue;
    const [r, c] = pivotOf(run);
    const k = key(r, c);
    if (!used.has(k)) {
      creates.push({ r, c, type: RAINBOW, special: null, fromType: run.type });
      used.add(k);
    }
    consume(run);
  }
  for (const [k, n] of count) {
    if (n < 2 || consumed.has(k) || used.has(k)) continue;
    const [r, c] = unkey(k);
    const type = g[r][c].type;
    creates.push({ r, c, type, special: 'bomb', fromType: type });
    used.add(k);
    for (const run of runs) if (run.cells.some(([r2, c2]) => key(r2, c2) === k)) consume(run);
  }
  for (const run of runs) {
    if (run.cells.length !== 4 || run.cells.some(([r, c]) => consumed.has(key(r, c)))) continue;
    const [r, c] = pivotOf(run);
    creates.push({ r, c, type: run.type, special: run.dir, fromType: run.type });
    used.add(key(r, c));
    consume(run);
  }
  for (const cr of creates) clear.delete(key(cr.r, cr.c));
  return { clear, creates };
}

function mostCommonType(g) {
  const counts = new Map();
  for (const row of g) for (const t of row) {
    if (t && t.type !== RAINBOW) counts.set(t.type, (counts.get(t.type) || 0) + 1);
  }
  let best = null, bestN = -1;
  for (const [t, n] of counts) if (n > bestN) { best = t; bestN = n; }
  return best;
}

/** Fire specials inside the clear set (chain reactions). Mutates `clear`. Returns effects list. */
export function expandSpecials(g, clear, protect = new Set(), fired = new Set()) {
  const rows = g.length, cols = g[0].length, effects = [];
  const queue = [...clear];
  const add = k => {
    if (!clear.has(k) && !protect.has(k)) { clear.add(k); queue.push(k); }
  };
  while (queue.length) {
    const k = queue.shift();
    if (fired.has(k)) continue;
    const [r, c] = unkey(k);
    const t = g[r][c];
    if (!t) continue;
    if (t.special === 'h') {
      fired.add(k); effects.push({ kind: 'h', r, c });
      for (let x = 0; x < cols; x++) add(key(r, x));
    } else if (t.special === 'v') {
      fired.add(k); effects.push({ kind: 'v', r, c });
      for (let y = 0; y < rows; y++) add(key(y, c));
    } else if (t.special === 'bomb') {
      fired.add(k); effects.push({ kind: 'bomb', r, c });
      for (let y = r - 1; y <= r + 1; y++) for (let x = c - 1; x <= c + 1; x++) {
        if (y >= 0 && y < rows && x >= 0 && x < cols) add(key(y, x));
      }
    } else if (t.type === RAINBOW) {
      fired.add(k); effects.push({ kind: 'rainbow', r, c });
      const tt = mostCommonType(g);
      for (let y = 0; y < rows; y++) for (let x = 0; x < cols; x++) {
        if (g[y][x] && g[y][x].type === tt) add(key(y, x));
      }
    }
  }
  return effects;
}

/** Swapping a rainbow tile with a neighbor clears every tile of the neighbor's type. */
export function rainbowClear(g, a, b) {
  const rows = g.length, cols = g[0].length;
  const ta = g[a[0]][a[1]], tb = g[b[0]][b[1]];
  const clear = new Set(), fired = new Set();
  if (ta.type === RAINBOW && tb.type === RAINBOW) {
    for (let r = 0; r < rows; r++) for (let c = 0; c < cols; c++) clear.add(key(r, c));
    fired.add(key(...a)); fired.add(key(...b));
  } else {
    const [rp, op] = ta.type === RAINBOW ? [a, b] : [b, a];
    const target = g[op[0]][op[1]].type;
    clear.add(key(...rp)); fired.add(key(...rp));
    for (let r = 0; r < rows; r++) for (let c = 0; c < cols; c++) {
      if (g[r][c] && g[r][c].type === target) clear.add(key(r, c));
    }
  }
  return { clear, fired };
}

/** Remove cleared tiles. Returns counts per food type and removed tile ids. */
export function applyClear(g, clear) {
  const counts = new Map(), ids = [];
  for (const k of clear) {
    const [r, c] = unkey(k);
    const t = g[r][c];
    if (!t) continue;
    if (t.type !== RAINBOW) counts.set(t.type, (counts.get(t.type) || 0) + 1);
    ids.push(t.id);
    g[r][c] = null;
  }
  return { counts, ids };
}

export function applyCreates(g, creates, counts) {
  for (const cr of creates) {
    const t = g[cr.r][cr.c];
    if (!t) continue;
    t.type = cr.type;
    t.special = cr.special;
    counts.set(cr.fromType, (counts.get(cr.fromType) || 0) + 1);
  }
}

export function gravity(g) {
  const rows = g.length, cols = g[0].length;
  for (let c = 0; c < cols; c++) {
    let write = rows - 1;
    for (let r = rows - 1; r >= 0; r--) {
      if (g[r][c]) {
        if (write !== r) { g[write][c] = g[r][c]; g[r][c] = null; }
        write--;
      }
    }
  }
}

/** Fill empty cells (top of each column after gravity). Returns spawns with start row above the board. */
export function refill(g, types, rng = Math.random) {
  const rows = g.length, cols = g[0].length, spawns = [];
  for (let c = 0; c < cols; c++) {
    let empties = 0;
    for (let r = 0; r < rows; r++) if (!g[r][c]) empties++;
    for (let r = 0; r < rows; r++) {
      if (!g[r][c]) {
        const t = makeTile(pick(types, rng));
        g[r][c] = t;
        spawns.push({ tile: t, fromRow: r - empties });
      }
    }
  }
  return spawns;
}

/** Rearrange tiles until there is no ready-made match and at least one move. */
export function shuffle(g, types, rng = Math.random) {
  const rows = g.length, cols = g[0].length;
  const tiles = g.flat().filter(Boolean);
  for (let attempt = 0; attempt < 200; attempt++) {
    for (let i = tiles.length - 1; i > 0; i--) {
      const j = Math.floor(rng() * (i + 1));
      [tiles[i], tiles[j]] = [tiles[j], tiles[i]];
    }
    if (attempt > 100) for (const t of tiles) if (!t.special && t.type !== RAINBOW) t.type = pick(types, rng);
    let i = 0;
    for (let r = 0; r < rows; r++) for (let c = 0; c < cols; c++) g[r][c] = tiles[i++];
    if (findRuns(g).length === 0 && findAnyMove(g)) return true;
  }
  return false;
}
