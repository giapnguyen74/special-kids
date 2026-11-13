// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Vietnamese (`vi`).
class AppLocalizationsVi extends AppLocalizations {
  AppLocalizationsVi([String locale = 'vi']) : super(locale);

  @override
  String get appTitle => 'Special Kids';

  @override
  String get hubTagline => 'Chơi, học và tạo âm nhạc';

  @override
  String levelN(int n) {
    return 'Màn $n';
  }

  @override
  String get play => 'Chơi';

  @override
  String get start => 'Bắt đầu!';

  @override
  String get myMusic => 'Nhạc của tôi';

  @override
  String get calm => 'Thư giãn';

  @override
  String get parentsHold => 'Phụ huynh (giữ)';

  @override
  String get comingSoon => 'Sắp ra mắt';

  @override
  String get moves => 'Lượt';

  @override
  String get orderDone => 'Hoàn thành đơn! +3 ⭐';

  @override
  String get serve => 'Phục vụ khách ▶';

  @override
  String get almost => 'Gần được rồi! Mình thử lại nhé.';

  @override
  String get tryAgain => 'Thử lại';

  @override
  String get home => 'Trang chủ';

  @override
  String get whatWant =>
      'Cảm ơn bạn! Giờ bạn chọn một món nhé. Bạn muốn ăn gì?';

  @override
  String get makeSentence => 'Ghép thành câu';

  @override
  String get sayIt => 'Đến lượt bạn! Hãy nói to câu này 🎤';

  @override
  String get saidIt => 'Mình đã nói! 🎤';

  @override
  String get skip => 'Bỏ qua';

  @override
  String get selfStart => 'Bạn tự bắt đầu! +1 ⭐';

  @override
  String get newSong => 'Mở khóa bài hát mới!';

  @override
  String get greatJob => 'Giỏi lắm!';

  @override
  String get greatJobStars => 'Giỏi lắm! +3 ⭐';

  @override
  String get nextLevel => 'Màn tiếp ▶';

  @override
  String get locked => 'Chưa mở';

  @override
  String get calmTitle => 'Thư giãn — không mục tiêu';

  @override
  String get breakTitle => 'Bạn chơi giỏi lắm!';

  @override
  String get breakMsg => 'Đến giờ nghỉ rồi. 🎵';

  @override
  String get parentContinue => 'Phụ huynh: giữ để tiếp tục';

  @override
  String get pTitle => 'Bảng theo dõi cho phụ huynh';

  @override
  String get pNote => 'Dữ liệu chỉ lưu trên thiết bị này.';

  @override
  String get pPlayToday => 'Thời gian chơi hôm nay';

  @override
  String get pSelfStarts => 'Tự bắt đầu (không cần gợi ý)';

  @override
  String get pAvgStart => 'Thời gian bắt đầu TB (10 lần gần nhất)';

  @override
  String get pSentences => 'Số câu đã ghép';

  @override
  String get pAvgLen => 'Độ dài câu TB (từ)';

  @override
  String get pNoHint => 'Câu không cần trợ giúp';

  @override
  String get pSpoke => 'Đã nói to';

  @override
  String get pLevels => 'Số màn hoàn thành';

  @override
  String get pWeek => '7 ngày qua';

  @override
  String get pDay => 'Ngày';

  @override
  String get pMin => 'Phút';

  @override
  String get pHelp => 'Mức trợ giúp hiện tại (tự điều chỉnh)';

  @override
  String get pSentHelp => 'Trợ giúp ghép câu';

  @override
  String get helpFull => 'Hiện câu mẫu';

  @override
  String get helpFirst => 'Hiện từ đầu tiên';

  @override
  String get helpNone => 'Không gợi ý';

  @override
  String get pCue => 'Gợi ý bắt đầu xuất hiện sau';

  @override
  String get pSettings => 'Cài đặt';

  @override
  String get pLang => 'Ngôn ngữ';

  @override
  String get pLimit => 'Nghỉ sau';

  @override
  String get pOff => 'Tắt';

  @override
  String minutesN(int n) {
    return '$n phút';
  }

  @override
  String secondsN(String n) {
    return '$n giây';
  }

  @override
  String get pVoices => 'Giọng đọc trên thiết bị';

  @override
  String get pVoiceMissing => 'chưa có — thêm trong cài đặt giọng nói';

  @override
  String get pReset => 'Xóa toàn bộ tiến trình';

  @override
  String get pResetConfirm => 'Xóa toàn bộ tiến trình và lịch sử?';

