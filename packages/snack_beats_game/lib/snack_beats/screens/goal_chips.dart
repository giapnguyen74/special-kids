import 'package:flutter/material.dart';
import 'package:sk_core/core/content/foods.dart';
import 'package:sk_core/core/ui/effects.dart';
import 'package:sk_core/core/ui/palette.dart';
import 'package:sk_core/core/ui/theme.dart';

import '../levels.dart';

class GoalItem {
  const GoalItem(this.emoji, this.left);
  final String emoji;
  final int left;
}

/// Goal chips for a level: fruits to collect + obstacles to clear.
List<GoalItem> goalItems(
  SnackLevel lv, {
  List<int>? foodsLeft,
  int? ice,
  int? walls,
  int? mud,
}) => [
  for (var i = 0; i < lv.goals.length; i++)
    GoalItem(foods[lv.goals[i].food].emoji, foodsLeft?[i] ?? lv.goals[i].n),
  if (lv.ice > 0) GoalItem('🧊', ice ?? lv.ice),
  if (lv.walls > 0) GoalItem('🧱', walls ?? lv.walls),
  if (lv.mud > 0) GoalItem('🟫', mud ?? lv.mud),
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
              Text(it.emoji, style: const TextStyle(fontSize: 28)),
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
