import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_vi.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('vi'),
  ];

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'Special Kids'**
  String get appTitle;

  /// No description provided for @hubTagline.
  ///
  /// In en, this message translates to:
  /// **'Play, learn, and make music'**
  String get hubTagline;

  /// No description provided for @levelN.
  ///
  /// In en, this message translates to:
  /// **'Level {n}'**
  String levelN(int n);

  /// No description provided for @play.
  ///
  /// In en, this message translates to:
  /// **'Play'**
  String get play;

  /// No description provided for @start.
  ///
  /// In en, this message translates to:
  /// **'Let\'s go!'**
  String get start;

  /// No description provided for @myMusic.
  ///
  /// In en, this message translates to:
  /// **'My Music'**
  String get myMusic;

  /// No description provided for @calm.
  ///
  /// In en, this message translates to:
  /// **'Calm Mode'**
  String get calm;

  /// No description provided for @parentsHold.
  ///
  /// In en, this message translates to:
  /// **'Parents (hold)'**
  String get parentsHold;

  /// No description provided for @comingSoon.
  ///
  /// In en, this message translates to:
  /// **'Coming soon'**
  String get comingSoon;

  /// No description provided for @moves.
  ///
  /// In en, this message translates to:
  /// **'Moves'**
  String get moves;

  /// No description provided for @orderDone.
  ///
  /// In en, this message translates to:
  /// **'Order complete! +3 ⭐'**
  String get orderDone;

  /// No description provided for @serve.
  ///
  /// In en, this message translates to:
  /// **'Serve the order ▶'**
  String get serve;

  /// No description provided for @almost.
  ///
  /// In en, this message translates to:
  /// **'So close! Let\'s try again.'**
  String get almost;

  /// No description provided for @tryAgain.
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get tryAgain;

  /// No description provided for @home.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get home;

  /// No description provided for @whatWant.
  ///
  /// In en, this message translates to:
  /// **'Thank you! Now you pick a treat. What do you want?'**
  String get whatWant;

  /// No description provided for @makeSentence.
  ///
  /// In en, this message translates to:
  /// **'Make the sentence'**
  String get makeSentence;

  /// No description provided for @sayIt.
  ///
  /// In en, this message translates to:
  /// **'Your turn! Say it out loud 🎤'**
  String get sayIt;

  /// No description provided for @saidIt.
  ///
  /// In en, this message translates to:
  /// **'I said it! 🎤'**
  String get saidIt;

  /// No description provided for @skip.
  ///
  /// In en, this message translates to:
  /// **'Skip'**
  String get skip;

  /// No description provided for @selfStart.
  ///
  /// In en, this message translates to:
  /// **'You started by yourself! +1 ⭐'**
  String get selfStart;

  /// No description provided for @newSong.
  ///
  /// In en, this message translates to:
  /// **'New song unlocked!'**
  String get newSong;

  /// No description provided for @greatJob.
  ///
  /// In en, this message translates to:
  /// **'Great job!'**
  String get greatJob;

  /// No description provided for @greatJobStars.
  ///
  /// In en, this message translates to:
  /// **'Great job! +3 ⭐'**
  String get greatJobStars;

  /// No description provided for @nextLevel.
  ///
  /// In en, this message translates to:
  /// **'Next level ▶'**
  String get nextLevel;

  /// No description provided for @locked.
  ///
  /// In en, this message translates to:
  /// **'Locked'**
  String get locked;

  /// No description provided for @calmTitle.
  ///
  /// In en, this message translates to:
  /// **'Calm — no goals, just relax'**
  String get calmTitle;

  /// No description provided for @breakTitle.
  ///
  /// In en, this message translates to:
  /// **'Great playing!'**
  String get breakTitle;

  /// No description provided for @breakMsg.
  ///
  /// In en, this message translates to:
  /// **'Time for a break. 🎵'**
  String get breakMsg;

  /// No description provided for @parentContinue.
  ///
  /// In en, this message translates to:
  /// **'Parent: hold to continue'**
  String get parentContinue;

  /// No description provided for @pTitle.
  ///
  /// In en, this message translates to:
  /// **'Parent dashboard'**
  String get pTitle;

  /// No description provided for @pNote.
  ///
  /// In en, this message translates to:
  /// **'All data stays on this device only.'**
  String get pNote;

  /// No description provided for @pPlayToday.
  ///
  /// In en, this message translates to:
  /// **'Play time today'**
  String get pPlayToday;

  /// No description provided for @pSelfStarts.
  ///
  /// In en, this message translates to:
  /// **'Started without a cue'**
  String get pSelfStarts;

  /// No description provided for @pAvgStart.
  ///
  /// In en, this message translates to:
  /// **'Avg. time to start (last 10)'**
  String get pAvgStart;

  /// No description provided for @pSentences.
  ///
  /// In en, this message translates to:
  /// **'Sentences built'**
  String get pSentences;

  /// No description provided for @pAvgLen.
  ///
  /// In en, this message translates to:
  /// **'Avg. sentence length (words)'**
  String get pAvgLen;

  /// No description provided for @pNoHint.
  ///
  /// In en, this message translates to:
  /// **'Sentences with no help'**
  String get pNoHint;

  /// No description provided for @pSpoke.
  ///
  /// In en, this message translates to:
  /// **'Said it out loud'**
  String get pSpoke;

  /// No description provided for @pLevels.
  ///
  /// In en, this message translates to:
  /// **'Levels completed'**
  String get pLevels;

  /// No description provided for @pWeek.
  ///
  /// In en, this message translates to:
  /// **'Last 7 days'**
  String get pWeek;

  /// No description provided for @pDay.
  ///
  /// In en, this message translates to:
  /// **'Day'**
  String get pDay;

  /// No description provided for @pMin.
  ///
  /// In en, this message translates to:
  /// **'Min'**
  String get pMin;

  /// No description provided for @pHelp.
  ///
  /// In en, this message translates to:
  /// **'Current help level (adjusts automatically)'**
  String get pHelp;

  /// No description provided for @pSentHelp.
  ///
  /// In en, this message translates to:
  /// **'Sentence help'**
  String get pSentHelp;

  /// No description provided for @helpFull.
  ///
  /// In en, this message translates to:
  /// **'Full model shown'**
  String get helpFull;

  /// No description provided for @helpFirst.
  ///
  /// In en, this message translates to:
  /// **'First word shown'**
  String get helpFirst;

  /// No description provided for @helpNone.
  ///
  /// In en, this message translates to:
  /// **'No hints'**
  String get helpNone;

  /// No description provided for @pCue.
  ///
  /// In en, this message translates to:
  /// **'Start cue appears after'**
  String get pCue;

  /// No description provided for @pSettings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get pSettings;

  /// No description provided for @pLang.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get pLang;

  /// No description provided for @pLimit.
  ///
  /// In en, this message translates to:
  /// **'Break after'**
  String get pLimit;

  /// No description provided for @pOff.
  ///
  /// In en, this message translates to:
  /// **'Off'**
  String get pOff;

  /// No description provided for @minutesN.
  ///
  /// In en, this message translates to:
  /// **'{n} min'**
  String minutesN(int n);

  /// No description provided for @secondsN.
  ///
  /// In en, this message translates to:
  /// **'{n} s'**
  String secondsN(String n);

  /// No description provided for @pVoices.
  ///
  /// In en, this message translates to:
  /// **'Voices on this device'**
  String get pVoices;

  /// No description provided for @pVoiceMissing.
  ///
  /// In en, this message translates to:
  /// **'missing — add it in device speech settings'**
  String get pVoiceMissing;

  /// No description provided for @pReset.
  ///
  /// In en, this message translates to:
  /// **'Reset all progress'**
  String get pReset;

  /// No description provided for @pResetConfirm.
  ///
  /// In en, this message translates to:
  /// **'Delete all progress and history?'**
  String get pResetConfirm;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @delete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get delete;

  /// No description provided for @gameSnackBeats.
  ///
  /// In en, this message translates to:
  /// **'Snack Beats'**
  String get gameSnackBeats;

  /// No description provided for @gameSnackBeatsDesc.
  ///
  /// In en, this message translates to:
  /// **'Match food. Make music.'**
  String get gameSnackBeatsDesc;

  /// No description provided for @gameCafe.
  ///
  /// In en, this message translates to:
  /// **'Café'**
  String get gameCafe;

  /// No description provided for @gameKitchen.
  ///
  /// In en, this message translates to:
  /// **'Kitchen'**
  String get gameKitchen;

  /// No description provided for @gameMyDay.
  ///
  /// In en, this message translates to:
  /// **'My Day'**
  String get gameMyDay;

  /// No description provided for @gameTalk.
  ///
  /// In en, this message translates to:
  /// **'Talk Board'**
  String get gameTalk;

  /// No description provided for @praiseNice.
  ///
  /// In en, this message translates to:
  /// **'Nice!'**
  String get praiseNice;

  /// No description provided for @praiseGreat.
  ///
  /// In en, this message translates to:
  /// **'Great!'**
  String get praiseGreat;

  /// No description provided for @praiseAwesome.
  ///
  /// In en, this message translates to:
  /// **'Awesome!'**
  String get praiseAwesome;

  /// No description provided for @praiseAmazing.
  ///
  /// In en, this message translates to:
  /// **'Amazing!'**
  String get praiseAmazing;

  /// No description provided for @pEffects.
  ///
  /// In en, this message translates to:
  /// **'Visual effects'**
  String get pEffects;

  /// No description provided for @effectsFull.
  ///
  /// In en, this message translates to:
  /// **'Full (bright & bouncy)'**
  String get effectsFull;

  /// No description provided for @effectsSoft.
  ///
  /// In en, this message translates to:
  /// **'Soft (calmer, no shaking)'**
  String get effectsSoft;

  /// No description provided for @gameSing.
  ///
  /// In en, this message translates to:
  /// **'Sing & Say'**
  String get gameSing;

  /// No description provided for @gameSingDesc.
  ///
  /// In en, this message translates to:
  /// **'Sing songs. Say sentences.'**
  String get gameSingDesc;

  /// No description provided for @chooseSong.
  ///
  /// In en, this message translates to:
  /// **'Choose a song'**
  String get chooseSong;

  /// No description provided for @letsSing.
  ///
  /// In en, this message translates to:
  /// **'Let\'s sing!'**
  String get letsSing;

  /// No description provided for @getReady.
  ///
  /// In en, this message translates to:
  /// **'Get ready…'**
  String get getReady;

  /// No description provided for @listenFirst.
  ///
  /// In en, this message translates to:
  /// **'Listen…'**
  String get listenFirst;

  /// No description provided for @singNow.
  ///
  /// In en, this message translates to:
  /// **'Sing! 🎤'**
  String get singNow;

  /// No description provided for @sayRound.
  ///
  /// In en, this message translates to:
  /// **'Now say it!'**
  String get sayRound;

  /// No description provided for @yourTurn.
  ///
  /// In en, this message translates to:
  /// **'Your turn! Say it 🎤'**
  String get yourTurn;

  /// No description provided for @greatSinging.
  ///
  /// In en, this message translates to:
  /// **'Great singing! +1 ⭐'**
  String get greatSinging;

  /// No description provided for @greatTalking.
  ///
  /// In en, this message translates to:
  /// **'Great talking! +2 ⭐'**
  String get greatTalking;

  /// No description provided for @didYouSing.
  ///
  /// In en, this message translates to:
  /// **'Did you sing along?'**
  String get didYouSing;

  /// No description provided for @iSang.
  ///
  /// In en, this message translates to:
  /// **'I sang! 🎤'**
  String get iSang;

  /// No description provided for @singAgain.
  ///
  /// In en, this message translates to:
  /// **'Sing again'**
  String get singAgain;

  /// No description provided for @otherSongs.
  ///
  /// In en, this message translates to:
  /// **'Other songs'**
  String get otherSongs;

  /// No description provided for @micOff.
  ///
  /// In en, this message translates to:
  /// **'Mic is off — that\'s okay! Just sing.'**
  String get micOff;

  /// No description provided for @linesSung.
  ///
  /// In en, this message translates to:
  /// **'{n} of {total} lines with your voice'**
  String linesSung(int n, int total);

  /// No description provided for @songDone.
  ///
  /// In en, this message translates to:
  /// **'You sang the whole song!'**
  String get songDone;

  /// No description provided for @pSongs.
  ///
  /// In en, this message translates to:
  /// **'Songs sung'**
  String get pSongs;

  /// No description provided for @pVoiced.
  ///
  /// In en, this message translates to:
  /// **'Lines sung with voice (est.)'**
  String get pVoiced;

  /// No description provided for @pSaid.
  ///
  /// In en, this message translates to:
  /// **'Sentences said aloud (est.)'**
  String get pSaid;

  /// No description provided for @restartTitle.
  ///
  /// In en, this message translates to:
  /// **'Start this level again?'**
  String get restartTitle;

  /// No description provided for @restartYes.
  ///
  /// In en, this message translates to:
  /// **'Restart ↻'**
  String get restartYes;

  /// No description provided for @restartNo.
  ///
  /// In en, this message translates to:
  /// **'Keep playing'**
  String get restartNo;

  /// No description provided for @pSentenceEvery.
  ///
  /// In en, this message translates to:
  /// **'Sentence practice after a level'**
  String get pSentenceEvery;

  /// No description provided for @everyLevel.
  ///
  /// In en, this message translates to:
  /// **'Every level'**
  String get everyLevel;

  /// No description provided for @every2.
  ///
  /// In en, this message translates to:
  /// **'Every 2 levels'**
  String get every2;

  /// No description provided for @every3.
  ///
  /// In en, this message translates to:
  /// **'Every 3 levels'**
  String get every3;

  /// No description provided for @nextArrow.
  ///
  /// In en, this message translates to:
  /// **'Next ▶'**
  String get nextArrow;

  /// No description provided for @extraMoves.
  ///
  /// In en, this message translates to:
  /// **'🎁 +5 moves'**
  String get extraMoves;

  /// No description provided for @extraMovesNote.
  ///
  /// In en, this message translates to:
  /// **'Do a little task to get 5 more moves!'**
  String get extraMovesNote;

  /// No description provided for @holdToOpen.
  ///
  /// In en, this message translates to:
  /// **'Press and hold to open'**
  String get holdToOpen;

  /// No description provided for @pSpeechSpeed.
  ///
  /// In en, this message translates to:
  /// **'Reading speed'**
  String get pSpeechSpeed;

  /// No description provided for @speedSlow.
  ///
  /// In en, this message translates to:
  /// **'Slow'**
  String get speedSlow;

  /// No description provided for @speedMedium.
  ///
  /// In en, this message translates to:
  /// **'A bit slow'**
  String get speedMedium;

  /// No description provided for @speedNormal.
  ///
  /// In en, this message translates to:
  /// **'Normal'**
  String get speedNormal;

  /// No description provided for @gameColorBeats.
  ///
  /// In en, this message translates to:
  /// **'Color Beats'**
  String get gameColorBeats;

  /// No description provided for @gameColorBeatsDesc.
  ///
  /// In en, this message translates to:
  /// **'Fit the blocks. Clear lines. Make music.'**
  String get gameColorBeatsDesc;

  /// No description provided for @tbClearLines.
  ///
  /// In en, this message translates to:
  /// **'Clear {n} lines!'**
  String tbClearLines(int n);

  /// No description provided for @tbBoardFull.
  ///
  /// In en, this message translates to:
  /// **'No more space!'**
  String get tbBoardFull;

  /// No description provided for @tbNewBlocks.
  ///
  /// In en, this message translates to:
  /// **'🎁 New blocks'**
  String get tbNewBlocks;

  /// No description provided for @tbNewBlocksNote.
  ///
  /// In en, this message translates to:
  /// **'Do a small challenge to clear space and keep playing!'**
  String get tbNewBlocksNote;

  /// No description provided for @tbLevelDone.
  ///
  /// In en, this message translates to:
  /// **'You did it!'**
  String get tbLevelDone;

  /// No description provided for @tbScore.
  ///
  /// In en, this message translates to:
  /// **'Score'**
  String get tbScore;

  /// No description provided for @tbBest.
  ///
  /// In en, this message translates to:
  /// **'Best'**
  String get tbBest;

  /// No description provided for @tbHelpCleared.
  ///
  /// In en, this message translates to:
  /// **'More space!'**
  String get tbHelpCleared;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'vi'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'vi':
      return AppLocalizationsVi();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
