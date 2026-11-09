import { store, save, log, dayKey, resetAll } from './store.js';
import * as audio from './audio.js';
import { speak, hasVoice, stopSpeak, warmup } from './speech.js';
import { t, FOODS, foodWord, goalSentence, SENTENCES, DISTRACTORS } from './i18n.js';
import { SONGS } from './songs.js';
import { getLevel } from './levels.js';
import { BoardGame } from './board-game.js';

const $ = s => document.querySelector(s);
const tr = k => t(k, store.lang);
const say = text => speak(text, store.lang);

let game = null;
let screen = 'home';
let sessionPlayMs = 0;

// ---------- helpers ----------
function show(id) {
  screen = id;
  document.querySelectorAll('.screen').forEach(s => s.classList.toggle('active', s.id === id));
}

function applyI18n() {
  document.documentElement.lang = store.lang;
  document.querySelectorAll('[data-i18n]').forEach(el => { el.textContent = tr(el.dataset.i18n); });
  document.querySelectorAll('.starCount').forEach(el => { el.textContent = store.stars; });
}

function toast(msg) {
  const el = $('#toast');
  el.textContent = msg;
  el.classList.add('show');
  clearTimeout(toast._t);
  toast._t = setTimeout(() => el.classList.remove('show'), 2400);
}

function shuffle(a) {
  a = [...a];
  for (let i = a.length - 1; i > 0; i--) {
    const j = Math.floor(Math.random() * (i + 1));
    [a[i], a[j]] = [a[j], a[i]];
  }
  return a;
}

const capitalize = s => s.charAt(0).toUpperCase() + s.slice(1);

function holdButton(el, ms, cb) {
  let raf = 0, t0 = 0;
  const end = () => { cancelAnimationFrame(raf); raf = 0; el.style.setProperty('--p', 0); };
  el.addEventListener('pointerdown', e => {
    e.preventDefault();
    t0 = performance.now();
    const tick = () => {
      const p = Math.min(1, (performance.now() - t0) / ms);
      el.style.setProperty('--p', p);
      if (p >= 1) { end(); cb(); } else raf = requestAnimationFrame(tick);
    };
    raf = requestAnimationFrame(tick);
  });
  ['pointerup', 'pointerleave', 'pointercancel'].forEach(ev => el.addEventListener(ev, end));
}

function leave() {
  if (game) { game.destroy(); game = null; }
  stopSpeak();
  audio.stopSong();
  $('#overlay').hidden = true;
}

/**
 * INITIATION TRAINING: the app never auto-advances. It waits for the child.
 * If they tap before the glow cue appears -> "self-start" bonus, and next time the cue waits longer (help fades).
 * If they needed the cue, the cue comes a bit sooner next time. A pointing hand appears only after a long wait.
 */
function waitForStart(btn, context) {
  btn._cancelWait?.();
  return new Promise(resolve => {
    const shown = performance.now();
    const delay = store.cueDelay;
    btn.classList.remove('cue', 'cue-hand');
    const t1 = setTimeout(() => btn.classList.add('cue'), delay);
    const t2 = setTimeout(() => btn.classList.add('cue-hand'), delay * 2 + 6000);
    const cleanup = () => {
      clearTimeout(t1); clearTimeout(t2);
      btn.removeEventListener('click', handler);
      btn._cancelWait = null;
    };
    const handler = () => {
      const latency = performance.now() - shown;
      const selfStart = latency < delay;
      const hand = btn.classList.contains('cue-hand');
      btn.classList.remove('cue', 'cue-hand');
      cleanup();
      audio.unlock();
      if (selfStart) {
        store.stars += 1;
        store.cueDelay = Math.min(15000, store.cueDelay + 1000);
        toast(tr('selfStart'));
        audio.sparkle();
      } else {
        store.cueDelay = Math.max(2000, store.cueDelay - 250);
      }
      log('start', { context, latency: Math.round(latency), selfStart, hand });
      resolve();
    };
    btn._cancelWait = () => { btn.classList.remove('cue', 'cue-hand'); cleanup(); };
    btn.addEventListener('click', handler);
  });
}

function renderGoalChips(el, goals) {
  el.innerHTML = goals.map(g =>
    `<div class="chip ${g.left === 0 ? 'done' : ''}"><span>${FOODS[g.food].emoji}</span><b>${g.left === 0 ? '✔' : g.left}</b></div>`
  ).join('');
}

