// Text-to-speech using the device's built-in voices (English + Vietnamese).
const synth = 'speechSynthesis' in window ? window.speechSynthesis : null;
let voices = [];
let warmed = false;

function loadVoices() { voices = synth ? synth.getVoices() : []; }
if (synth) {
  loadVoices();
  synth.addEventListener?.('voiceschanged', loadVoices);
}

function pickVoice(lang) {
  const code = lang === 'vi' ? 'vi' : 'en';
  const list = voices.filter(v => v.lang.toLowerCase().replace('_', '-').startsWith(code));
  if (code === 'en') return list.find(v => /en-us/i.test(v.lang.replace('_', '-'))) || list[0];
  return list[0];
}

export function hasVoice(lang) { loadVoices(); return !!pickVoice(lang); }

/** iOS needs the first utterance to come from a user gesture. */
export function warmup() {
  if (!synth || warmed) return;
  warmed = true;
  const u = new SpeechSynthesisUtterance(' ');
  u.volume = 0;
  synth.speak(u);
}

export function stopSpeak() { synth?.cancel(); }

export function speak(text, lang, { rate = 0.85 } = {}) {
  if (!synth) return Promise.resolve();
  synth.cancel();
  const u = new SpeechSynthesisUtterance(text);
  u.lang = lang === 'vi' ? 'vi-VN' : 'en-US';
  const v = pickVoice(lang);
  if (v) u.voice = v;
  u.rate = rate;
  return new Promise(res => {
    u.onend = res;
    u.onerror = res;
    synth.speak(u);
    setTimeout(res, 8000);
  });
}
