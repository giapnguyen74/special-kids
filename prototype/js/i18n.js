export const FOODS = [
  { emoji: '🥭', color: '#FFD54F', en: { name: 'mango', plural: 'mangoes', ask: 'a mango' }, vi: { name: 'xoài', count: 'quả xoài' } },
  { emoji: '🥖', color: '#FF9F43', en: { name: 'bánh mì', plural: 'bánh mì', ask: 'a bánh mì' }, vi: { name: 'bánh mì', count: 'ổ bánh mì' } },
  { emoji: '🥟', color: '#4ECDC4', en: { name: 'dumpling', plural: 'dumplings', ask: 'dumplings' }, vi: { name: 'sủi cảo', count: 'cái sủi cảo' } },
  { emoji: '🍓', color: '#FF6B8B', en: { name: 'strawberry', plural: 'strawberries', ask: 'strawberries' }, vi: { name: 'dâu tây', count: 'quả dâu tây' } },
  { emoji: '🍜', color: '#A78BFA', en: { name: 'phở', plural: 'phở', ask: 'phở', count1: 'bowl of phở', count: 'bowls of phở' }, vi: { name: 'phở', count: 'bát phở' } },
  { emoji: '🍪', color: '#60A5FA', en: { name: 'cookie', plural: 'cookies', ask: 'a cookie' }, vi: { name: 'bánh quy', count: 'cái bánh quy' } },
];

export const CUSTOMERS = ['🧑', '👩', '👨', '👵', '🧔', '👩‍🦱', '👴', '🧑‍🦱'];

export function foodWord(f, lang, form = 'name') {
  const d = FOODS[f][lang];
  if (lang === 'vi') return form === 'count' ? d.count : d.name;
  if (form === 'ask') return d.ask;
  if (form === 'plural') return d.plural;
  return d.name;
}

export function goalSentence(goals, lang) {
  if (lang === 'vi') {
    return 'Xin chào! Tôi cần ' + goals.map(g => `${g.n} ${FOODS[g.food].vi.count}`).join(' và ') + '.';
  }
  return 'Hi! I need ' + goals.map(g => {
    const d = FOODS[g.food].en;
    return `${g.n} ${g.n === 1 ? (d.count1 || d.name) : (d.count || d.plural)}`;
  }).join(' and ') + '.';
}

// Sentence templates grow longer level by level. {F} = food (request form), {FP} = plural.
export const SENTENCES = [
  { en: ['I', 'want', '{F}'], vi: ['Tôi', 'muốn', '{F}'] },
  { en: ['I', 'want', '{F}', 'please'], vi: ['Tôi', 'muốn', 'ăn', '{F}'] },
  { en: ['Can', 'I', 'have', '{F}', 'please'], vi: ['Cho', 'tôi', 'xin', '{F}', 'ạ'] },
  { en: ['I', 'would', 'like', '{F}', 'please'], vi: ['Con', 'muốn', 'ăn', '{F}', 'ạ'] },
  { en: ['I', 'am', 'hungry,', 'I', 'want', '{F}'], vi: ['Con', 'đói', 'rồi,', 'con', 'muốn', 'ăn', '{F}'] },
  { en: ['Mom,', 'can', 'I', 'have', '{F}', 'please'], vi: ['Mẹ', 'ơi,', 'cho', 'con', 'ăn', '{F}', 'ạ'] },
  { en: ['Thank', 'you,', 'I', 'love', '{FP}'], vi: ['Cảm ơn,', 'con', 'thích', '{F}', 'lắm'] },
  { en: ['Dad,', 'I', 'would', 'like', '{F}', 'please'], vi: ['Bố', 'ơi,', 'con', 'muốn', 'ăn', '{F}', 'ạ'] },
];

export const DISTRACTORS = { en: ['you', 'go', 'no', 'is'], vi: ['bạn', 'đi', 'không', 'là'] };

