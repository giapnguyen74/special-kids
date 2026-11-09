// DOM rendering + touch input for the board. Tiles are absolutely positioned and animated via CSS transforms.
import { FOODS } from './i18n.js';
import { RAINBOW } from './engine.js';

export class BoardView {
  constructor(el, rows, cols) {
    this.el = el;
    this.rows = rows;
    this.cols = cols;
    this.els = new Map(); // tile id -> element
    this.dead = false;
    this.lastGrid = null;
    el.innerHTML = '';
    this.layout();
    this._onResize = () => {
      this.layout();
      el.classList.add('no-anim');
      if (this.lastGrid) this.sync(this.lastGrid);
      requestAnimationFrame(() => el.classList.remove('no-anim'));
    };
    window.addEventListener('resize', this._onResize);
    this.bindInput();
  }

  layout() {
    const wrap = this.el.parentElement;
    const s = Math.floor(Math.min(wrap.clientWidth / this.cols, wrap.clientHeight / this.rows, 88));
    this.size = Math.max(s, 32);
    this.el.style.width = this.size * this.cols + 'px';
    this.el.style.height = this.size * this.rows + 'px';
    this.el.style.setProperty('--s', this.size + 'px');
  }

  tr(c, r) { return `translate(${c * this.size}px, ${r * this.size}px)`; }

  makeEl(tile) {
    const el = document.createElement('div');
    el.className = 'tile';
    const f = document.createElement('div');
    f.className = 'face';
    el.appendChild(f);
    this.els.set(tile.id, el);
    this.el.appendChild(el);
    return el;
  }

  paint(el, tile) {
    const sig = tile.type + '|' + tile.special;
    if (el._sig === sig) return;
    const upgraded = el._sig !== undefined;
    el._sig = sig;
    const f = el.firstChild;
    el.classList.toggle('rainbow', tile.type === RAINBOW);
    for (const s of ['h', 'v', 'bomb']) el.classList.toggle('sp-' + s, tile.special === s);
    if (tile.type === RAINBOW) {
      f.textContent = '🎵';
    } else {
      f.textContent = FOODS[tile.type].emoji;
      f.style.setProperty('--c', FOODS[tile.type].color);
    }
    if (upgraded) {
      el.classList.remove('born');
      void el.offsetWidth;
      el.classList.add('born');
    }
  }

  sync(grid, spawns = []) {
    if (this.dead) return;
    this.lastGrid = grid;
    const sp = new Map(spawns.map(s => [s.tile.id, s.fromRow]));
    const seen = new Set();
    for (let r = 0; r < this.rows; r++) {
      for (let c = 0; c < this.cols; c++) {
        const t = grid[r][c];
        if (!t) continue;
        seen.add(t.id);
        let el = this.els.get(t.id);
        if (!el) {
          el = this.makeEl(t);
          const from = sp.has(t.id) ? sp.get(t.id) : r - this.rows - 1;
          el.style.transition = 'none';
          el.style.transform = this.tr(c, from);
          el.getBoundingClientRect(); // force start position
          el.style.transition = '';
        }
        this.paint(el, t);
        el.style.transform = this.tr(c, r);
      }
    }
    for (const [id, el] of this.els) {
      if (!seen.has(id)) { el.remove(); this.els.delete(id); }
    }
  }

  pop(ids) {
    if (this.dead) return;
    for (const id of ids) {
      const el = this.els.get(id);
      if (!el) continue;
      this.els.delete(id);
      el.classList.add('pop');
      setTimeout(() => el.remove(), 260);
    }
  }

  flash(kind) {
    if (this.dead) return;
    this.el.classList.remove('flash');
    void this.el.offsetWidth;
    this.el.classList.add('flash');
  }

  elAt(cell) {
    const t = this.lastGrid?.[cell[0]]?.[cell[1]];
    return t ? this.els.get(t.id) : null;
  }

  select(cell) {
    this.el.querySelectorAll('.tile.selected').forEach(e => e.classList.remove('selected'));
    if (cell) this.elAt(cell)?.classList.add('selected');
  }

  hint(move) {
    for (const cell of move) this.elAt(cell)?.classList.add('hint');
  }

  clearHint() {
    this.el.querySelectorAll('.tile.hint').forEach(e => e.classList.remove('hint'));
  }

  bindInput() {
    const el = this.el;
    let start = null;
    const cellAt = e => {
      const rect = el.getBoundingClientRect();
      const c = Math.floor((e.clientX - rect.left) / this.size);
      const r = Math.floor((e.clientY - rect.top) / this.size);
      return r >= 0 && r < this.rows && c >= 0 && c < this.cols ? [r, c] : null;
    };
    this._down = e => {
      const cell = cellAt(e);
      if (!cell) return;
      this.onInteract?.();
      start = { cell, x: e.clientX, y: e.clientY, swiped: false };
      try { el.setPointerCapture(e.pointerId); } catch { /* ignore */ }
    };
    this._move = e => {
      if (!start || start.swiped) return;
      const dx = e.clientX - start.x, dy = e.clientY - start.y;
      const th = this.size * 0.3;
      if (Math.abs(dx) < th && Math.abs(dy) < th) return;
      start.swiped = true;
      const [r, c] = start.cell;
      const to = Math.abs(dx) > Math.abs(dy) ? [r, c + Math.sign(dx)] : [r + Math.sign(dy), c];
      if (to[0] < 0 || to[0] >= this.rows || to[1] < 0 || to[1] >= this.cols) return;
      this.onSwipe?.(start.cell, to);
    };
    this._up = () => {
      if (start && !start.swiped) this.onTap?.(start.cell);
      start = null;
    };
    el.addEventListener('pointerdown', this._down);
    el.addEventListener('pointermove', this._move);
    el.addEventListener('pointerup', this._up);
    el.addEventListener('pointercancel', () => { start = null; });
  }

  destroy() {
    this.dead = true;
    window.removeEventListener('resize', this._onResize);
    this.el.removeEventListener('pointerdown', this._down);
    this.el.removeEventListener('pointermove', this._move);
    this.el.removeEventListener('pointerup', this._up);
    this.el.innerHTML = '';
    this.els.clear();
  }
}