function overlay(emoji, title, buttons) {
  $('#ovEmoji').textContent = emoji;
  $('#ovTitle').textContent = title;
  const row = $('#ovButtons');
  row.innerHTML = '';
  for (const b of buttons) {
    const el = document.createElement('button');
    el.className = 'btn' + (b.primary ? ' primary' : '');
    el.textContent = b.label;
    el.onclick = () => { $('#overlay').hidden = true; b.fn(); };
    row.appendChild(el);
  }
  $('#overlay').hidden = false;
}

// ---------- home ----------
function renderHome() {
  applyI18n();
  $('#homeLevel').textContent = `${tr('level')} ${store.level + 1}`;
  document.querySelectorAll('#langToggle button').forEach(b => b.classList.toggle('on', b.dataset.lang === store.lang));
}

async function goHome() {
  leave();
  show('home');
  renderHome();
  await waitForStart($('#btnPlay'), 'home');
  startLevelFlow();
}

// ---------- level ----------
function breakDue() {
  return store.sessionLimitMin > 0 && sessionPlayMs >= store.sessionLimitMin * 60000;
}

async function startLevelFlow() {
  leave();
  if (breakDue()) { show('break'); applyI18n(); log('break'); return; }
  const lv = getLevel(store.level);
  show('intro');
  applyI18n();
  $('#introLevel').textContent = `${tr('level')} ${lv.index + 1}`;
  $('#introCustomer').textContent = lv.customer;
  const sentence = goalSentence(lv.goals, store.lang);
  $('#introText').textContent = sentence;
  renderGoalChips($('#introGoals'), lv.goals.map(g => ({ ...g, left: g.n })));
  $('#introSpeak').onclick = () => say(sentence);
  setTimeout(() => { if (screen === 'intro') say(sentence); }, 350);
  await waitForStart($('#btnStart'), 'level');
  playLevel(lv);
}

function playLevel(lv) {
  leave();
  show('game');
  $('#game').classList.remove('calm');
  const goals = lv.goals.map(g => ({ ...g, left: g.n }));
  let moves = lv.moves;
  let ended = false;
  const renderHud = () => {
    renderGoalChips($('#hudGoals'), goals);
    $('#hudMoves').innerHTML = `<small>${tr('moves')}</small><b>${moves}</b>`;
    $('#hudMoves').classList.toggle('low', moves <= 3);
  };
  renderHud();
  audio.setSong(lv.song);
  log('level_start', { level: lv.index });
  requestAnimationFrame(() => {
    if (screen !== 'game') return;
    game = new BoardGame($('#board'), {
      types: lv.types,
      onClear: (counts, step, info) => {
        audio.matchNote({ big: info.size >= 5 || info.specials > 0 || info.created > 0 });
        for (const g of goals) g.left = Math.max(0, g.left - (counts.get(g.food) || 0));
        renderHud();
      },
      onSwap: () => { moves--; renderHud(); },
      onInvalid: () => audio.soft(),
      onSettled: () => {
        if (ended) return;
        if (goals.every(g => g.left === 0)) { ended = true; game.lock(); win(lv, moves); }
        else if (moves <= 0) { ended = true; game.lock(); lose(lv); }
      },
    });
  });
}

function win(lv, movesLeft) {
  log('level', { level: lv.index, result: 'win', movesLeft });
  store.stars += 3;
  store.level = Math.max(store.level, lv.index + 1);
  save();
  audio.winChime();
  setTimeout(() => {
    if (screen !== 'game') return;
    overlay('😋', `${tr('orderDone')} +3 ⭐`, [{ label: tr('serve'), primary: true, fn: () => sentenceFlow(lv) }]);
  }, 500);
}

function lose(lv) {
  // No lives, no penalty: just a calm retry.
  log('level', { level: lv.index, result: 'retry' });
  overlay('🙂', tr('almost'), [
    { label: tr('home'), fn: goHome },
    { label: tr('tryAgain'), primary: true, fn: () => playLevel(lv) },
  ]);
}