  @override
  String get cancel => 'Hủy';

  @override
  String get delete => 'Xóa';

  @override
  String get gameSnackBeats => 'Snack Beats';

  @override
  String get gameSnackBeatsDesc => 'Ghép món ăn. Tạo âm nhạc.';

  @override
  String get gameCafe => 'Quán cà phê';

  @override
  String get gameKitchen => 'Nhà bếp';

  @override
  String get gameMyDay => 'Một ngày của tôi';

  @override
  String get gameTalk => 'Bảng giao tiếp';

  @override
  String get praiseNice => 'Tốt!';

  @override
  String get praiseGreat => 'Tuyệt!';

  @override
  String get praiseAwesome => 'Xuất sắc!';

  @override
  String get praiseAmazing => 'Quá đỉnh!';

  @override
  String get pEffects => 'Hiệu ứng hình ảnh';

  @override
  String get effectsFull => 'Đầy đủ (rực rỡ, sinh động)';

  @override
  String get effectsSoft => 'Nhẹ nhàng (dịu hơn, không rung)';

  @override
  String get gameSing => 'Hát & Nói';

  @override
  String get gameSingDesc => 'Hát bài hát. Nói thành câu.';

  @override
  String get chooseSong => 'Chọn bài hát';

  @override
  String get letsSing => 'Cùng hát nào!';

  @override
  String get getReady => 'Chuẩn bị…';

  @override
  String get listenFirst => 'Nghe nhé…';

  @override
  String get singNow => 'Hát nào! 🎤';

  @override
  String get sayRound => 'Giờ mình nói nhé!';

  @override
  String get yourTurn => 'Đến lượt bạn! Nói nhé 🎤';

  @override
  String get greatSinging => 'Hát hay quá! +1 ⭐';

  @override
  String get greatTalking => 'Nói giỏi quá! +2 ⭐';

  @override
  String get didYouSing => 'Bạn có hát theo không?';

  @override
  String get iSang => 'Mình đã hát! 🎤';

  @override
  String get singAgain => 'Hát lại';

  @override
  String get otherSongs => 'Bài khác';

  @override
  String get micOff => 'Micro đang tắt — không sao cả! Cứ hát nhé.';

  @override
  String linesSung(int n, int total) {
    return '$n/$total câu có giọng hát của bạn';
  }

  @override
  String get songDone => 'Bạn đã hát hết bài!';

  @override
  String get pSongs => 'Số bài đã hát';

  @override
  String get pVoiced => 'Câu hát có giọng (ước tính)';

  @override
  String get pSaid => 'Câu đã nói to (ước tính)';

  @override
  String get restartTitle => 'Chơi lại màn này từ đầu?';

  @override
  String get restartYes => 'Chơi lại ↻';

  @override
  String get restartNo => 'Chơi tiếp';

  @override
  String get pSentenceEvery => 'Ghép câu sau màn chơi';

  @override
  String get everyLevel => 'Mỗi màn';

  @override
  String get every2 => '2 màn một lần';

  @override
  String get every3 => '3 màn một lần';

  @override
  String get nextArrow => 'Tiếp ▶';

  @override
  String get extraMoves => '🎁 +5 lượt';

  @override
  String get extraMovesNote => 'Làm một bài nhỏ để được thêm 5 lượt nhé!';

  @override
  String get holdToOpen => 'Nhấn giữ để mở';

  @override
  String get pSpeechSpeed => 'Tốc độ đọc';

  @override
  String get speedSlow => 'Chậm';

  @override
  String get speedMedium => 'Hơi chậm';

  @override
  String get speedNormal => 'Bình thường';

  @override
  String get gameColorBeats => 'Color Beats';

  @override
  String get gameColorBeatsDesc => 'Xếp gạch. Xóa hàng. Tạo âm nhạc.';

  @override
  String tbClearLines(int n) {
    return 'Xóa $n hàng nhé!';
  }

  @override
  String get tbBoardFull => 'Hết chỗ rồi!';

  @override
  String get tbNewBlocks => '🎁 Gạch mới';

  @override
  String get tbNewBlocksNote =>
      'Làm một thử thách nhỏ để có thêm chỗ và chơi tiếp nhé!';

  @override
  String get tbLevelDone => 'Con làm được rồi!';

  @override
  String get tbScore => 'Điểm';

  @override
  String get tbBest => 'Kỷ lục';

  @override
  String get tbHelpCleared => 'Thêm chỗ rồi!';
}
