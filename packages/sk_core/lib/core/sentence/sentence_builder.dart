import 'dart:async';

import 'package:flutter/material.dart';

import '../ui/palette.dart';
import '../ui/theme.dart';

class SentenceResult {
  SentenceResult({
    required this.words,
    required this.wrong,
    required this.hints,
  });
  final List<String> words;
  final int wrong, hints;
  int get wordCount => words.join(' ').split(RegExp(r'\s+')).length;
  bool get perfect => wrong == 0 && hints == 0;
}

/// Reusable "build the sentence from word tiles" exercise (used by any game).
///
/// Help fades by [hintLevel]: 0 = whole sentence shown as ghost text, 1 = first word only, 2 = nothing.
/// Errorless learning: the child is never left stuck.
///  - 1 wrong tap  -> the correct next tile glows (counted as a hint)
///  - 3 wrong taps on the same word -> the app places that word itself and reads it out
///  - 8 s without a tap -> the correct tile glows
class SentenceBuilder extends StatefulWidget {
  const SentenceBuilder({
    super.key,
    required this.words,
    required this.hintLevel,
    required this.onDone,
    this.distractor,
    this.onWordPlaced,
    this.onWrong,
    this.hintsUsedExternally = 0,
  });

  final List<String> words;
  final String? distractor;
  final int hintLevel;
  final int hintsUsedExternally;
  final void Function(String word, int index)? onWordPlaced;
  final VoidCallback? onWrong;
  final void Function(SentenceResult result) onDone;

  @override
  State<SentenceBuilder> createState() => _SentenceBuilderState();
}

class _WordTile {
  _WordTile(this.word);
  final String word;
  bool used = false;
}

class _SentenceBuilderState extends State<SentenceBuilder> {
  late final List<_WordTile> _tiles;
  int _next = 0, _wrong = 0, _wrongStreak = 0, _hints = 0;
  int? _glow, _shake;
  Timer? _idle;
  bool _finished = false;

  @override
  void initState() {
    super.initState();
    _tiles = [
      for (final w in widget.words) _WordTile(w),
      if (widget.distractor != null) _WordTile(widget.distractor!),
    ]..shuffle();
    _resetIdle();
  }

  @override
  void dispose() {
    _idle?.cancel();
    super.dispose();
  }

  void _resetIdle() {
    _idle?.cancel();
    _idle = Timer(const Duration(seconds: 8), () {
      if (mounted && !_finished) _glowNext();
    });
  }

  void _glowNext() {
    final i = _tiles.indexWhere(
      (t) => !t.used && t.word == widget.words[_next],
    );
    if (i >= 0) {
      setState(() {
        _glow = i;
        _hints++;
      });
    }
  }

  void _tapTile(int i) {
    final tile = _tiles[i];
    if (tile.used || _finished) return;
    _resetIdle();
    if (tile.word == widget.words[_next]) {
      _place(i);
    } else {
      setState(() {
        _wrong++;
        _wrongStreak++;
        _shake = i;
      });
      widget.onWrong?.call();
      Future.delayed(const Duration(milliseconds: 350), () {
        if (mounted) setState(() => _shake = null);
      });
      if (_wrongStreak >= 3) {
        // Never stuck: put the right word in for the child.
        final right = _tiles.indexWhere(
          (t) => !t.used && t.word == widget.words[_next],
        );
        if (right >= 0) {
          _hints++;
          Future.delayed(const Duration(milliseconds: 400), () {
            if (mounted && !_finished) _place(right);
          });
        }
      } else if (_glow == null) {
        _glowNext();
      }
    }
  }

  void _place(int i) {
    final tile = _tiles[i];
    setState(() {
      tile.used = true;
      _glow = null;
      _wrongStreak = 0;
    });
    widget.onWordPlaced?.call(tile.word, _next);
    _next++;
    if (_next == widget.words.length) {
      _finished = true;
      _idle?.cancel();
      widget.onDone(
        SentenceResult(
          words: widget.words,
          wrong: _wrong,
          hints: _hints + widget.hintsUsedExternally,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final h = widget.hintLevel;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 10,
          runSpacing: 10,
          children: [
            for (var i = 0; i < widget.words.length; i++)
              _Slot(
                filled: i < _next,
                text: i < _next
                    ? widget.words[i]
                    : ((h == 0 || (h == 1 && i == 0)) ? widget.words[i] : ''),
              ),
          ],
        ),
        const SizedBox(height: 28),
        if (!_finished)
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 12,
            runSpacing: 12,
            children: [
              for (var i = 0; i < _tiles.length; i++)
                _TileButton(
                  key: ValueKey('word-tile-$i-${_tiles[i].word}'),
                  word: _tiles[i].word,
                  hidden: _tiles[i].used,
                  glow: _glow == i,
                  shake: _shake == i,
                  onTap: () => _tapTile(i),
                ),
            ],
          ),
      ],
    );
  }
}

class _Slot extends StatelessWidget {
  const _Slot({required this.filled, required this.text});
  final bool filled;
  final String text;
  @override
  Widget build(BuildContext context) => AnimatedContainer(
    duration: const Duration(milliseconds: 200),
    constraints: const BoxConstraints(minWidth: 84, minHeight: 64),
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    decoration: BoxDecoration(
      color: filled
          ? Pure.green.withValues(alpha: .18)
          : Colors.white.withValues(alpha: .6),
      borderRadius: BorderRadius.circular(16),
      border: Border.all(
        color: filled ? Pure.green : AppColors.ink.withValues(alpha: 0.3),
        width: 3,
      ),
    ),
    child: Text(
      text,
      textAlign: TextAlign.center,
      style: TextStyle(
        fontSize: 26,
        fontWeight: FontWeight.w800,
        color: filled ? AppColors.ink : AppColors.ink.withValues(alpha: 0.35),
      ),
    ),
  );
}

class _TileButton extends StatelessWidget {
  const _TileButton({
    super.key,
    required this.word,
    required this.hidden,
    required this.glow,
    required this.shake,
    required this.onTap,
  });
  final String word;
  final bool hidden, glow, shake;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Visibility(
      visible: !hidden,
      maintainSize: true,
      maintainAnimation: true,
      maintainState: true,
      child: Semantics(
        button: true,
        label: word,
        child: GestureDetector(
          onTap: onTap,
          child: TweenAnimationBuilder<double>(
            key: ValueKey(shake),
            tween: Tween(begin: 0, end: shake ? 1 : 0),
            duration: const Duration(milliseconds: 350),
            builder: (_, v, child) => Transform.translate(
              offset: Offset(shake ? 8 * (v < .5 ? -1 : 1) * (1 - v) : 0, 0),
              child: child,
            ),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              // Size to the word (no `alignment`, which would stretch the tile to full width).
              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 13),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  const BoxShadow(
                    color: Color(0xFF90A4C8),
                    offset: Offset(0, 5),
                  ),
                  if (glow)
                    BoxShadow(
                      color: AppColors.accent.withValues(alpha: .9),
                      blurRadius: 30,
                      spreadRadius: 10,
                    ),
                ],
              ),
              child: Text(
                word,
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  color: AppColors.ink,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
