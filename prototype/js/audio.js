// Tiny Web Audio synth: soft marimba-like plucks, no audio files needed.
import { SONGS } from './songs.js';

let ctx = null, master = null, songBus = null;
let cur = 0, pos = 0;

const NOTE = { C: 0, 'C#': 1, D: 2, 'D#': 3, E: 4, F: 5, 'F#': 6, G: 7, 'G#': 8, A: 9, 'A#': 10, B: 11 };
function freq(name) {
  const m = name.match(/^([A-G]#?)(\d)$/);
  const midi = (+m[2] + 1) * 12 + NOTE[m[1]];
  return 440 * Math.pow(2, (midi - 69) / 12);
}
const PARSED = SONGS.map(s => s.notes.trim().split(/\s+/).map(tok => {
  const [n, d] = tok.split(':');
  return { f: freq(n), d: d ? parseFloat(d) : 1 };
}));

export function unlock() {
  if (!ctx) {
    const AC = window.AudioContext || window.webkitAudioContext;
    if (!AC) return;
    ctx = new AC();
    master = ctx.createGain();
    master.gain.value = 0.6;
    const comp = ctx.createDynamicsCompressor();
    master.connect(comp);
    comp.connect(ctx.destination);
  }
  if (ctx.state === 'suspended') ctx.resume();
}

function pluck(f, when = 0, { vol = 0.35, dur = 0.9, dest = null } = {}) {
  unlock();
  if (!ctx) return;
  const t = ctx.currentTime + when;
  const g = ctx.createGain();
  const o1 = ctx.createOscillator(), o2 = ctx.createOscillator(), g2 = ctx.createGain();
  o1.type = 'sine'; o1.frequency.value = f;
  o2.type = 'sine'; o2.frequency.value = f * 4;
  g2.gain.value = 0.1;
  g.gain.setValueAtTime(0.0001, t);
  g.gain.exponentialRampToValueAtTime(vol, t + 0.008);
  g.gain.exponentialRampToValueAtTime(0.0001, t + dur);
  o1.connect(g); o2.connect(g2); g2.connect(g);
  g.connect(dest || master);
  o1.start(t); o2.start(t);
  o1.stop(t + dur + 0.05); o2.stop(t + dur + 0.05);
}

export function setSong(i) { cur = i % PARSED.length; pos = 0; }

/** Each match plays the next note of the level's song. */
export function matchNote({ big = false, gentle = false } = {}) {
  const song = PARSED[cur];
  const n = song[pos % song.length];
  pos++;
  pluck(n.f, 0, { vol: gentle ? 0.18 : 0.35, dur: gentle ? 1.4 : 0.9 });
  if (big) pluck(n.f * 2, 0.02, { vol: 0.16 });
}

export function playSong(i, beat = 0.34) {
  unlock();
  if (!ctx) return 0;
  stopSong();
  songBus = ctx.createGain();
  songBus.connect(master);
  let t = 0.05;
  for (const n of PARSED[i % PARSED.length]) {
    pluck(n.f, t, { dest: songBus, vol: 0.3, dur: Math.max(0.5, n.d * beat * 1.6) });
    t += n.d * beat;
  }
  return t;
}

export function stopSong() {
  if (songBus) { try { songBus.disconnect(); } catch { /* already gone */ } songBus = null; }
}

export function winChime() {
  [523.25, 659.25, 783.99, 1046.5].forEach((f, i) => pluck(f, i * 0.12, { vol: 0.3, dur: 1.2 }));
}

export function soft() { pluck(196, 0, { vol: 0.15, dur: 0.35 }); }

const PENTA = [0, 2, 4, 7, 9, 12, 14, 16, 19, 21, 24];
export function tap(n = 0) { pluck(392 * Math.pow(2, PENTA[n % PENTA.length] / 12), 0, { vol: 0.25, dur: 0.6 }); }

export function sparkle() {
  [1046.5, 1318.5, 1568, 2093].forEach((f, i) => pluck(f, i * 0.06, { vol: 0.15, dur: 0.6 }));
}
