import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../audio/audio_service.dart';
import '../content/foods.dart';
import '../content/lang.dart';
import '../content/sentences.dart';
import '../progress/event_log.dart';
import '../progress/profile.dart';
import '../sentence/sentence_builder.dart';
import '../session/session_tracker.dart';
import '../speech/speech_service.dart';
import '../ui/theme.dart';
import '../ui/widgets.dart';
import '../../l10n/app_localizations.dart';

import '../skills/skills.dart';

enum _Phase { choose, build, say }

/// Skill lesson "Choose & ask for a treat": the child CHOOSES a treat, BUILDS the request
/// sentence (help fades), and is invited to SAY it. Pops a [SkillOutcome].
class TreatLessonScreen extends ConsumerStatefulWidget {
  const TreatLessonScreen({super.key, required this.request});
  final SkillRequest request;
  @override
  ConsumerState<TreatLessonScreen> createState() => _TreatLessonScreenState();
}

class _TreatLessonScreenState extends ConsumerState<TreatLessonScreen>
    with TracksPlayTime {
  var _phase = _Phase.choose;
  late final Lang lang = ref.read(profileProvider).lang;
  late final int hintLevel = ref.read(profileProvider).hintFor(lang);
  late final List<int> options;
  final _choiceWatch = Stopwatch()..start();
  int? _food;
  int _choiceMs = 0;
  List<String> _words = const [];
  String? _distractor;
  int _speakerHints = 0;
  SentenceResult? _result;

  SpeechService get _speech => ref.read(speechProvider);
  AudioService get _audio => ref.read(audioProvider);
  String get _full => _words.join(' ');
  String get _sentenceText =>
      _full.isEmpty ? '' : '${_full[0].toUpperCase()}${_full.substring(1)}.';

  @override
  void initState() {
    super.initState();
    startTracking(ref.read(sessionProvider));
    final goalFood =
        widget.request.suggestedFood ?? widget.request.levelIndex % 6;
    final others = ([0, 1, 2, 3, 4, 5]..remove(goalFood))..shuffle();
    options = [goalFood, ...others.take(2)]..shuffle();
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) _speech.speak(AppLocalizations.of(context).whatWant, lang);
    });
  }

  void _choose(int food) {
    _audio.tap(3);
    _choiceMs = _choiceWatch.elapsedMilliseconds;
    final words = buildRequest(widget.request.levelIndex, food, lang);
    String? distractor;
    if (widget.request.levelIndex >= 2) {
      final pool = distractors[lang]!.where((d) => !words.contains(d)).toList();
      distractor = pool[Random().nextInt(pool.length)];
    }
    setState(() {
      _food = food;
      _words = words;
      _distractor = distractor;
      _phase = _Phase.build;
    });
    if (hintLevel == 0) {
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) _speech.speak(_full, lang);
      });
    }
  }

  void _built(SentenceResult r) {
    setState(() {
      _result = r;
      _phase = _Phase.say;
    });
    _speech.speak(_sentenceText, lang);
  }

  void _finish(bool spoke) {
    final r = _result!;
    final hints = r.hints + _speakerHints;
    ref.read(profileProvider.notifier).update((p) {
      if (r.wrong == 0 && hints == 0) {
        p.hintLevel[lang.name] = min(2, hintLevel + 1);
      } else if (r.wrong + hints >= 3) {
        p.hintLevel[lang.name] = max(0, hintLevel - 1);
      }
      p.stars += spoke ? 3 : 1;
    });
    ref
        .read(eventLogProvider)
        .log(
          'sentence',
          game: widget.request.game,
          data: {
            'lang': lang.name,
            'words': r.wordCount,
            'wrong': r.wrong,
            'hints': hints,
            'hintLevel': hintLevel,
            'spoke': spoke,
            'food': _food,
            'choiceMs': _choiceMs,
          },
        );
    if (spoke) {
      _audio.sparkle();
      showToast(context, AppLocalizations.of(context).greatJobStars);
    }
    Navigator.of(context).pop(
      SkillOutcome('ask_treat', wrong: r.wrong, hints: hints, spoke: spoke),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return AppScreen(
      scroll: true,
      child: Column(
        children: [
          Row(
            children: [
              HomeBtn(onBeforeLeave: _speech.stop),
              const Spacer(),
              Text(
                widget.request.customer,
                style: const TextStyle(fontSize: 56),
              ),
              const Spacer(),
              const StarsPill(),
            ],
          ),
          const SizedBox(height: 14),
          if (_phase == _Phase.choose) ...[
            SpeechBubble(
              text: l.whatWant,
              onSpeak: () => _speech.speak(l.whatWant, lang),
            ),
            const SizedBox(height: 24),
            Wrap(
              spacing: 16,
              runSpacing: 16,
              alignment: WrapAlignment.center,
              children: [
                for (final f in options)
                  _ChoiceCard(food: f, lang: lang, onTap: () => _choose(f)),
              ],
            ),
          ] else ...[
            SpeechBubble(
              text: l.makeSentence,
              onSpeak: () {
                _speakerHints++;
                _speech.speak(_full, lang);
              },
            ),
            const SizedBox(height: 18),
            SentenceBuilder(
              words: _words,
              distractor: _distractor,
              hintLevel: hintLevel,
              onWordPlaced: (w, i) {
                _audio.tap(i + 1);
                if (i < _words.length - 1) _speech.speak(w, lang);
              },
              onWrong: _audio.soft,
              onDone: _built,
            ),
            if (_phase == _Phase.say) ...[
              const SizedBox(height: 8),
              Text(
                _sentenceText,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 34,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF2962FF),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                l.sayIt,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 22),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 14,
                runSpacing: 14,
                alignment: WrapAlignment.center,
                children: [
                  BigButton(
                    label: l.saidIt,
                    primary: true,
                    onPressed: () => _finish(true),
                  ),
                  BigButton(label: l.skip, onPressed: () => _finish(false)),
                ],
              ),
            ],
          ],
        ],
      ),
    );
  }
}

class _ChoiceCard extends StatelessWidget {
  const _ChoiceCard({
    required this.food,
    required this.lang,
    required this.onTap,
  });
  final int food;
  final Lang lang;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final f = foods[food];
    final name = f.words(lang).name;
    return Semantics(
      button: true,
      label: name,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 140,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.glass2,
            borderRadius: BorderRadius.circular(24),
          ),
          child: Column(
            children: [
              Text(f.emoji, style: const TextStyle(fontSize: 70)),
              const SizedBox(height: 6),
              Text(
                name,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
