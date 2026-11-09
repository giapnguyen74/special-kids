import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:sk_core/core/audio/audio_service.dart';
import 'package:sk_core/core/content/lang.dart';
import 'package:sk_core/core/initiation/start_cue_button.dart';
import 'package:sk_core/core/progress/event_log.dart';
import 'package:sk_core/core/progress/profile.dart';
import 'package:sk_core/core/session/session_tracker.dart';
import 'package:sk_core/core/speech/speech_service.dart';
import 'package:sk_core/core/ui/effects.dart';
import 'package:sk_core/core/ui/palette.dart';
import 'package:sk_core/core/ui/routes.dart';
import 'package:sk_core/core/ui/theme.dart';
import 'package:sk_core/core/ui/widgets.dart';
import 'package:special_kids/voice/voice_meter.dart';
import 'package:sk_core/l10n/app_localizations.dart';

import '../sing_say.dart';
import '../sing_songs.dart';

enum _Phase { ready, countdown, singing, say, done }

/// Karaoke: the melody plays and lyrics light up syllable by syllable.
/// Then the key lines are SAID as normal sentences (singing -> speaking bridge).
///
/// Help fades (per language, adjusts automatically):
///   0 = each line is spoken first as a model, 1 = no spoken model, 2 = last word hidden (recall).
/// The mic only measures loudness to reward using the voice; nothing is recorded.
class SingScreen extends ConsumerStatefulWidget {
  const SingScreen({super.key, required this.song});
  final SingSong song;
  @override
  ConsumerState<SingScreen> createState() => _SingScreenState();
}

class _SingScreenState extends ConsumerState<SingScreen> with TracksPlayTime {
  static const _beatMs = 520;

  late final Lang lang = ref.read(profileProvider).lang;
  late final String _hintKey = 'sing_${lang.name}';
  late final int hint = ref.read(profileProvider).hintLevel[_hintKey] ?? 0;
  late final List<LyricLine> lines = widget.song.parsed(lang);
  late final List<String> sayLines = widget.song.say[lang]!;
  late final AudioService _audio = ref.read(audioProvider);
  late final SpeechService _speech = ref.read(speechProvider);
  late final VoiceMeter _voice = ref.read(voiceProvider);

  var _phase = _Phase.ready;
  bool _alive = true;
  int _line = -1, _syl = -1, _countdown = 3, _sayIndex = -1;
  bool _previewing = false, _listening = false, _showSayButtons = false;

  // Voice
  bool? _mic; // null = not known yet
  double _level = 0, _quietBase = 0.15, _musicBase = 0.2;
  StreamSubscription<double>? _levelSub;
  final _cal = <double>[];
  bool _calibrating = false, _counting = false, _sayMode = false;
  int _voiceFrames = 0;

  // Results
  final _lineVoiced = <bool>[];
  int _sayVoiced = 0, _starsEarned = 0;
  bool? _selfReportSang;
  Completer<bool>? _choice;
  String? _flash;
  int _flashId = 0;
  bool _logged = false;

  double get _threshold =>
      min(0.9, (_sayMode ? _quietBase : _musicBase) + 0.15);

  @override
  void initState() {
    super.initState();
    startTracking(ref.read(sessionProvider));
    _initMic();
  }

  @override
  void dispose() {
    if (_phase == _Phase.done && !_logged) _logSong();
    _alive = false;
    _levelSub?.cancel();
    _voice.stop();
    _speech.stop();
    if (_choice != null && !_choice!.isCompleted) _choice!.complete(false);
    super.dispose();
  }

  Future<void> _initMic() async {
    // If the permission prompt is never answered (or the browser hangs), play without the mic.
    final ok = await _voice.start().timeout(
      const Duration(seconds: 8),
      onTimeout: () => false,
    );
    if (!mounted) return;
    setState(() => _mic = ok);
    if (!ok) return;
    _levelSub = _voice.levels.listen(_onLevel);
    // Measure the quiet room before anything plays.
    _cal.clear();
    _calibrating = true;
    await Future.delayed(const Duration(milliseconds: 1200));
    _calibrating = false;
    if (_cal.isNotEmpty) _quietBase = _p80(_cal);
  }

  void _onLevel(double v) {
    if (_calibrating) _cal.add(v);
    if (_counting && v > _threshold) _voiceFrames++;
    if (mounted) setState(() => _level = v);
  }

  static double _p80(List<double> xs) {
    final s = [...xs]..sort();
    return s[(s.length * 0.8).floor().clamp(0, s.length - 1)];
  }

  Future<bool> _wait(num ms) async {
    await Future.delayed(Duration(milliseconds: ms.round()));
    return _alive && mounted;
  }

