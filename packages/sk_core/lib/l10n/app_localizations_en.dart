// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Special Kids';

  @override
  String get hubTagline => 'Play, learn, and make music';

  @override
  String levelN(int n) {
    return 'Level $n';
  }

  @override
  String get play => 'Play';

  @override
  String get start => 'Let\'s go!';

  @override
  String get myMusic => 'My Music';

  @override
  String get calm => 'Calm Mode';

  @override
  String get parentsHold => 'Parents (hold)';

  @override
  String get comingSoon => 'Coming soon';

  @override
  String get moves => 'Moves';

  @override
  String get orderDone => 'Order complete! +3 ⭐';

  @override
  String get serve => 'Serve the order ▶';

  @override
  String get almost => 'So close! Let\'s try again.';

  @override
  String get tryAgain => 'Try again';

  @override
  String get home => 'Home';

  @override
  String get whatWant => 'Thank you! Now you pick a treat. What do you want?';

  @override
  String get makeSentence => 'Make the sentence';

  @override
  String get sayIt => 'Your turn! Say it out loud 🎤';

  @override
  String get saidIt => 'I said it! 🎤';

  @override
  String get skip => 'Skip';

  @override
  String get selfStart => 'You started by yourself! +1 ⭐';

  @override
  String get newSong => 'New song unlocked!';

  @override
  String get greatJob => 'Great job!';

  @override
  String get greatJobStars => 'Great job! +3 ⭐';

  @override
  String get nextLevel => 'Next level ▶';

  @override
  String get locked => 'Locked';

  @override
  String get calmTitle => 'Calm — no goals, just relax';

  @override
  String get breakTitle => 'Great playing!';

  @override
  String get breakMsg => 'Time for a break. 🎵';

  @override
  String get parentContinue => 'Parent: hold to continue';

  @override
  String get pTitle => 'Parent dashboard';

  @override
  String get pNote => 'All data stays on this device only.';

  @override
  String get pPlayToday => 'Play time today';

  @override
  String get pSelfStarts => 'Started without a cue';

  @override
  String get pAvgStart => 'Avg. time to start (last 10)';

  @override
  String get pSentences => 'Sentences built';

  @override
  String get pAvgLen => 'Avg. sentence length (words)';

  @override
  String get pNoHint => 'Sentences with no help';

  @override
  String get pSpoke => 'Said it out loud';

  @override
  String get pLevels => 'Levels completed';

  @override
  String get pWeek => 'Last 7 days';

  @override
  String get pDay => 'Day';

  @override
  String get pMin => 'Min';

  @override
  String get pHelp => 'Current help level (adjusts automatically)';

  @override
  String get pSentHelp => 'Sentence help';

  @override
  String get helpFull => 'Full model shown';

  @override
  String get helpFirst => 'First word shown';

  @override
  String get helpNone => 'No hints';

  @override
  String get pCue => 'Start cue appears after';

  @override
  String get pSettings => 'Settings';

  @override
  String get pLang => 'Language';

  @override
  String get pLimit => 'Break after';

  @override
  String get pOff => 'Off';

  @override
  String minutesN(int n) {
    return '$n min';
  }

  @override
  String secondsN(String n) {
    return '$n s';
  }

  @override
  String get pVoices => 'Voices on this device';

  @override
  String get pVoiceMissing => 'missing — add it in device speech settings';

  @override
  String get pReset => 'Reset all progress';

  @override
  String get pResetConfirm => 'Delete all progress and history?';

  @override
  String get cancel => 'Cancel';

  @override
  String get delete => 'Delete';

  @override
  String get gameSnackBeats => 'Snack Beats';

  @override
  String get gameSnackBeatsDesc => 'Match food. Make music.';

  @override
  String get gameCafe => 'Café';

  @override
  String get gameKitchen => 'Kitchen';

  @override
  String get gameMyDay => 'My Day';

  @override
  String get gameTalk => 'Talk Board';

  @override
  String get praiseNice => 'Nice!';

  @override
  String get praiseGreat => 'Great!';

  @override
  String get praiseAwesome => 'Awesome!';

  @override
  String get praiseAmazing => 'Amazing!';

  @override
  String get pEffects => 'Visual effects';

  @override
  String get effectsFull => 'Full (bright & bouncy)';

  @override
  String get effectsSoft => 'Soft (calmer, no shaking)';

  @override
  String get gameSing => 'Sing & Say';

  @override
  String get gameSingDesc => 'Sing songs. Say sentences.';

  @override
  String get chooseSong => 'Choose a song';

  @override
  String get letsSing => 'Let\'s sing!';

  @override
  String get getReady => 'Get ready…';

  @override
  String get listenFirst => 'Listen…';

  @override
  String get singNow => 'Sing! 🎤';

  @override
  String get sayRound => 'Now say it!';

  @override
  String get yourTurn => 'Your turn! Say it 🎤';

  @override
  String get greatSinging => 'Great singing! +1 ⭐';

  @override
  String get greatTalking => 'Great talking! +2 ⭐';

  @override
  String get didYouSing => 'Did you sing along?';

  @override
  String get iSang => 'I sang! 🎤';

  @override
  String get singAgain => 'Sing again';

  @override
  String get otherSongs => 'Other songs';

  @override
  String get micOff => 'Mic is off — that\'s okay! Just sing.';

  @override
  String linesSung(int n, int total) {
    return '$n of $total lines with your voice';
  }

  @override
  String get songDone => 'You sang the whole song!';

  @override
  String get pSongs => 'Songs sung';

  @override
  String get pVoiced => 'Lines sung with voice (est.)';

  @override
  String get pSaid => 'Sentences said aloud (est.)';

  @override
  String get restartTitle => 'Start this level again?';

  @override
  String get restartYes => 'Restart ↻';

  @override
  String get restartNo => 'Keep playing';

  @override
  String get pSentenceEvery => 'Sentence practice after a level';

  @override
  String get everyLevel => 'Every level';

  @override
  String get every2 => 'Every 2 levels';

  @override
  String get every3 => 'Every 3 levels';

  @override
  String get nextArrow => 'Next ▶';

  @override
  String get extraMoves => '🎁 +5 moves';

  @override
  String get extraMovesNote => 'Do a little task to get 5 more moves!';

  @override
  String get holdToOpen => 'Press and hold to open';

  @override
  String get pSpeechSpeed => 'Reading speed';

  @override
  String get speedSlow => 'Slow';

  @override
  String get speedMedium => 'A bit slow';

  @override
  String get speedNormal => 'Normal';

  @override
  String get gameColorBeats => 'Color Beats';

  @override
  String get gameColorBeatsDesc => 'Fit the blocks. Clear lines. Make music.';

  @override
  String tbClearLines(int n) {
    return 'Clear $n lines!';
  }

  @override
  String get tbBoardFull => 'No more space!';

  @override
  String get tbNewBlocks => '🎁 New blocks';

  @override
  String get tbNewBlocksNote =>
      'Do a small challenge to clear space and keep playing!';

  @override
  String get tbLevelDone => 'You did it!';

  @override
  String get tbScore => 'Score';

  @override
  String get tbBest => 'Best';

  @override
  String get tbHelpCleared => 'More space!';
}
