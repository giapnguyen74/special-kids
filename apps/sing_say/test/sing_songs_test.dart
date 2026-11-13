import 'package:flutter_test/flutter_test.dart';
import 'package:sk_core/core/content/lang.dart';
import 'package:sing_say/sing_say/sing_songs.dart';

void main() {
  test('every lyric syllable matches exactly one melody note (both languages)', () {
    for (final song in singSongs) {
      for (final lang in Lang.values) {
        final lines = song.parsed(lang);
        final total = lines.fold<int>(0, (a, l) => a + l.syllableCount);
        expect(
          total,
          song.notes.length,
          reason:
              '${song.id} ${lang.name}: $total syllables vs ${song.notes.length} notes',
        );
        expect(song.say[lang], isNotEmpty);
      }
      expect(
        song.lines[Lang.en]!.length,
        song.lines[Lang.vi]!.length,
        reason: '${song.id} line count EN vs VI',
      );
    }
  });
}