// ---------- sentence builder ----------
async function sentenceFlow(lv) {
  leave();
  show('sentence');
  applyI18n();
  const lang = store.lang;
  const token = {};
  sentenceFlow.token = token;
  const alive = () => sentenceFlow.token === token && screen === 'sentence';

  $('#sCustomer').textContent = lv.customer;
  $('#sBuild').hidden = true;
  $('#sSay').hidden = true;
  const choicesEl = $('#sChoices');
  choicesEl.hidden = false;
  choicesEl.innerHTML = '';

  // 1) Child CHOOSES a treat (choosing = initiating).
  const prompt = tr('whatWant');
  $('#sPrompt').textContent = prompt;
  $('#sSpeak').onclick = () => say(prompt);
  say(prompt);
  const goalFood = lv.goals[0].food;
  const opts = shuffle([goalFood, ...shuffle([0, 1, 2, 3, 4, 5].filter(f => f !== goalFood)).slice(0, 2)]);
  const shownAt = performance.now();
  const food = await new Promise(res => {
    for (const f of opts) {
      const b = document.createElement('button');
      b.className = 'choice';
      b.innerHTML = `<span>${FOODS[f].emoji}</span><small>${foodWord(f, lang, 'name')}</small>`;
      b.onclick = () => { audio.tap(3); res(f); };
      choicesEl.appendChild(b);
    }
  });
  if (!alive()) return;
  const choiceMs = Math.round(performance.now() - shownAt);
  choicesEl.hidden = true;

  // 2) Child BUILDS the request sentence. Help fades: full model -> first word -> none.
  const tpl = SENTENCES[lv.sentence % SENTENCES.length][lang];
  const words = tpl.map(w => (w === '{F}' ? foodWord(food, lang, 'ask') : w === '{FP}' ? foodWord(food, lang, 'plural') : w));
  const full = words.join(' ');
  const h = store.hintLevel[lang] ?? 0;
  let next = 0, wrong = 0, wrongStreak = 0, hintsUsed = 0, idle = 0;

  $('#sPrompt').textContent = tr('makeSentence');
  $('#sSpeak').onclick = () => { hintsUsed++; say(full); };
  $('#sBuild').hidden = false;

  const slotsEl = $('#sSlots'), tilesEl = $('#sTiles');
  slotsEl.innerHTML = '';
  tilesEl.innerHTML = '';
  tilesEl.hidden = false;
  const slotEls = words.map((w, i) => {
    const s = document.createElement('div');
    s.className = 'slot';
    s.textContent = h === 0 || (h === 1 && i === 0) ? w : '';
    slotsEl.appendChild(s);
    return s;
  });

  const pool = [...words];
  if (lv.index >= 2) {
    const d = DISTRACTORS[lang].filter(x => !words.includes(x));
    pool.push(d[Math.floor(Math.random() * d.length)]);
  }
  const tiles = shuffle(pool.map(w => ({ w, used: false, el: null })));

  const clearGlow = () => tiles.forEach(x => x.el.classList.remove('glow'));
  const glowNext = () => {
    const tile = tiles.find(x => !x.used && x.w === words[next]);
    if (tile) { tile.el.classList.add('glow'); hintsUsed++; }
  };
  const resetIdle = () => {
    clearTimeout(idle);
    idle = setTimeout(() => { if (alive()) glowNext(); }, 12000);
  };

  if (h === 0) setTimeout(() => { if (alive()) say(full); }, 500);

  await new Promise(done => {
    for (const tile of tiles) {
      const b = document.createElement('button');
      b.className = 'wtile';
      b.textContent = tile.w;
      tile.el = b;
      b.onclick = () => {
        if (tile.used) return;
        resetIdle();
        if (tile.w === words[next]) {
          tile.used = true;
          b.classList.add('used');
          slotEls[next].textContent = tile.w;
          slotEls[next].classList.add('filled');
          next++;
          wrongStreak = 0;
          clearGlow();
          audio.tap(next);
          if (next === words.length) { clearTimeout(idle); done(); } else say(tile.w);
        } else {
          wrong++;
          wrongStreak++;
          b.classList.remove('shake');
          void b.offsetWidth;
          b.classList.add('shake');
          audio.soft();
          if (wrongStreak >= 2) { wrongStreak = 0; glowNext(); }
        }
      };
      tilesEl.appendChild(b);
    }
    resetIdle();
  });
  if (!alive()) return;

  // 3) Invite (never force) the child to say it aloud.
  tilesEl.hidden = true; // hide leftover distractor tiles
  const sentenceText = capitalize(full) + '.';
  $('#sFinal').textContent = sentenceText;
  $('#sSay').hidden = false;
  say(sentenceText);
  const spoke = await new Promise(res => {
    $('#btnSaid').onclick = () => res(true);
    $('#btnSkip').onclick = () => res(false);
  });
  if (!alive()) return;

  if (wrong === 0 && hintsUsed === 0) store.hintLevel[lang] = Math.min(2, h + 1);
  else if (wrong + hintsUsed >= 3) store.hintLevel[lang] = Math.max(0, h - 1);
  store.stars += spoke ? 3 : 1;
  log('sentence', { lang, words: full.split(/\s+/).length, wrong, hints: hintsUsed, hintLevel: h, spoke, food, choiceMs });
  if (spoke) { audio.sparkle(); toast(`${tr('greatJob')} +3 ⭐`); }
  rewardFlow(lv);
}

