import 'dart:ui';

import '../ui/palette.dart';

import 'lang.dart';

class FoodWords {
  const FoodWords({
    required this.name,
    String? plural,
    String? ask,
    this.count1,
    String? count,
  }) : plural = plural ?? name,
       ask = ask ?? name,
       count = count ?? plural ?? name;
  final String name, plural, ask, count;
  final String? count1;
}

class Food {
  const Food(this.emoji, this.color, this.en, this.vi);
  final String emoji;
  final Color color;
  final FoodWords en, vi;
  FoodWords words(Lang l) => l == Lang.vi ? vi : en;
}

/// Board pieces: one fruit per standard color, so pieces are told apart instantly (like candy).
const foods = <Food>[
  Food(
    '🍓',
    Pure.red,
    FoodWords(name: 'strawberry', plural: 'strawberries', ask: 'strawberries'),
    FoodWords(name: 'dâu tây', count: 'quả dâu tây'),
  ),
  Food(
    '🍏',
    Pure.green,
    FoodWords(
      name: 'green apple',
      plural: 'green apples',
      ask: 'a green apple',
    ),
    FoodWords(name: 'táo xanh', count: 'quả táo xanh'),
  ),
  Food(
    '🫐',
    Pure.blue,
    FoodWords(name: 'blueberry', plural: 'blueberries', ask: 'blueberries'),
    FoodWords(name: 'việt quất', count: 'quả việt quất'),
  ),
  Food(
    '🍌',
    Pure.yellow,
    FoodWords(name: 'banana', plural: 'bananas', ask: 'a banana'),
    FoodWords(name: 'chuối', count: 'quả chuối'),
  ),
  Food(
    '🍊',
    Pure.orange,
    FoodWords(name: 'orange', plural: 'oranges', ask: 'an orange'),
    FoodWords(name: 'cam', count: 'quả cam'),
  ),
  Food(
    '🍇',
    Pure.purple,
    FoodWords(
      name: 'grapes',
      ask: 'grapes',
      count1: 'bunch of grapes',
      count: 'bunches of grapes',
    ),
    FoodWords(name: 'nho', count: 'chùm nho'),
  ),
];

const customers = ['🧑', '👩', '👨', '👵', '🧔', '👩‍🦱', '👴', '🧑‍🦱'];

class FoodGoal {
  FoodGoal(this.food, this.n);
  final int food, n;
}

String goalSentence(List<FoodGoal> goals, Lang lang) {
  if (lang == Lang.vi) {
    return 'Xin chào! Tôi cần ${goals.map((g) => '${g.n} ${foods[g.food].vi.count}').join(' và ')}.';
  }
  return 'Hi! I need ${goals.map((g) {
    final w = foods[g.food].en;
    return '${g.n} ${g.n == 1 ? (w.count1 ?? w.name) : w.count}';
  }).join(' and ')}.';
}
