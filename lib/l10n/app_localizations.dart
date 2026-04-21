import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'localization_service.dart';

/// Extension to access translations from BuildContext
/// Uses the LocalizationService provider to get the current translations
extension AppLocalizations on BuildContext {
  LocalizationService get _localizationService => read<LocalizationService>();

  // App strings
  String get appTitle => _t('appTitle');
  String get gameSubtitle => _t('gameSubtitle');
  String get joinGame => _t('joinGame');
  String get loginToPlay => _t('loginToPlay');
  String get gameRules => _t('gameRules');
  String get settings => _t('settings');
  String get back => _t('back');
  String get name => _t('name');
  String get soundFx => _t('soundFx');
  String get music => _t('music');
  String get usePokerCards => _t('usePokerCards');

  // Lobby strings
  String get cardinyoliLobby => _t('cardinyoliLobby');
  String get waitingForPlayers => _t('waitingForPlayers');
  String get playersJoined => _t('playersJoined');
  String get startingGame => _t('startingGame');
  String get gameCode => _t('gameCode');
  String get changeGame => _t('changeGame');
  String get enterNewGameId => _t('enterNewGameId');
  String get gameId => _t('gameId');
  String get gameIdHint => _t('gameIdHint');
  String get leaveGame => _t('leaveGame');
  String get areYouSure => _t('areYouSure');
  String get leaveGameConfirm => _t('leaveGameConfirm');
  String get leave => _t('leave');

  // Login strings
  String get loading => _t('loading');
  String get enterUsername => _t('enterUsername');
  String get username => _t('username');
  String get usernamePlaceholder => _t('usernamePlaceholder');
  String get usernameEmpty => _t('usernameEmpty');
  String get usernameTooLong => _t('usernameTooLong');
  String get gameIdHintLong => _t('gameIdHintLong');
  String get login => _t('login');
  String get loginFailed => _t('loginFailed');
  String get resumeGame => _t('resumeGame');
  String get startNewGame => _t('startNewGame');
  String get gameIdWarning => _t('gameIdWarning');
  String get failedToResumeGame => _t('failedToResumeGame');

  // Game result strings
  String get youWon => _t('youWon');
  String get youLose => _t('youLose');
  String get score => _t('score');
  String get winner => _t('winner');
  String get tie => _t('tie');
  String get continueButton => _t('continue');

  // Rules strings
  String get gameRulesTitle => _t('gameRulesTitle');
  String get playersSection => _t('playersSection');
  String get cardsSection => _t('cardsSection');
  String get triomfSection => _t('triomfSection');
  String get controlSection => _t('controlSection');
  String get playCardsSection => _t('playCardsSection');
  String get cardValuesSection => _t('cardValuesSection');

  // Settings and user strings
  String get profile => _t('profile');
  String get changeUsername => _t('changeUsername');
  String get enterNewUsername => _t('enterNewUsername');
  String get usernameNote => _t('usernameNote');
  String get update => _t('update');
  String get usernameUpdated => _t('usernameUpdated');
  String get usernameUpdateFailed => _t('usernameUpdateFailed');
  String get changeUsernameTitle => _t('changeUsernameTitle');
  String get logoutFromDevice => _t('logoutFromDevice');
  String get logoutDescription => _t('logoutDescription');
  String get logout => _t('logout');

  // Language strings
  String get language => _t('language');
  String get english => _t('english');
  String get catalan => _t('catalan');
  String get updatingUsername => _t('updatingUsername');
  String get selectPreferredLanguage => _t('selectPreferredLanguage');
  String get gameRulesToolip => _t('gameRulesToolip');
  String get settingsTooltip => _t('settingsTooltip');
  String get logoutTooltip => _t('logoutTooltip');

  // Dialog buttons
  String get cancel => _t('cancel');
  String get joinGameButton => _t('joinGameButton');
  String get tryAgain => _t('tryAgain');
  String get somethingWentWrong => _t('somethingWentWrong');
  String get changeName => _t('changeName');
  String get close => _t('close');
  String get thisCardCannotBePlayed => _t('thisCardCannotBePlayed');
  String get notYourTurn => _t('notYourTurn');
  String get trickArea => _t('trickArea');
  String get dropCardsHere => _t('dropCardsHere');
  String get waitYourTurn => _t('waitYourTurn');
  String get createdBy => _t('createdBy');
  String get scores => _t('scores');
  String get gameSuit => _t('gameSuit');
  String get trickSuit => _t('trickSuit');
  String get ending => _t('ending');
  String get gameWasEnded => _t('gameWasEnded');
  String get ok => _t('ok');
  String get leaveGameTitle => _t('leaveGameTitle');
  String get leaveGameConfirmAll => _t('leaveGameConfirmAll');
  String get chooseGameSuit => _t('chooseGameSuit');
  String get selectTrumpSuit => _t('selectTrumpSuit');
  String get clubs => _t('clubs');
  String get diamonds => _t('diamonds');
  String get hearts => _t('hearts');
  String get spades => _t('spades');
  String get botifarra => _t('botifarra');
  String get castellers => _t('castellers');
  String get diables => _t('diables');
  String get sardanes => _t('sardanes');
  String get bastoners => _t('bastoners');
  String get delegate => _t('delegate');
  String get bidding => _t('bidding');
  String get doYouWantTo => _t('doYouWantTo');
  String get contra => _t('contra');
  String get recontra => _t('recontra');
  String get santVicenc => _t('santVicenc');
  String get thisWillIncreaseStakes => _t('thisWillIncreaseStakes');
  String get pass => _t('pass');
  String get activeGameFound => _t('activeGameFound');
  String get lobbyGameFound => _t('lobbyGameFound');
  String get welcomeBackActive => _t('welcomeBackActive');
  String get welcomeBackLobby => _t('welcomeBackLobby');
  String get gameIdLabel => _t('gameIdLabel');
  String get returnToLobby => _t('returnToLobby');
  String get backToLogin => _t('backToLogin');
  String get gameNeedsFourPlayers => _t('gameNeedsFourPlayers');
  String get welcomeBack => _t('welcomeBack');
  String get errorJoiningGame => _t('errorJoiningGame');
  String get readyToStart => _t('readyToStart');
  String get gameMaster => _t('gameMaster');
  String get waitingForGameMaster => _t('waitingForGameMaster');
  String get waitingForSuit => _t('waitingForSuit');
  String get waitingForBid => _t('waitingForBid');
  String get yourTurn => _t('yourTurn');
  String get waitingForTurn => _t('waitingForTurn');
  String get trickDisplay => _t('trickDisplay');
  String get roundDisplay => _t('roundDisplay');
  String get gameNotStarted => _t('gameNotStarted');
  String get defaultPlayerName => _t('defaultPlayerName');
  String get you => _t('you');

  /// Internal helper to translate using the service
  String _t(String key) => _localizationService.translate(key);
}

/// Delegate for loading app localization
class AppLocalizationDelegate extends LocalizationsDelegate<AppLocalizationsImpl> {
  const AppLocalizationDelegate();

  @override
  bool isSupported(Locale locale) {
    return ['en', 'ca'].contains(locale.languageCode);
  }

  @override
  Future<AppLocalizationsImpl> load(Locale locale) async {
    return AppLocalizationsImpl();
  }

  @override
  bool shouldReload(LocalizationsDelegate<AppLocalizationsImpl> old) => false;
}

/// Implementation class for localization - not used directly but required for the delegate
class AppLocalizationsImpl {
  AppLocalizationsImpl();
}