const STR = {
  en: {
    tagline: 'Match food. Make music.',
    play: 'Play', level: 'Level', start: "Let's go!",
    myMusic: 'My Music', calm: 'Calm Mode', parents: 'Parents', holdHint: 'hold',
    moves: 'Moves',
    orderDone: 'Order complete!', serve: 'Serve the order ▶',
    almost: "So close! Let's try again.", tryAgain: 'Try again', home: 'Home',
    whatWant: 'Thank you! Now you pick a treat. What do you want?',
    makeSentence: 'Make the sentence',
    sayIt: 'Your turn! Say it out loud 🎤', saidIt: 'I said it! 🎤', skip: 'Skip',
    selfStart: 'You started by yourself! +1 ⭐',
    newSong: 'New song unlocked!', greatJob: 'Great job!', next: 'Next level ▶',
    locked: 'Locked', calmTitle: 'Calm — no goals, just relax',
    breakTitle: 'Great playing!', breakMsg: 'Time for a break. 🎵', parentContinue: 'Parent: hold to continue',
    p_title: 'Parent dashboard', p_note: 'All data stays on this device only.',
    p_playToday: 'Play time today', p_selfStarts: 'Started without a cue', p_avgStart: 'Avg. time to start (last 10)',
    p_sentences: 'Sentences built', p_avgLen: 'Avg. sentence length', p_words: 'words', p_noHint: 'Sentences with no help',
    p_spoke: 'Said it out loud', p_levels: 'Levels completed', p_week: 'Last 7 days',
    p_day: 'Day', p_min: 'Minutes', p_help: 'Current help level (adjusts automatically)',
    p_sentHelp: 'Sentence help', p_helpNames: ['Full model shown', 'First word shown', 'No hints'],
    p_cue: 'Start cue (glow) appears after', p_settings: 'Settings', p_lang: 'Language', p_limit: 'Break after',
    p_off: 'Off', p_minutes: 'min', p_voices: 'Voices on this device', p_voiceMissing: 'missing — add it in device speech settings',
    p_reset: 'Reset all progress', p_resetConfirm: 'Delete all progress and history?',
  },
  vi: {
    tagline: 'Ghép món ăn. Tạo âm nhạc.',
    play: 'Chơi', level: 'Màn', start: 'Bắt đầu!',
    myMusic: 'Nhạc của tôi', calm: 'Thư giãn', parents: 'Phụ huynh', holdHint: 'giữ',
    moves: 'Lượt',
    orderDone: 'Hoàn thành đơn!', serve: 'Phục vụ khách ▶',
    almost: 'Gần được rồi! Mình thử lại nhé.', tryAgain: 'Thử lại', home: 'Trang chủ',
    whatWant: 'Cảm ơn bạn! Giờ bạn chọn một món nhé. Bạn muốn ăn gì?',
    makeSentence: 'Ghép thành câu',
    sayIt: 'Đến lượt bạn! Hãy nói to câu này 🎤', saidIt: 'Mình đã nói! 🎤', skip: 'Bỏ qua',
    selfStart: 'Bạn tự bắt đầu! +1 ⭐',
    newSong: 'Mở khóa bài hát mới!', greatJob: 'Giỏi lắm!', next: 'Màn tiếp ▶',
    locked: 'Chưa mở', calmTitle: 'Thư giãn — không mục tiêu',
    breakTitle: 'Bạn chơi giỏi lắm!', breakMsg: 'Đến giờ nghỉ rồi. 🎵', parentContinue: 'Phụ huynh: giữ để tiếp tục',
    p_title: 'Bảng theo dõi cho phụ huynh', p_note: 'Dữ liệu chỉ lưu trên thiết bị này.',
    p_playToday: 'Thời gian chơi hôm nay', p_selfStarts: 'Tự bắt đầu (không cần gợi ý)', p_avgStart: 'Thời gian bắt đầu TB (10 lần gần nhất)',
    p_sentences: 'Số câu đã ghép', p_avgLen: 'Độ dài câu TB', p_words: 'từ', p_noHint: 'Câu không cần trợ giúp',
    p_spoke: 'Đã nói to', p_levels: 'Số màn hoàn thành', p_week: '7 ngày qua',
    p_day: 'Ngày', p_min: 'Phút', p_help: 'Mức trợ giúp hiện tại (tự điều chỉnh)',
    p_sentHelp: 'Trợ giúp ghép câu', p_helpNames: ['Hiện câu mẫu', 'Hiện từ đầu tiên', 'Không gợi ý'],
    p_cue: 'Gợi ý (phát sáng) xuất hiện sau', p_settings: 'Cài đặt', p_lang: 'Ngôn ngữ', p_limit: 'Nghỉ sau',
    p_off: 'Tắt', p_minutes: 'phút', p_voices: 'Giọng đọc trên thiết bị', p_voiceMissing: 'chưa có — thêm trong cài đặt giọng nói',
    p_reset: 'Xóa toàn bộ tiến trình', p_resetConfirm: 'Xóa toàn bộ tiến trình và lịch sử?',
  },
};

export function t(k, lang) {
  return STR[lang]?.[k] ?? STR.en[k] ?? k;
}
