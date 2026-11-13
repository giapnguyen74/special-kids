import 'package:flutter/material.dart';
import 'package:sk_core/core/ui/effects.dart';
import 'package:sk_core/core/ui/palette.dart';
import 'package:sk_core/core/ui/theme.dart';

import '../engine/grid.dart';
import '../engine/levels.dart';

class GoalItem {
  const GoalItem(this.emoji, this.left);
  final String emoji;
  final int left;
}

/// Lines to clear + gems to collect.
List<GoalItem> goalItems(
  BlockLevel lv, {
  int? linesLeft,
  List<int>? gemsLeft,
}) => [
  if (lv.lines > 0) GoalItem('↔️', linesLeft ?? lv.lines),
  for (var k = 0; k < lv.gems.length; k++)
    if (lv.gems[k] > 0) GoalItem(gemEmojis[k], gemsLeft?[k] ?? lv.gems[k]),
];

class GoalChips extends StatelessWidget {
  const GoalChips({super.key, required this.items});
  final List<GoalItem> items;

  @override
  Widget build(BuildContext context) => Wrap(
    spacing: 8,
    runSpacing: 8,
    alignment: WrapAlignment.center,
    children: [
      for (final it in items)
        AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: it.left == 0 ? Pure.green : AppColors.glass2,
            borderRadius: BorderRadius.circular(16),
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
            children: [
              Text(it.emoji, style: const TextStyle(fontSize: 26)),
              const SizedBox(width: 6),
              BounceOnChange(
                value: it.left,
                child: Text(
                  it.left == 0 ? '✔' : '${it.left}',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: it.left == 0 ? Colors.white : AppColors.text,
                  ),
                ),
              ),
            ],
          ),
        ),
    ],
  );
}