  void _earn(int n) {
    _starsEarned += n;
    ref.read(profileProvider.notifier).update((p) => p.stars += n);
  }

  void _showFlash(String msg) {
    final id = ++_flashId;
    setState(() => _flash = msg);
    Future.delayed(const Duration(milliseconds: 1400), () {
      if (mounted && _flashId == id) setState(() => _flash = null);
    });
  }

  // ------------------------------------------------------------------ flow
  Future<void> _run() async {
    final l = AppLocalizations.of(context);
    final notes = widget.song.notes;

    // Count-in (also measures how loud our own music is through the mic).
    setState(() => _phase = _Phase.countdown);
    _cal.clear();
    _calibrating = true;
    for (var c = 3; c >= 1; c--) {
      setState(() => _countdown = c);
      _audio.note(notes.first.midi, volume: 0.7);
      if (!await _wait(_beatMs * 1.3)) return;
    }
    _calibrating = false;
    if (_cal.isNotEmpty) _musicBase = max(_quietBase, _p80(_cal));

    // Sing every line.
    setState(() => _phase = _Phase.singing);
    for (var i = 0; i < lines.length; i++) {
      final line = lines[i];
      setState(() {
        _line = i;
        _syl = -1;
      });
      if (hint == 0) {
        setState(() => _previewing = true);
        _speech.speak(line.text, lang);
        if (!await _wait(max(1500, line.words.length * 430))) return;
        setState(() => _previewing = false);
      }
      _sayMode = false;
      _voiceFrames = 0;
      _counting = true;
      for (var j = 0; j < line.syllableCount; j++) {
        final n = notes[line.firstNote + j];
        setState(() => _syl = j);
        _audio.note(n.midi, volume: 0.75);
        if (!await _wait(n.beats * _beatMs)) return;
      }
      _counting = false;
      setState(() => _syl = line.syllableCount);
      if (!await _wait(260)) return;
      final voiced = (_mic ?? false) && _voiceFrames >= 3;
      _lineVoiced.add(voiced);
      if (voiced) {
        _earn(1);
        _showFlash(l.greatSinging);
      }
    }
    _audio.winChime();
    if (!await _wait(900)) return;

    // Say the key sentences (speaking, no music).
    setState(() => _phase = _Phase.say);
    for (var k = 0; k < sayLines.length; k++) {
      setState(() {
        _sayIndex = k;
        _listening = false;
        _showSayButtons = false;
      });
      if (hint < 2) {
        _speech.speak(sayLines[k], lang);
        if (!await _wait(
          max(1600, sayLines[k].split(' ').length * 450 + 600),
        )) {
          return;
        }
      }
      setState(() => _listening = true);
      var heard = false;
      if (_mic ?? false) {
        _sayMode = true;
        _voiceFrames = 0;
        _counting = true;
        for (var t = 0; t < 60 && !heard; t++) {
          if (!await _wait(100)) return;
          heard = _voiceFrames >= 4;
        }
        _counting = false;
      }
      if (heard) {
        _sayVoiced++;
        _earn(2);
        _showFlash(l.greatTalking);
        if (!await _wait(1300)) return;
      } else {
        setState(() => _showSayButtons = true);
        _choice = Completer<bool>();
        final said = await _choice!.future;
        _choice = null;
        if (!_alive || !mounted) return;
        if (said) {
          _earn(2);
          _showFlash(l.greatTalking);
          if (!await _wait(900)) return;
        }
      }
    }
    _finish();
  }

  void _answer(bool said) {
    if (_choice == null || _choice!.isCompleted) return;
    setState(() => _showSayButtons = false);
    _choice!.complete(said);
  }

  void _finish() {
    final voiced = _lineVoiced.where((v) => v).length;
    if (_mic ?? false) {
      final ratio = voiced / lines.length;
      ref.read(profileProvider.notifier).update((p) {
        if (ratio >= 0.8) p.hintLevel[_hintKey] = min(2, hint + 1);
        if (ratio < 0.3) p.hintLevel[_hintKey] = max(0, hint - 1);
      });
    }
    if (_mic ?? false) {
      _logSong(); // without a mic, logged after the "Did you sing?" answer
    }
    _audio.sparkle();
    setState(() => _phase = _Phase.done);
  }

  void _logSong() {
    if (_logged) return;
    _logged = true;
    ref
        .read(eventLogProvider)
        .log(
          'sing_song',
          game: SingSay.id,
          data: {
            'song': widget.song.id,
            'lang': lang.name,
            'lines': lines.length,
            'voiced': _lineVoiced.where((v) => v).length,
            'say': sayLines.length,
            'sayVoiced': _sayVoiced,
            'mic': _mic ?? false,
            'hintLevel': hint,
            'selfReportSang': _selfReportSang,
            'stars': _starsEarned,
          },
        );
  }

