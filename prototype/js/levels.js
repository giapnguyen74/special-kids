import { CUSTOMERS, SENTENCES } from './i18n.js';
import { SONGS } from './songs.js';

const BASE = [
  { goals: [{ food: 0, n: 8 }], moves: 20 },
  { goals: [{ food: 3, n: 10 }], moves: 20 },
  { goals: [{ food: 5, n: 12 }], moves: 20 },
  { goals: [{ food: 1, n: 8 }, { food: 4, n: 8 }], moves: 22 },
  { goals: [{ food: 2, n: 14 }], moves: 20 },
  { goals: [{ food: 0, n: 10 }, { food: 3, n: 10 }], moves: 22 },
  { goals: [{ food: 4, n: 16 }], moves: 20 },
  { goals: [{ food: 5, n: 12 }, { food: 2, n: 12 }], moves: 22 },
];

function mulberry32(a) {
  return () => {
    a |= 0; a = (a + 0x6d2b79f5) | 0;
    let t = Math.imul(a ^ (a >>> 15), 1 | a);
    t = (t + Math.imul(t ^ (t >>> 7), 61 | t)) ^ t;
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  };
}

export function getLevel(i) {
  let L;
  if (i < BASE.length) {
    L = { ...BASE[i], goals: BASE[i].goals.map(g => ({ ...g })) };
  } else {
    const rng = mulberry32(i * 7919 + 13);
    const a = Math.floor(rng() * 6);
    let b = Math.floor(rng() * 5);
    if (b >= a) b++;
    const n = 10 + Math.min(10, Math.floor((i - BASE.length) / 2));
    L = { goals: [{ food: a, n }, { food: b, n }], moves: 22 };
  }
  L.index = i;
  L.song = i % SONGS.length;
  L.sentence = i % SENTENCES.length;
  L.customer = CUSTOMERS[i % CUSTOMERS.length];
  // Early levels use 5 foods (easier, more cascades); later levels use all 6.
  const nTypes = i < 3 ? 5 : 6;
  const types = [...new Set(L.goals.map(g => g.food))];
  for (let f = 0; types.length < nTypes; f++) if (!types.includes(f)) types.push(f);
  L.types = types;
  return L;
}
