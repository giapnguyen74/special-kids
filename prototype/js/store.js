// Progress + event log, stored only on this device (localStorage).
const KEY = 'snackbeats.v1';

const DEFAULTS = {
  lang: 'en',
  level: 0,
  stars: 0,
  songs: [],
  hintLevel: { en: 0, vi: 0 }, // sentence help: 0 full model, 1 first word, 2 none
  cueDelay: 3000, // ms before the "start" button begins to glow
  sessionLimitMin: 20,
  playMs: {}, // date -> ms
  events: [],
};

function load() {
  try {
    const saved = JSON.parse(localStorage.getItem(KEY));
    const s = Object.assign(structuredClone(DEFAULTS), saved || {});
    s.hintLevel = Object.assign({ en: 0, vi: 0 }, s.hintLevel);
    return s;
  } catch {
    return structuredClone(DEFAULTS);
  }
}

export const store = load();

export function save() {
  try { localStorage.setItem(KEY, JSON.stringify(store)); } catch { /* storage full or blocked */ }
}

export function log(type, data = {}) {
  store.events.push({ t: Date.now(), type, ...data });
  if (store.events.length > 5000) store.events.splice(0, store.events.length - 5000);
  save();
}

export function resetAll() {
  localStorage.removeItem(KEY);
  location.reload();
}

export function dayKey(ts = Date.now()) {
  const d = new Date(ts);
  return `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}-${String(d.getDate()).padStart(2, '0')}`;
}
