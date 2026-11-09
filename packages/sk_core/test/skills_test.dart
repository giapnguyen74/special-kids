import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sk_core/core/progress/profile.dart';
import 'package:sk_core/core/skills/skills.dart';

const spec = GameSkillSpec(
  id: 'g',
  emoji: '🎮',
  titleEn: 'Game',
  titleVi: 'Game',
  slots: {
    SkillSlot.afterLevel: ['ask_treat', 'ask_help', 'counting'],
    SkillSlot.outOfMoves: ['ask_help', 'counting'],
  },
  defaults: {
    SkillSlot.afterLevel: ['ask_treat'],
    SkillSlot.outOfMoves: ['ask_help', 'counting'],
  },
);

Future<ProviderContainer> container() async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  return ProviderContainer(overrides: [prefsProvider.overrideWithValue(prefs)]);
}

void main() {
  test('game defaults apply until the parent changes them', () async {
    final c = await container();
    final e = c.read(skillEngineProvider);
    expect(e.enabled(spec, SkillSlot.afterLevel), ['ask_treat']);
    expect(e.enabled(spec, SkillSlot.outOfMoves), ['ask_help', 'counting']);

    c
        .read(profileProvider.notifier)
        .update(
          (p) => p.skills['g'] = {
            'outOfMoves': ['counting'],
            'afterLevel': [],
          },
        );
    expect(e.enabled(spec, SkillSlot.outOfMoves), ['counting']);
    expect(e.hasLessons(spec, SkillSlot.afterLevel), isFalse);
    expect(
      e.dueAfterLevel(spec, 0),
      isFalse,
    ); // nothing enabled -> no lesson after a level
  });

  test('modules not allowed in a slot are ignored', () async {
    final c = await container();
    c
        .read(profileProvider.notifier)
        .update(
          (p) => p.skills['g'] = {
            'outOfMoves': ['ask_treat', 'counting'],
          },
        );
    expect(c.read(skillEngineProvider).enabled(spec, SkillSlot.outOfMoves), [
      'counting',
    ]);
  });

  test('after-level frequency: every level / every 2 / off', () async {
    final c = await container();
    final e = c.read(skillEngineProvider);
    expect(
      [for (var i = 0; i < 4; i++) e.dueAfterLevel(spec, i)],
      [true, true, true, true],
    );
    c.read(profileProvider.notifier).update((p) => p.afterEvery['g'] = 2);
    expect(
      [for (var i = 0; i < 4; i++) e.dueAfterLevel(spec, i)],
      [true, false, true, false],
    );
    c.read(profileProvider.notifier).update((p) => p.afterEvery['g'] = 0);
    expect(e.dueAfterLevel(spec, 0), isFalse);
  });

  test('next lesson rotates through the enabled modules', () async {
    final c = await container();
    final e = c.read(skillEngineProvider);
    expect(e.peek(spec, SkillSlot.outOfMoves), 'ask_help');
    c
        .read(profileProvider.notifier)
        .update((p) => p.rotation['g.outOfMoves'] = 1);
    expect(e.peek(spec, SkillSlot.outOfMoves), 'counting');
  });

  test('suggestions follow the child profile: no word tiles for a child who does not read yet', () {
    final reader = ChildProfile(reading: Ability.yes);
    final nonReader = ChildProfile(reading: Ability.notYet);
    expect(recommendSkills(spec, reader)[SkillSlot.afterLevel], [
      'ask_treat',
      'ask_help',
      'counting',
    ]);
    expect(recommendSkills(spec, nonReader)[SkillSlot.afterLevel], [
      'counting',
    ]);
    expect(recommendSkills(spec, nonReader)[SkillSlot.outOfMoves], [
      'counting',
    ]);
  });

  test('old single "sentence practice" setting migrates to the new per-game setting', () {
    final p = ChildProfile.fromJson({'sentenceEvery': 3});
    expect(p.afterEvery['snack_beats'], 3);
  });
}