  // ------------------------------------------------------------------ UI
  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final soft = ref.read(profileProvider).effectsSoft;
    return AppScreen(
      child: Stack(
        children: [
          if (_phase == _Phase.done && !soft)
            const Positioned.fill(child: Confetti()),
          Column(
            children: [
              Row(
                children: [
                  HomeBtn(onBeforeLeave: _speech.stop),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Center(
                      child: Pill(
                        child: Text(
                          '${widget.song.emoji} ${widget.song.title[lang]}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  const StarsPill(),
                ],
              ),
              const SizedBox(height: 10),
              SizedBox(
                height: 54,
                child: _flash == null
                    ? null
                    : BounceOnChange(
                        value: _flashId,
                        child: Pill(
                          color: const Color(0xFFFFD600),
                          child: Text(
                            _flash!,
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                              color: AppColors.ink,
                            ),
                          ),
                        ),
                      ),
              ),
              Expanded(
                child: Center(child: SingleChildScrollView(child: _body(l))),
              ),
              if (_mic == true && _phase != _Phase.done)
                _VoiceOrb(level: _level, hot: _counting && _level > _threshold),
              if (_mic == false && _phase == _Phase.ready)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    l.micOff,
                    style: const TextStyle(
                      color: AppColors.muted,
                      fontSize: 16,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _body(AppLocalizations l) {
    switch (_phase) {
      case _Phase.ready:
        return Column(
          children: [
            Bob(
              child: Text(
                widget.song.emoji,
                style: const TextStyle(fontSize: 110),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              widget.song.title[lang]!,
              style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 28),
            StartCueButton(
              label: l.letsSing,
              cueContext: 'sing',
              game: SingSay.id,
              onStart: _run,
            ),
          ],
        );
      case _Phase.countdown:
        return Column(
          children: [
            Text(
              l.getReady,
              style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800),
            ),
            BounceOnChange(
              value: _countdown,
              child: Text(
                '$_countdown',
                style: const TextStyle(
                  fontSize: 140,
                  fontWeight: FontWeight.w900,
                  color: Pure.orange,
                ),
              ),
            ),
          ],
        );
      case _Phase.singing:
        return _lyrics(l);
      case _Phase.say:
        return Column(
          children: [
            Text(
              l.sayRound,
              style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 18),
            Container(
              constraints: const BoxConstraints(maxWidth: 640),
              padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 22),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(26),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x55000000),
                    blurRadius: 20,
                    offset: Offset(0, 8),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      sayLines[max(0, _sayIndex)],
                      style: const TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.w900,
                        color: AppColors.ink,
                      ),
                    ),
                  ),
                  IconBtn(
                    icon: '🔊',
                    light: true,
                    semantic: 'Listen',
                    onPressed: () =>
                        _speech.speak(sayLines[max(0, _sayIndex)], lang),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            if (_listening)
              Text(
                l.yourTurn,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                ),
              ),
            if (_showSayButtons) ...[
              const SizedBox(height: 16),
              Wrap(
                spacing: 14,
                runSpacing: 14,
                alignment: WrapAlignment.center,
                children: [
                  BigButton(
                    label: l.saidIt,
                    primary: true,
                    onPressed: () => _answer(true),
                  ),
                  BigButton(label: l.skip, onPressed: () => _answer(false)),
                ],
              ),
            ],
          ],
        );
      case _Phase.done:
        final voiced = _lineVoiced.where((v) => v).length;
        return Column(
          children: [
            const Bob(child: Text('🎉', style: TextStyle(fontSize: 96))),
            Text(
              l.songDone,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 8),
            if (_mic ?? false)
              Text(
                l.linesSung(voiced, lines.length),
                style: const TextStyle(fontSize: 20, color: AppColors.muted),
              )
            else if (_selfReportSang == null) ...[
              Text(l.didYouSing, style: const TextStyle(fontSize: 22)),
              const SizedBox(height: 12),
              Wrap(
                spacing: 14,
                runSpacing: 14,
                alignment: WrapAlignment.center,
                children: [
                  BigButton(
                    label: l.iSang,
                    primary: true,
                    onPressed: () {
                      _earn(3);
                      setState(() => _selfReportSang = true);
                      _logSong();
                    },
                  ),
                  BigButton(
                    label: l.skip,
                    onPressed: () {
                      setState(() => _selfReportSang = false);
                      _logSong();
                    },
                  ),
                ],
              ),
            ],
            const SizedBox(height: 10),
            Text(
              '+$_starsEarned ⭐',
              style: const TextStyle(
                fontSize: 34,
                fontWeight: FontWeight.w900,
                color: Pure.orange,
              ),
            ),
            const SizedBox(height: 22),
            Wrap(
              spacing: 14,
              runSpacing: 14,
              alignment: WrapAlignment.center,
              children: [
                BigButton(
                  label: l.singAgain,
                  primary: true,
                  onPressed: () => Navigator.of(
                    context,
                  ).pushReplacement(fadeRoute(SingScreen(song: widget.song))),
                ),
                BigButton(
                  label: l.otherSongs,
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ],
        );
    }
  }

  Widget _lyrics(AppLocalizations l) {
    TextSpan span(LyricLine line, {required bool current, double size = 36}) {
      final spans = <InlineSpan>[];
      var k = 0;
      for (var w = 0; w < line.words.length; w++) {
        final word = line.words[w];
        final cloze =
            current && hint >= 2 && w == line.words.length - 1 && k > _syl;
        if (cloze) {
          spans.add(
            TextSpan(
              text: '＿' * max(2, word.join().length ~/ 2),
              style: TextStyle(
                fontSize: size,
                color: AppColors.text.withValues(alpha: 0.5),
              ),
            ),
          );
          k += word.length;
        } else {
          for (final s in word) {
            final sung = current && k < _syl;
            final now = current && k == _syl;
            spans.add(
              TextSpan(
                text: s,
                style: TextStyle(
                  fontSize: now ? size * 1.18 : size,
                  fontWeight: FontWeight.w900,
                  color: !current
                      ? AppColors.text.withValues(alpha: 0.45)
                      : (now
                            ? Pure.red
                            : (sung
                                  ? Pure.blue
                                  : AppColors.text.withValues(alpha: 0.8))),
                  shadows: now
                      ? const [Shadow(color: Color(0xFFFFD600), blurRadius: 14)]
                      : null,
                ),
              ),
            );
            k++;
          }
        }
        if (w < line.words.length - 1) {
          spans.add(
            TextSpan(
              text: ' ',
              style: TextStyle(fontSize: size),
            ),
          );
        }
      }
      return TextSpan(children: spans);
    }

    final cur = lines[max(0, _line)];
    return Column(
      children: [
        Pill(
          color: _previewing
              ? const Color(0x552979FF)
              : const Color(0x55FF1744),
          child: Text(
            _previewing ? '👂 ${l.listenFirst}' : l.singNow,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
          ),
        ),
        const SizedBox(height: 22),
        Container(
          constraints: const BoxConstraints(maxWidth: 720),
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 26),
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: const [
              BoxShadow(
                color: AppColors.shadow,
                blurRadius: 16,
                offset: Offset(0, 6),
              ),
            ],
            borderRadius: BorderRadius.circular(28),
            border: Border.all(
              color: Pure.blue.withValues(alpha: 0.35),
              width: 3,
            ),
          ),
          child: Column(
            children: [
              Text.rich(span(cur, current: true), textAlign: TextAlign.center),
              if (_line + 1 < lines.length) ...[
                const SizedBox(height: 18),
                Text.rich(
                  span(lines[_line + 1], current: false, size: 22),
                  textAlign: TextAlign.center,
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 18),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (var i = 0; i < lines.length; i++)
              Container(
                width: 14,
                height: 14,
                margin: const EdgeInsets.symmetric(horizontal: 4),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: i < _lineVoiced.length
                      ? (_lineVoiced[i]
                            ? Pure.green
                            : AppColors.text.withValues(alpha: 0.35))
                      : (i == _line
                            ? Pure.blue
                            : AppColors.text.withValues(alpha: 0.12)),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

/// Glowing mic orb that grows with the child's voice.
class _VoiceOrb extends StatelessWidget {
  const _VoiceOrb({required this.level, required this.hot});
  final double level;
  final bool hot;

  @override
  Widget build(BuildContext context) {
    final size = 70 + 50 * level;
    return SizedBox(
      height: 130,
      child: Center(
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 100),
          width: size,
          height: size,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: hot
                  ? const [Color(0xFFFFF59D), Color(0xFFFF1744)]
                  : [Colors.white, Pure.blue.withValues(alpha: 0.35)],
            ),
            boxShadow: [
              if (hot)
                BoxShadow(
                  color: const Color(0xFFFFD600).withValues(alpha: 0.8),
                  blurRadius: 30,
                  spreadRadius: 6,
                ),
            ],
          ),
          child: Text(
            hot ? '✨' : '🎤',
            style: TextStyle(fontSize: 30 + 14 * level),
          ),
        ),
      ),
    );
  }
}
