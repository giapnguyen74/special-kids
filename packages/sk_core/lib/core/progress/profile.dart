import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../content/lang.dart';

/// Must be overridden in main() with the loaded instance.
final prefsProvider = Provider<SharedPreferences>(
  (ref) => throw UnimplementedError('prefsProvider not overridden'),
);

/// Ability levels used to suggest which skill lessons fit a child (0 = not yet, 1 = some, 2 = yes).
abstract final class Ability {
  static const notYet = 0, some = 1, yes = 2;
}

/// The child's profile, settings and progress (one child per device). Shared by every game.
class ChildProfile {
  ChildProfile({
    this.id = 'default',
    this.name = 'Bé',
    this.avatar = '🧒',
    this.age,
    this.speech = Ability.some,
    this.reading = Ability.some,
    this.counting = Ability.some,
    this.lang = Lang.en,
    this.stars = 0,
    Map<String, int>? hintLevel,
    this.cueDelayMs = 3000,
    this.sessionLimitMin = 20,
    this.effectsSoft = false,
    Map<String, int>? playMs,
    List<int>? songs,
    Map<String, int>? gameLevels,
    Map<String, Map<String, List<String>>>? skills,
    Map<String, int>? afterEvery,
    Map<String, int>? rotation,
  }) : hintLevel = hintLevel ?? {'en': 0, 'vi': 0},
       playMs = playMs ?? {},
       songs = songs ?? [],
       gameLevels = gameLevels ?? {},
       skills = skills ?? {},
       afterEvery = afterEvery ?? {},
       rotation = rotation ?? {};

  // ---- who the child is
  final String id;
  String name;
  String avatar;
  int? age;

  /// Speaking: 0 = few words, 1 = short phrases, 2 = full sentences.
  int speech;

  /// Reading: 0 = not yet, 1 = simple words, 2 = sentences.
  int reading;

  /// Counting: 0 = not yet, 1 = up to 10, 2 = can calculate.
  int counting;

  // ---- settings
  Lang lang;
  int cueDelayMs;
  int sessionLimitMin;

  /// Softer visual effects (fewer particles, no shake) for sensory-sensitive children.
  bool effectsSoft;

  /// Skill lessons enabled per game and slot: gameId -> slotName -> [moduleId].
  /// A game missing here uses its default set.
  Map<String, Map<String, List<String>>> skills;

  /// Lesson after every Nth won level, per game (1 = every level, 0 = off). Missing = 1.
  Map<String, int> afterEvery;

  /// Round-robin position per game/slot (which lesson comes next).
  Map<String, int> rotation;

  // ---- progress
  int stars;

  /// Sentence help per language: 0 = full model, 1 = first word, 2 = no hints. Adjusts automatically.
  Map<String, int> hintLevel;
  Map<String, int> playMs; // yyyy-MM-dd -> ms
  List<int> songs; // unlocked song indexes (shared music collection)
  Map<String, int> gameLevels; // game id -> current level

  int hintFor(Lang l) => hintLevel[l.name] ?? 0;

  Map<String, Object?> toJson() => {
    'id': id,
    'name': name,
    'avatar': avatar,
    'age': age,
    'speech': speech,
    'reading': reading,
    'counting': counting,
    'lang': lang.name,
    'stars': stars,
    'hintLevel': hintLevel,
    'cueDelayMs': cueDelayMs,
    'sessionLimitMin': sessionLimitMin,
    'effectsSoft': effectsSoft,
    'playMs': playMs,
    'songs': songs,
    'gameLevels': gameLevels,
    'skills': skills,
    'afterEvery': afterEvery,
    'rotation': rotation,
  };

  static Map<String, int>? _intMap(Object? m) =>
      (m as Map?)?.map((k, v) => MapEntry(k as String, v as int));

  factory ChildProfile.fromJson(Map<String, dynamic> j, {String? id}) {
    final afterEvery = _intMap(j['afterEvery']) ?? {};
    // Migration from the single "sentence practice" setting.
    if (j['sentenceEvery'] is int && !afterEvery.containsKey('snack_beats')) {
      afterEvery['snack_beats'] = j['sentenceEvery'] as int;
    }
    return ChildProfile(
      id: id ?? j['id'] as String? ?? 'default',
      name: j['name'] as String? ?? 'Bé',
      avatar: j['avatar'] as String? ?? '🧒',
      age: j['age'] as int?,
      speech: j['speech'] as int? ?? Ability.some,
      reading: j['reading'] as int? ?? Ability.some,
      counting: j['counting'] as int? ?? Ability.some,
      lang: Lang.parse(j['lang'] as String?),
      stars: j['stars'] as int? ?? 0,
      hintLevel: _intMap(j['hintLevel']),
      cueDelayMs: j['cueDelayMs'] as int? ?? 3000,
      sessionLimitMin: j['sessionLimitMin'] as int? ?? 20,
      effectsSoft: j['effectsSoft'] as bool? ?? false,
      playMs: _intMap(j['playMs']),
      songs: (j['songs'] as List?)?.cast<int>().toList(),
      gameLevels: _intMap(j['gameLevels']),
      skills: (j['skills'] as Map?)?.map(
        (g, slots) => MapEntry(
          g as String,
          (slots as Map).map(
            (s, ids) =>
                MapEntry(s as String, (ids as List).cast<String>().toList()),
          ),
        ),
      ),
      afterEvery: afterEvery,
      rotation: _intMap(j['rotation']),
    );
  }
}

// ============================================================================ the child's profile (one child per device)

class ProfileNotifier extends Notifier<ChildProfile> {
  static const _key = 'profile.default';

  @override
  ChildProfile build() {
    final raw = ref.read(prefsProvider).getString(_key);
    if (raw == null) return ChildProfile();
    try {
      return ChildProfile.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return ChildProfile();
    }
  }

  @override
  bool updateShouldNotify(ChildProfile previous, ChildProfile next) => true;

  /// Mutate the profile, persist it and notify listeners.
  void update(void Function(ChildProfile p) fn) {
    fn(state);
    state = state;
    ref.read(prefsProvider).setString(_key, jsonEncode(state.toJson()));
  }

  /// Clears this child's progress and history (keeps who they are and their lesson settings).
  Future<void> reset() async {
    final keep = state;
    await ref.read(prefsProvider).remove(_key);
    state = ChildProfile(
      id: keep.id,
      name: keep.name,
      avatar: keep.avatar,
      age: keep.age,
      speech: keep.speech,
      reading: keep.reading,
      counting: keep.counting,
      lang: keep.lang,
      skills: keep.skills,
      afterEvery: keep.afterEvery,
    );
    ref.read(prefsProvider).setString(_key, jsonEncode(state.toJson()));
  }
}

final profileProvider = NotifierProvider<ProfileNotifier, ChildProfile>(
  ProfileNotifier.new,
);
