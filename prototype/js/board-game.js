// Connects the pure engine to the view: swaps, cascades, specials, idle hints.
import * as E from './engine.js';
import { BoardView } from './board-view.js';

const sleep = ms => new Promise(r => setTimeout(r, ms));

export class BoardGame {
  constructor(el, opts = {}) {
    this.opts = Object.assign({
      rows: 7, cols: 7, types: [0, 1, 2, 3, 4, 5], rng: Math.random,
      idleHintMs: 7000, speed: 1,
      onClear() {}, onSwap() {}, onSettled() {}, onInvalid() {},
    }, opts);
    this.view = new BoardView(el, this.opts.rows, this.opts.cols);
    this.grid = E.createGrid(this.opts.rows, this.opts.cols, this.opts.types, this.opts.rng);
    this.busy = false;
    this.locked = false;
    this.destroyed = false;
    this.selected = null;
    this.view.onSwipe = (a, b) => this.trySwap(a, b);
    this.view.onTap = cell => this.tap(cell);
    this.view.onInteract = () => this.resetIdle();
    this.view.sync(this.grid);
    this.resetIdle();
  }

  wait(ms) { return sleep(ms * this.opts.speed); }

  tap(cell) {
    if (this.busy || this.locked) return;
    if (this.selected) {
      const s = this.selected;
      this.selected = null;
      this.view.select(null);
      if (s[0] === cell[0] && s[1] === cell[1]) return;
      if (E.adjacent(s, cell)) { this.trySwap(s, cell); return; }
    }
    this.selected = cell;
    this.view.select(cell);
  }

  resetIdle() {
    clearTimeout(this.idleTimer);
    this.view.clearHint();
    if (this.locked || this.destroyed) return;
    this.idleTimer = setTimeout(() => {
      if (this.busy || this.locked || this.destroyed) return;
      const m = E.findAnyMove(this.grid);
      if (m) this.view.hint(m);
    }, this.opts.idleHintMs);
  }

  async trySwap(a, b) {
    if (this.busy || this.locked || this.destroyed || !E.adjacent(a, b)) return;
    this.busy = true;
    this.selected = null;
    this.view.select(null);
    clearTimeout(this.idleTimer);
    this.view.clearHint();

    E.swap(this.grid, a, b);
    this.view.sync(this.grid);
    await this.wait(180);
    if (this.destroyed) return;

    const ta = this.grid[a[0]][a[1]], tb = this.grid[b[0]][b[1]];
    if (ta.type === E.RAINBOW || tb.type === E.RAINBOW) {
      this.opts.onSwap();
      const { clear, fired } = E.rainbowClear(this.grid, a, b);
      const effects = E.expandSpecials(this.grid, clear, new Set(), fired);
      await this.doClear(clear, [], 0, effects.length + 1);
      await this.cascade([], 1);
    } else if (E.findRuns(this.grid).length === 0) {
      // Not a match: gently swap back, no move used.
      E.swap(this.grid, a, b);
      this.view.sync(this.grid);
      await this.wait(180);
      this.opts.onInvalid();
      this.busy = false;
      this.resetIdle();
      return;
    } else {
      this.opts.onSwap();
      await this.cascade([a, b], 0);
    }
    if (this.destroyed) return;

    if (!E.findAnyMove(this.grid)) {
      E.shuffle(this.grid, this.opts.types, this.opts.rng);
      this.view.sync(this.grid);
      await this.wait(350);
    }
    this.busy = false;
    this.opts.onSettled();
    this.resetIdle();
  }

  async cascade(pivots, step) {
    while (!this.destroyed) {
      const runs = E.findRuns(this.grid);
      if (!runs.length) break;
      const { clear, creates } = E.planClear(this.grid, runs, pivots);
      const protect = new Set(creates.map(c => E.key(c.r, c.c)));
      const effects = E.expandSpecials(this.grid, clear, protect);
      await this.doClear(clear, creates, step++, effects.length);
      pivots = [];
    }
  }

  async doClear(clear, creates, step, specials) {
    const { counts, ids } = E.applyClear(this.grid, clear);
    E.applyCreates(this.grid, creates, counts);
    this.opts.onClear(counts, step, { size: ids.length, specials, created: creates.length });
    if (specials > 0) this.view.flash();
    this.view.pop(ids);
    this.view.sync(this.grid);
    await this.wait(230);
    if (this.destroyed) return;
    E.gravity(this.grid);
    const spawns = E.refill(this.grid, this.opts.types, this.opts.rng);
    this.view.sync(this.grid, spawns);
    await this.wait(280);
  }

  lock() {
    this.locked = true;
    clearTimeout(this.idleTimer);
    this.view.clearHint();
  }

  destroy() {
    this.destroyed = true;
    this.lock();
    this.view.destroy();
  }
}
