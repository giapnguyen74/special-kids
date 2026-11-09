import 'lang.dart';

/// Public-domain melodies. Format: NOTE[:beats].
class Song {
  const Song(this.en, this.vi, this.notes);
  final String en, vi, notes;
  String title(Lang l) => l == Lang.vi ? vi : en;
}

const songs = <Song>[
  Song(
    'Twinkle Twinkle Little Star',
    'Ngôi sao nhỏ lấp lánh',
    'C4 C4 G4 G4 A4 A4 G4:2 F4 F4 E4 E4 D4 D4 C4:2 G4 G4 F4 F4 E4 E4 D4:2 G4 G4 F4 F4 E4 E4 D4:2 C4 C4 G4 G4 A4 A4 G4:2 F4 F4 E4 E4 D4 D4 C4:2',
  ),
  Song(
    'Mary Had a Little Lamb',
    'Mary có một chú cừu non',
    'E4 D4 C4 D4 E4 E4 E4:2 D4 D4 D4:2 E4 G4 G4:2 E4 D4 C4 D4 E4 E4 E4 E4 D4 D4 E4 D4 C4:2',
  ),
  Song(
    'Ode to Joy',
    'Khúc hoan ca',
    'E4 E4 F4 G4 G4 F4 E4 D4 C4 C4 D4 E4 E4:1.5 D4:0.5 D4:2 E4 E4 F4 G4 G4 F4 E4 D4 C4 C4 D4 E4 D4:1.5 C4:0.5 C4:2',
  ),
  Song(
    'Frère Jacques',
    'Kìa con bướm vàng',
    'C4 D4 E4 C4 C4 D4 E4 C4 E4 F4 G4:2 E4 F4 G4:2 G4:0.5 A4:0.5 G4:0.5 F4:0.5 E4 C4 G4:0.5 A4:0.5 G4:0.5 F4:0.5 E4 C4 C4 G3 C4:2 C4 G3 C4:2',
  ),
  Song(
    'Row, Row, Row Your Boat',
    'Chèo thuyền',
    'C4:1.5 C4:1.5 C4 D4:0.5 E4:1.5 E4 D4:0.5 E4 F4:0.5 G4:3 C5:0.5 C5:0.5 C5:0.5 G4:0.5 G4:0.5 G4:0.5 E4:0.5 E4:0.5 E4:0.5 C4:0.5 C4:0.5 C4:0.5 G4 F4:0.5 E4 D4:0.5 C4:3',
  ),
  Song(
    'London Bridge',
    'Cầu London',
    'G4:1.5 A4:0.5 G4 F4 E4 F4 G4:2 D4 E4 F4:2 E4 F4 G4:2 G4:1.5 A4:0.5 G4 F4 E4 F4 G4:2 D4:2 G4:2 E4 C4:3',
  ),
  Song(
    'Jingle Bells',
    'Jingle Bells',
    'E4 E4 E4:2 E4 E4 E4:2 E4 G4 C4:1.5 D4:0.5 E4:4 F4 F4 F4:1.5 F4:0.5 F4 E4 E4 E4:0.5 E4:0.5 E4 D4 D4 E4 D4:2 G4:2 E4 E4 E4:2 E4 E4 E4:2 E4 G4 C4:1.5 D4:0.5 E4:4 F4 F4 F4:1.5 F4:0.5 F4 E4 E4 E4:0.5 E4:0.5 G4 G4 F4 D4 C4:4',
  ),
  Song(
    'Happy Birthday',
    'Chúc mừng sinh nhật',
    'G4:0.75 G4:0.25 A4 G4 C5 B4:2 G4:0.75 G4:0.25 A4 G4 D5 C5:2 G4:0.75 G4:0.25 G5 E5 C5 B4 A4:2 F5:0.75 F5:0.25 E5 C5 D5 C5:2',
  ),
];

class Note {
  const Note(this.midi, this.beats);
  final int midi;
  final double beats;
}

const _semis = {
  'C': 0,
  'C#': 1,
  'D': 2,
  'D#': 3,
  'E': 4,
  'F': 5,
  'F#': 6,
  'G': 7,
  'G#': 8,
  'A': 9,
  'A#': 10,
  'B': 11,
};

int noteToMidi(String name) {
  final m = RegExp(r'^([A-G]#?)(\d)$').firstMatch(name)!;
  return (int.parse(m.group(2)!) + 1) * 12 + _semis[m.group(1)]!;
}

final List<List<Note>> parsedSongs = [
  for (final s in songs)
    [
      for (final tok in s.notes.trim().split(RegExp(r'\s+')))
        Note(
          noteToMidi(tok.split(':')[0]),
          tok.contains(':') ? double.parse(tok.split(':')[1]) : 1,
        ),
    ],
];
