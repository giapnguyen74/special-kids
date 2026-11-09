import 'package:sk_core/core/content/lang.dart';
import 'package:sk_core/core/content/songs.dart';

/// Original lyrics (written for this app) set to public-domain melodies from core/content/songs.dart.
/// Lyrics carry target functional sentences. One syllable = one melody note:
/// words are separated by spaces, syllables inside a word by '-'.
/// NOTE: Vietnamese lyrics should be reviewed by a native-speaking music teacher
/// (tone/melody fit) before release.
class SingSong {
  const SingSong({
    required this.id,
    required this.emoji,
    required this.melody,
    required this.title,
    required this.lines,
    required this.say,
  });

  final String id;
  final String emoji;
  final int melody; // index into [parsedSongs]
  final Map<Lang, String> title;
  final Map<Lang, List<String>> lines;

  /// Sentences to SAY (not sing) after the song.
  final Map<Lang, List<String>> say;

  List<Note> get notes => parsedSongs[melody];

  List<LyricLine> parsed(Lang lang) {
    var noteIndex = 0;
    return [
      for (final line in lines[lang]!)
        () {
          final words = <List<String>>[
            for (final w in line.split(' ')) w.split('-'),
          ];
          final count = words.fold<int>(0, (a, w) => a + w.length);
          final l = LyricLine(words, noteIndex, count);
          noteIndex += count;
          return l;
        }(),
    ];
  }
}

class LyricLine {
  LyricLine(this.words, this.firstNote, this.syllableCount);

  /// words[i] = syllables of word i.
  final List<List<String>> words;
  final int firstNote, syllableCount;

  String get text => words.map((w) => w.join()).join(' ');
}

const singSongs = <SingSong>[
  SingSong(
    id: 'snack',
    emoji: '🍜',
    melody: 0, // Twinkle Twinkle
    title: {Lang.en: 'Snack Song', Lang.vi: 'Bài hát Đói bụng'},
    lines: {
      Lang.en: [
        'I am hun-gry, yes I am',
        'Can I have some noo-dles, please',
        'Hot and yum-my in a bowl',
        'Thank you, Mom, I love it so',
        'I am hun-gry, yes I am',
        'Can I have some noo-dles, please',
      ],
      Lang.vi: [
        'Mẹ ơi, mẹ ơi, con đói rồi',
        'Mẹ cho con xin bát phở nha',
        'Phở thơm phở nóng thật là ngon',
        'Con cảm ơn mẹ thật nhiều ạ',
        'Mẹ ơi, mẹ ơi, con đói rồi',
        'Mẹ cho con xin bát phở nha',
      ],
    },
    say: {
      Lang.en: ['Can I have some noodles, please?', 'Thank you, Mom!'],
      Lang.vi: ['Mẹ cho con xin bát phở.', 'Con cảm ơn mẹ ạ!'],
    },
  ),
  SingSong(
    id: 'morning',
    emoji: '☀️',
    melody: 4, // Row, Row, Row Your Boat
    title: {Lang.en: 'Morning Song', Lang.vi: 'Bài hát Buổi sáng'},
    lines: {
      Lang.en: [
        'Wake up, wake up now',
        'Brush my teeth and smile',
        'Wash my face and comb my hair and put on my clothes',
        "Now I'm rea-dy, go!",
      ],
      Lang.vi: [
        'Dậy đi, dậy đi nào',
        'Đánh răng thật là sạch',
        'Rửa mặt, chải đầu, mặc quần áo, rồi ăn sáng thật ngon',
        'Mình cùng đi học thôi',
      ],
    },
    say: {
      Lang.en: ['I brush my teeth.', 'I am ready!'],
      Lang.vi: ['Con đánh răng.', 'Con sẵn sàng rồi!'],
    },
  ),
  SingSong(
    id: 'help',
    emoji: '🙋',
    melody: 1, // Mary Had a Little Lamb
    title: {Lang.en: 'Help Song', Lang.vi: 'Bài hát Nhờ giúp đỡ'},
    lines: {
      Lang.en: [
        'Can you help me, please, right now?',
        'help me, please',
        'help me, please',
        "I can ask for help, it's o-kay",
        'Thank you, thank you, friend',
      ],
      Lang.vi: [
        'Bạn ơi, bạn giúp mình với nha',
        'giúp mình nha',
        'giúp mình nha',
        'Không sao đâu, mình nhờ bạn giúp nha',
        'Cảm ơn bạn nhiều nha',
      ],
    },
    say: {
      Lang.en: ['Can you help me, please?', 'Thank you, friend!'],
      Lang.vi: ['Bạn giúp mình với nhé.', 'Cảm ơn bạn nhiều!'],
    },
  ),
  SingSong(
    id: 'feelings',
    emoji: '😊',
    melody: 5, // London Bridge
    title: {Lang.en: 'Feelings Song', Lang.vi: 'Bài hát Cảm xúc'},
    lines: {
      Lang.en: [
        "When I'm hap-py, I can smile",
        'I can smile',
        'I can smile',
        "When I'm sad, I tell my mom",
        'Mom, I feel sad',
      ],
      Lang.vi: [
        'Khi con vui, con hay mỉm cười',
        'con mỉm cười',
        'con mỉm cười',
        'Khi con buồn, con nói mẹ hay',
        'Mẹ ơi con buồn',
      ],
    },
    say: {
      Lang.en: ['I am happy.', 'Mom, I feel sad.'],
      Lang.vi: ['Con đang vui.', 'Mẹ ơi, con buồn.'],
    },
  ),
];
