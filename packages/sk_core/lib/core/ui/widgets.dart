import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../content/lang.dart';
import '../progress/event_log.dart';
import '../progress/profile.dart';
import 'palette.dart';
import 'theme.dart';

/// Large, high-contrast button with a press animation. [glow] 0..1 drives the start-cue glow.
class BigButton extends StatefulWidget {
  const BigButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.primary = false,
    this.big = false,
    this.subtitle,
    this.glow = 0,
    this.showHand = false,
    this.light = false,
  });

  final String label;
  final String? subtitle;
  final VoidCallback? onPressed;
  final bool primary, big, showHand, light;
  final double glow;

  @override
  State<BigButton> createState() => _BigButtonState();
}

class _BigButtonState extends State<BigButton> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final bg = widget.primary
        ? AppColors.accent
        : (widget.light ? AppColors.cardSoft : AppColors.glass2);
    final fg = widget.primary
        ? AppColors.accentInk
        : (widget.light ? AppColors.ink : AppColors.text);
    final button = AnimatedScale(
      scale: _down ? .96 : 1,
      duration: const Duration(milliseconds: 90),
      child: Container(
        constraints: BoxConstraints(
          minHeight: widget.big ? 84 : 60,
          minWidth: widget.big ? 240 : 0,
        ),
        padding: EdgeInsets.symmetric(
          horizontal: widget.big ? 48 : 24,
          vertical: widget.big ? 18 : 12,
        ),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(widget.big ? 30 : 18),
          boxShadow: [
            if (widget.primary)
              const BoxShadow(
                color: AppColors.accentShadow,
                offset: Offset(0, 6),
              )
            else
              const BoxShadow(
                color: AppColors.shadow,
                blurRadius: 10,
                offset: Offset(0, 4),
              ),
            if (widget.glow > 0)
              BoxShadow(
                // Orange glow: visible on the light sky background.
                color: Pure.orange.withValues(alpha: .8 * widget.glow),
                blurRadius: 40 * widget.glow,
                spreadRadius: 12 * widget.glow,
              ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              widget.label,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: widget.big ? 34 : 22,
                fontWeight: FontWeight.w800,
                color: fg,
              ),
            ),
            if (widget.subtitle != null)
              Text(
                widget.subtitle!,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: fg.withValues(alpha: .75),
                ),
              ),
          ],
        ),
      ),
    );
    return Semantics(
      button: true,
      label: widget.label,
      child: GestureDetector(
        onTapDown: (_) => setState(() => _down = true),
        onTapCancel: () => setState(() => _down = false),
        onTapUp: (_) => setState(() => _down = false),
        onTap: widget.onPressed,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            button,
            if (widget.showHand)
              const Positioned(right: -6, bottom: -52, child: _BouncingHand()),
          ],
        ),
      ),
    );
  }
}

class _BouncingHand extends StatefulWidget {
  const _BouncingHand();
  @override
  State<_BouncingHand> createState() => _BouncingHandState();
}

class _BouncingHandState extends State<_BouncingHand>
    with SingleTickerProviderStateMixin {
  late final _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 600),
  )..repeat(reverse: true);
  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _c,
    builder: (_, child) =>
        Transform.translate(offset: Offset(0, -12 * _c.value), child: child),
    child: const Text('👆', style: TextStyle(fontSize: 46)),
  );
}

class IconBtn extends StatelessWidget {
  const IconBtn({
    super.key,
    required this.icon,
    required this.onPressed,
    this.light = false,
    this.semantic,
  });
  final String icon;
  final VoidCallback onPressed;
  final bool light;
  final String? semantic;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: semantic,
    child: GestureDetector(
      onTap: onPressed,
      child: Container(
        width: 56,
        height: 56,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: light ? AppColors.cardSoft : AppColors.glass2,
          boxShadow: light
              ? null
              : const [
                  BoxShadow(
                    color: AppColors.shadow,
                    blurRadius: 10,
                    offset: Offset(0, 4),
                  ),
                ],
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          icon,
          style: TextStyle(
            fontSize: 26,
            color: light ? AppColors.ink : AppColors.text,
          ),
        ),
      ),
    ),
  );
}

