enum Lang {
  en,
  vi;

  static Lang parse(String? s) => s == 'vi' ? Lang.vi : Lang.en;
  String get ttsCode => this == Lang.vi ? 'vi-VN' : 'en-US';
}