// ---------- reward ----------
function rewardFlow(lv) {
  leave();
  show('reward');
  applyI18n();
  const isNew = !store.songs.includes(lv.song);
  if (isNew) { store.songs.push(lv.song); save(); }
  $('#rTitle').textContent = isNew ? tr('newSong') : tr('greatJob');
  $('#rSong').textContent = '🎵 ' + SONGS[lv.song][store.lang];
  setTimeout(() => { if (screen === 'reward') audio.playSong(lv.song); }, 300);
}

// ---------- music room ----------
function showMusic() {
  leave();
  show('music');
  applyI18n();
  const list = $('#songList');
  list.innerHTML = '';
  SONGS.forEach((s, i) => {
    const un = store.songs.includes(i);
    const b = document.createElement('button');
    b.className = 'song' + (un ? '' : ' locked');
    b.innerHTML = `<span>${un ? '🎵' : '🔒'}</span><b>${un ? s[store.lang] : tr('locked')}</b>`;
    if (un) {
      b.onclick = () => {
        audio.playSong(i);
        list.querySelectorAll('.song').forEach(x => x.classList.remove('playing'));
        b.classList.add('playing');
        log('music', { song: i });
      };
    }
    list.appendChild(b);
  });
}

// ---------- calm mode ----------
function startCalm() {
  leave();
  show('game');
  $('#game').classList.add('calm');
  $('#hudGoals').innerHTML = `<span class="calm-label">🌙 ${tr('calmTitle')}</span>`;
  $('#hudMoves').innerHTML = '';
  $('#hudMoves').classList.remove('low');
  audio.setSong(store.songs.length ? store.songs[store.songs.length - 1] : 0);
  log('calm');
  requestAnimationFrame(() => {
    if (screen !== 'game') return;
    game = new BoardGame($('#board'), {
      speed: 1.4,
      idleHintMs: 15000,
      onClear: () => audio.matchNote({ gentle: true }),
    });
  });
}

// ---------- parents ----------
function showParents() {
  leave();
  show('parents');
  renderParents();
}