/// Home button: always returns to the hub.
class HomeBtn extends StatelessWidget {
  const HomeBtn({super.key, this.onBeforeLeave});
  final VoidCallback? onBeforeLeave;
  @override
  Widget build(BuildContext context) => IconBtn(
    icon: '⌂',
    semantic: 'Home',
    onPressed: () {
      onBeforeLeave?.call();
      Navigator.of(context).popUntil((r) => r.isFirst);
    },
  );
}

class StarsPill extends ConsumerWidget {
  const StarsPill({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stars = ref.watch(profileProvider.select((p) => p.stars));
    return Pill(
      child: Text(
        '⭐ $stars',
        style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
      ),
    );
  }
}

class Pill extends StatelessWidget {
  const Pill({super.key, required this.child, this.color = AppColors.glass});
  final Widget child;
  final Color color;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    decoration: BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(999),
      boxShadow: const [
        BoxShadow(color: AppColors.shadow, blurRadius: 8, offset: Offset(0, 3)),
      ],
    ),
    child: child,
  );
}

class LangToggle extends ConsumerWidget {
  const LangToggle({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lang = ref.watch(profileProvider.select((p) => p.lang));
    Widget opt(Lang l, String label) {
      final on = l == lang;
      return GestureDetector(
        onTap: () {
          ref.read(profileProvider.notifier).update((p) => p.lang = l);
          ref.read(eventLogProvider).log('lang', data: {'lang': l.name});
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
          decoration: BoxDecoration(
            color: on ? Pure.blue : Colors.transparent,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: on ? Colors.white : AppColors.muted,
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.glass,
        borderRadius: BorderRadius.circular(999),
        boxShadow: const [
          BoxShadow(
            color: AppColors.shadow,
            blurRadius: 8,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [opt(Lang.en, 'EN'), opt(Lang.vi, 'VI')],
      ),
    );
  }
}

/// White speech bubble with a replay (🔊) button.
class SpeechBubble extends StatelessWidget {
  const SpeechBubble({super.key, required this.text, this.onSpeak});
  final String text;
  final VoidCallback? onSpeak;
  @override
  Widget build(BuildContext context) => Container(
    constraints: const BoxConstraints(maxWidth: 640),
    padding: const EdgeInsets.fromLTRB(24, 16, 10, 16),
    decoration: BoxDecoration(
      color: AppColors.card,
      borderRadius: BorderRadius.circular(24),
      boxShadow: const [
        BoxShadow(
          color: AppColors.shadow,
          blurRadius: 14,
          offset: Offset(0, 5),
        ),
      ],
    ),
    child: Row(
      children: [
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w700,
              color: AppColors.ink,
            ),
          ),
        ),
        if (onSpeak != null) ...[
          const SizedBox(width: 8),
          IconBtn(
            icon: '🔊',
            light: true,
            semantic: 'Listen',
            onPressed: onSpeak!,
          ),
        ],
      ],
    ),
  );
}

/// Press-and-hold button (keeps parent areas away from the child). Fills while holding.
class HoldButton extends StatefulWidget {
  const HoldButton({
    super.key,
    required this.label,
    required this.onComplete,
    this.duration = const Duration(milliseconds: 1500),
  });
  final String label;
  final VoidCallback onComplete;
  final Duration duration;
  @override
  State<HoldButton> createState() => _HoldButtonState();
}

class _HoldButtonState extends State<HoldButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: widget.duration)
        ..addStatusListener((s) {
          if (s == AnimationStatus.completed) {
            _c.value = 0;
            widget.onComplete();
          }
        });

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTapDown: (_) => _c.forward(from: 0),
    onTapUp: (_) => _c.value < 1 ? _c.reverse() : null,
    onTapCancel: () => _c.reverse(),
    child: ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: AnimatedBuilder(
        animation: _c,
        builder: (_, _) => Stack(
          children: [
            Positioned.fill(
              child: FractionallySizedBox(
                alignment: Alignment.centerLeft,
                widthFactor: _c.value,
                child: ColoredBox(color: Pure.blue.withValues(alpha: 0.3)),
              ),
            ),
            Container(
              color: AppColors.glass,
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
              child: Text(
                widget.label,
                style: const TextStyle(fontSize: 16, color: AppColors.muted),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

/// Top toast for praise messages.
void showToast(BuildContext context, String message) {
  final overlay = Overlay.maybeOf(context, rootOverlay: true);
  if (overlay == null) return;
  late OverlayEntry entry;
  entry = OverlayEntry(
    builder: (_) => _Toast(message: message, onDone: () => entry.remove()),
  );
  overlay.insert(entry);
}

class _Toast extends StatefulWidget {
  const _Toast({required this.message, required this.onDone});
  final String message;
  final VoidCallback onDone;
  @override
  State<_Toast> createState() => _ToastState();
}

class _ToastState extends State<_Toast> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 300),
  );
  @override
  void initState() {
    super.initState();
    _c.forward();
    Future.delayed(const Duration(milliseconds: 2400), () async {
      if (!mounted) return;
      await _c.reverse();
      widget.onDone();
    });
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Positioned(
    top: MediaQuery.paddingOf(context).top + 16,
    left: 0,
    right: 0,
    child: IgnorePointer(
      child: SlideTransition(
        position: Tween(
          begin: const Offset(0, -2),
          end: Offset.zero,
        ).animate(CurvedAnimation(parent: _c, curve: Curves.easeOut)),
        child: Center(
          child: Material(
            color: Colors.transparent,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(999),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x4D000000),
                    blurRadius: 30,
                    offset: Offset(0, 10),
                  ),
                ],
              ),
              child: Text(
                widget.message,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: AppColors.ink,
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

/// Gentle bobbing animation (customers, logos).
class Bob extends StatefulWidget {
  const Bob({super.key, required this.child, this.amount = 8});
  final Widget child;
  final double amount;
  @override
  State<Bob> createState() => _BobState();
}

class _BobState extends State<Bob> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1500),
  )..repeat(reverse: true);
  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.disableAnimationsOf(context)) return widget.child;
    return AnimatedBuilder(
      animation: _c,
      builder: (_, child) => Transform.translate(
        offset: Offset(
          0,
          -widget.amount * Curves.easeInOut.transform(_c.value),
        ),
        child: child,
      ),
      child: widget.child,
    );
  }
}

/// Big colorful title: rainbow fill with a dark navy outline (readable on the light sky).
class TitleText extends StatelessWidget {
  const TitleText(this.text, {super.key, this.size = 52});
  final String text;
  final double size;

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(fontSize: size, fontWeight: FontWeight.w900);
    return Stack(
      children: [
        Text(
          text,
          style: style.copyWith(
            foreground: Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = size * 0.14
              ..strokeJoin = StrokeJoin.round
              ..color = AppColors.text,
          ),
        ),
        ShaderMask(
          shaderCallback: (r) => const LinearGradient(
            colors: [Pure.yellow, Pure.orange, Pure.red, Pure.purple],
          ).createShader(r),
          child: Text(text, style: style.copyWith(color: Colors.white)),
        ),
      ],
    );
  }
}

/// The child's avatar + name (set by the parent in the Lessons tab).
class ChildPill extends ConsumerWidget {
  const ChildPill({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final (avatar, name) = ref.watch(
      profileProvider.select((p) => (p.avatar, p.name)),
    );
    return Pill(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(avatar, style: const TextStyle(fontSize: 22)),
          const SizedBox(width: 6),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 110),
            child: Text(
              name,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
  }
}
