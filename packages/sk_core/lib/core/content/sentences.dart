import 'foods.dart';
import 'lang.dart';

/// Request sentences that grow longer level by level. {F} = food (request form), {FP} = plural.
const sentenceTemplates = <Map<Lang, List<String>>>[
  {
    Lang.en: ['I', 'want', '{F}'],
    Lang.vi: ['Tôi', 'muốn', '{F}'],
  },
  {
    Lang.en: ['I', 'want', '{F}', 'please'],
    Lang.vi: ['Tôi', 'muốn', 'ăn', '{F}'],
  },
  {
    Lang.en: ['Can', 'I', 'have', '{F}', 'please'],
    Lang.vi: ['Cho', 'tôi', 'xin', '{F}', 'ạ'],
  },
  {
    Lang.en: ['I', 'would', 'like', '{F}', 'please'],
    Lang.vi: ['Con', 'muốn', 'ăn', '{F}', 'ạ'],
  },
  {
    Lang.en: ['I', 'am', 'hungry,', 'I', 'want', '{F}'],
    Lang.vi: ['Con', 'đói', 'rồi,', 'con', 'muốn', 'ăn', '{F}'],
  },
  {
    Lang.en: ['Mom,', 'can', 'I', 'have', '{F}', 'please'],
    Lang.vi: ['Mẹ', 'ơi,', 'cho', 'con', 'ăn', '{F}', 'ạ'],
  },
  {
    Lang.en: ['Thank', 'you,', 'I', 'love', '{FP}'],
    Lang.vi: ['Cảm ơn,', 'con', 'thích', '{F}', 'lắm'],
  },
  {
    Lang.en: ['Dad,', 'I', 'would', 'like', '{F}', 'please'],
    Lang.vi: ['Bố', 'ơi,', 'con', 'muốn', 'ăn', '{F}', 'ạ'],
  },
];

const distractors = {
  Lang.en: ['you', 'go', 'no', 'is'],
  Lang.vi: ['bạn', 'đi', 'không', 'là'],
};

List<String> buildRequest(int templateIndex, int food, Lang lang) {
  final w = foods[food].words(lang);
  return [
    for (final t
        in sentenceTemplates[templateIndex % sentenceTemplates.length][lang]!)
      t == '{F}' ? w.ask : (t == '{FP}' ? w.plural : t),
  ];
}