function renderParents() {
  const ev = store.events;
  const L = store.lang;
  const starts = ev.filter(e => e.type === 'start');
  const self = starts.filter(e => e.selfStart).length;
  const last10 = starts.slice(-10);
  const avgStart = last10.length ? last10.reduce((a, e) => a + e.latency, 0) / last10.length / 1000 : 0;
  const sents = ev.filter(e => e.type === 'sentence');
  const avgLen = sents.length ? sents.reduce((a, e) => a + e.words, 0) / sents.length : 0;
  const noHint = sents.filter(e => e.wrong === 0 && e.hints === 0).length;
  const spoke = sents.filter(e => e.spoke).length;
  const wins = ev.filter(e => e.type === 'level' && e.result === 'win').length;
  const pct = (a, b) => (b ? Math.round((a / b) * 100) + '%' : '–');
  const min = ms => Math.round((ms || 0) / 60000);

  const days = [];
  for (let i = 6; i >= 0; i--) {
    const k = dayKey(Date.now() - i * 86400000);
    const dayEv = ev.filter(e => dayKey(e.t) === k);
    const ds = dayEv.filter(e => e.type === 'start');
    const dsent = dayEv.filter(e => e.type === 'sentence');
    days.push({
      k: k.slice(5),
      min: min(store.playMs[k]),
      self: `${ds.filter(e => e.selfStart).length}/${ds.length}`,
      sent: dsent.length,
      len: dsent.length ? (dsent.reduce((a, e) => a + e.words, 0) / dsent.length).toFixed(1) : '–',
      spoke: dsent.filter(e => e.spoke).length,
    });
  }

  const helpNames = t('p_helpNames', L);
  const limits = [0, 10, 15, 20, 30, 45];
  const voiceRow = lang => `<li>${lang === 'vi' ? 'Tiếng Việt' : 'English'}: ${hasVoice(lang) ? '✅' : '⚠️ ' + tr('p_voiceMissing')}</li>`;

  $('#parentBody').innerHTML = `
    <div class="topbar"><button class="btn icon" id="pBack">⌂</button><h2>${tr('p_title')}</h2><div></div></div>
    <p class="muted">${tr('p_note')}</p>
    <div class="stat-grid">
      <div class="stat"><small>${tr('p_playToday')}</small><b>${min(store.playMs[dayKey()])} ${tr('p_minutes')}</b></div>
      <div class="stat"><small>${tr('p_selfStarts')}</small><b>${self}/${starts.length}</b><small>${pct(self, starts.length)}</small></div>
      <div class="stat"><small>${tr('p_avgStart')}</small><b>${avgStart.toFixed(1)} s</b></div>
      <div class="stat"><small>${tr('p_sentences')}</small><b>${sents.length}</b></div>
      <div class="stat"><small>${tr('p_avgLen')}</small><b>${avgLen.toFixed(1)} ${tr('p_words')}</b></div>
      <div class="stat"><small>${tr('p_noHint')}</small><b>${pct(noHint, sents.length)}</b></div>
      <div class="stat"><small>${tr('p_spoke')}</small><b>${spoke}/${sents.length}</b></div>
      <div class="stat"><small>${tr('p_levels')}</small><b>${wins}</b></div>
    </div>
    <h3>${tr('p_week')}</h3>
    <div class="table-wrap"><table>
      <tr><th>${tr('p_day')}</th><th>${tr('p_min')}</th><th>${tr('p_selfStarts')}</th><th>${tr('p_sentences')}</th><th>${tr('p_avgLen')}</th><th>${tr('p_spoke')}</th></tr>
      ${days.map(d => `<tr><td>${d.k}</td><td>${d.min}</td><td>${d.self}</td><td>${d.sent}</td><td>${d.len}</td><td>${d.spoke}</td></tr>`).join('')}
    </table></div>
    <h3>${tr('p_help')}</h3>
    <ul>
      <li>${tr('p_sentHelp')} (EN): <b>${helpNames[store.hintLevel.en]}</b></li>
      <li>${tr('p_sentHelp')} (VI): <b>${helpNames[store.hintLevel.vi]}</b></li>
      <li>${tr('p_cue')}: <b>${(store.cueDelay / 1000).toFixed(1)} s</b></li>
    </ul>
    <h3>${tr('p_settings')}</h3>
    <div class="settings">
      <label>${tr('p_lang')}
        <select id="pLang"><option value="en">English</option><option value="vi">Tiếng Việt</option></select></label>
      <label>${tr('p_limit')}
        <select id="pLimit">${limits.map(m => `<option value="${m}">${m ? m + ' ' + tr('p_minutes') : tr('p_off')}</option>`).join('')}</select></label>
    </div>
    <h3>${tr('p_voices')}</h3>
    <ul>${voiceRow('en')}${voiceRow('vi')}</ul>
    <button class="btn danger" id="pReset">${tr('p_reset')}</button>
  `;
  $('#pLang').value = store.lang;
  $('#pLimit').value = String(store.sessionLimitMin);
  $('#pLang').onchange = e => { store.lang = e.target.value; save(); renderParents(); };
  $('#pLimit').onchange = e => { store.sessionLimitMin = +e.target.value; save(); };
  $('#pReset').onclick = () => { if (confirm(tr('p_resetConfirm'))) resetAll(); };
  $('#pBack').onclick = goHome;
}

// ---------- wiring ----------
function init() {
  document.addEventListener('pointerdown', () => { audio.unlock(); warmup(); });

  document.querySelectorAll('[data-go="home"]').forEach(b => b.addEventListener('click', goHome));
  $('#gameHome').onclick = () => {
    if (!$('#game').classList.contains('calm')) log('quit', { level: store.level });
    goHome();
  };
  $('#btnMusic').onclick = showMusic;
  $('#btnCalm').onclick = startCalm;
  $('#btnNext').onclick = startLevelFlow;
  holdButton($('#btnParents'), 1500, showParents);
  holdButton($('#btnBreakContinue'), 2000, () => { sessionPlayMs = 0; startLevelFlow(); });
  document.querySelectorAll('#langToggle button').forEach(b => {
    b.onclick = e => {
      e.stopPropagation();
      store.lang = b.dataset.lang;
      save();
      log('lang', { lang: store.lang });
      renderHome();
    };
  });

  // Play-time tracking (only while actually playing and the app is visible).
  setInterval(() => {
    if (document.visibilityState !== 'visible') return;
    if (['game', 'intro', 'sentence', 'reward'].includes(screen) && !$('#game').classList.contains('calm')) {
      sessionPlayMs += 5000;
      const k = dayKey();
      store.playMs[k] = (store.playMs[k] || 0) + 5000;
      save();
    }
  }, 5000);

  if ('serviceWorker' in navigator && location.protocol !== 'file:') {
    navigator.serviceWorker.register('sw.js').catch(() => {});
  }

  log('app_open');
  goHome();
}

init();
