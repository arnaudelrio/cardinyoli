import 'dart:async';

import 'package:flutter/foundation.dart';

import 'card_suit.dart';
import 'game_suit.dart';
import 'playing_card.dart';
import 'score.dart';

enum GameStatus {
  waiting,
  ready,
  playing,
  finished,
}

class GamePlayer {
  final String username;
  final List<PlayingCard> hand;
  final int position; // 0, 1, 2, 3 representing positions around the table

  GamePlayer({
    required this.username,
    required this.hand,
    required this.position,
  });

  factory GamePlayer.fromJson(Map<String, dynamic> json) {
    return GamePlayer(
      username: json['username'] as String,
      hand: (json['hand'] as List?)?.map((cardJson) => PlayingCard.fromJson(cardJson as Map<String, dynamic>)).toList() ?? [],
      position: json['position'] as int,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'username': username,
      'hand': hand.map((card) => card.toJson()).toList(),
      'position': position,
    };
  }

  GamePlayer copyWith({
    String? username,
    List<PlayingCard>? hand,
    int? position,
  }) {
    return GamePlayer(
      username: username ?? this.username,
      hand: hand ?? this.hand,
      position: position ?? this.position,
    );
  }
}

class MultiplayerGameState extends ChangeNotifier {
  final String gameId;
  GameStatus _status;
  List<GamePlayer> _players;
  List<PlayingCard> _trick; // Cards played in current trick
  int _currentPlayerIndex;
  int _dealerIndex;
  String? _gameMaster; // Player ID who manages game logic (last to join)
  int _trickNumber; // Current trick number (0-based)
  Score _scores; // Team/player scores
  Score _tempScores; // Team/player scores
  GameSuit _gameSuit;
  GameMode _gameMode;
  CardSuit? _trickSuit;
  bool _choosingGameSuit;
  int _choosingGameSuitIndex;
  bool _biddingInProgress; // Tracks if we're in bidding phase
  int _biddingPlayerIndex; // Tracks which player is currently bidding
  (String, String)? _winnerInfo; // Winner names, score, and whether the current player is one of the winners
  int _roundNumber; // Increments each round; used to prevent double-celebration
  int _nextChooserIndex; // Index of the player who should choose the suit next round

  final StreamController<MultiplayerGameState> _streamController = StreamController<MultiplayerGameState>.broadcast();

  MultiplayerGameState({
    required this.gameId,
    GameStatus status = GameStatus.waiting,
    List<GamePlayer>? players,
    List<PlayingCard>? trick,
    int currentPlayerIndex = 0,
    int dealerIndex = 0,
    String? gameMaster,
    int trickNumber = 0,
    Score? scores,
    Score? tempScores,
    GameSuit gameSuit = GameSuit.none,
    GameMode gameMode = GameMode.normal,
    CardSuit? trickSuit,
    bool choosingGameSuit = false,
    int choosingGameSuitIndex = 0,
    bool biddingInProgress = false,
    int biddingPlayerIndex = 0,
    int roundNumber = 0,
    int nextChooserIndex = -1,
  })  : _status = status,
        _players = players ?? [],
        _trick = trick ?? [],
        _currentPlayerIndex = currentPlayerIndex,
        _dealerIndex = dealerIndex,
        _gameMaster = gameMaster,
        _trickNumber = trickNumber,
        _scores = scores ?? Score.empty(),
        _tempScores = tempScores ?? Score.empty(),
        _gameSuit = gameSuit,
        _gameMode = gameMode,
        _trickSuit = trickSuit,
        _choosingGameSuit = choosingGameSuit,
        _choosingGameSuitIndex = choosingGameSuitIndex,
        _biddingInProgress = biddingInProgress,
        _biddingPlayerIndex = biddingPlayerIndex,
        _roundNumber = roundNumber,
        _nextChooserIndex = nextChooserIndex;

  GameStatus get status => _status;
  List<GamePlayer> get players => List.unmodifiable(_players);
  List<PlayingCard> get trick => List.unmodifiable(_trick);
  int get currentPlayerIndex => _currentPlayerIndex;
  int get dealerIndex => _dealerIndex;
  String? get gameMaster => _gameMaster;
  int get trickNumber => _trickNumber;
  Score get scores => _scores;
  Score get tempScores => _tempScores;
  GameSuit get gameSuit => _gameSuit;
  GameMode get gameMode => _gameMode;
  CardSuit? get trickSuit => _trickSuit;
  bool get choosingGameSuit => _choosingGameSuit;
  int get choosingGameSuitIndex => _choosingGameSuitIndex;
  bool get biddingInProgress => _biddingInProgress;
  int get biddingPlayerIndex => _biddingPlayerIndex;
  (String, String)? get winnerInfo => _winnerInfo;
  int get roundNumber => _roundNumber;
  int get nextChooserIndex => _nextChooserIndex;

  GamePlayer? get currentPlayer => _players.isNotEmpty && _currentPlayerIndex < _players.length ? _players[_currentPlayerIndex] : null;

  bool get isGameActive => _status == GameStatus.playing;

  Stream<MultiplayerGameState> get stream => _streamController.stream;

  void _notifyChanges() {
    notifyListeners();
    _streamController.add(this);
  }

  @override
  void dispose() {
    _streamController.close();
    super.dispose();
  }

  /// Add a player to the game
  bool addPlayer(String username) {
    if (username.trim().isEmpty) {
      return false;
    }
    final maxPlayers = 4;
    if (_players.length >= maxPlayers || _status != GameStatus.waiting) {
      return false;
    }

    if (_players.any((p) => p.username == username)) {
      return false;
    }

    if (_players.isEmpty) {
      _gameMaster = username;
    }

    final position = _players.length;
    final newPlayer = GamePlayer(
      username: username,
      hand: [],
      position: position,
    );

    _players.add(newPlayer);

    _notifyChanges();

    return true;
  }

  bool setStatus(GameStatus status) {
    _status = status;
    _notifyChanges();

    return true;
  }

  // Remove a player from the game
  bool removePlayer(String username) {
    final removedIndex = _players.indexWhere((p) => p.username == username);
    if (removedIndex == -1) return false;

    _players.removeAt(removedIndex);

    // Adjust positions of remaining players
    for (int i = 0; i < _players.length; i++) {
      _players[i] = _players[i].copyWith(position: i);
    }

    // Adjust current player index if needed
    if (_currentPlayerIndex >= _players.length && _players.isNotEmpty) {
      _currentPlayerIndex = 0;
    }

    _notifyChanges();
    return true;
  }

  void _startGameAsGameMaster() {
    // For proper card dealing, we need exactly 4 players in non-debug mode
    if (_players.length != 4) {
      debugPrint('Cannot start game: Need exactly 4 players, but have ${_players.length}');
      return;
    }

    debugPrint('Game Master $_gameMaster is starting the game');

    _roundNumber++;
    _status = GameStatus.playing;
    _choosingGameSuit = true;
    _gameSuit = GameSuit.none;
    _biddingInProgress = false;
    _gameMode = GameMode.normal;
    _dealCards(); // This now sets _currentPlayerIndex based on 5 of spades
    _trick.clear();
    _trickNumber = 0;

    // Don't set turn master here - it will be set after bidding completes
    // The first player needs to choose the game suit first
    debugPrint('Waiting for player ${_players[_currentPlayerIndex].username} to choose game suit');

    _notifyChanges();
  }

  // Public method for game master to start game externally
  bool startGameAsGameMaster(String playerId) {
    if (_gameMaster != playerId) {
      debugPrint('Only game master can start the game');
      return false;
    }
    _startGameAsGameMaster();
    return true;
  }

  // Deal cards to all players
  void _dealCards() {
    // Create a full deck of cards (A, 2-10, J, Q, K for each suit)
    List<PlayingCard> _deck = [];
    for (final suit in CardSuit.values) {
      // Add Ace (1), 2-9, Jack (10), Queen (11), King (12)
      for (int value = 1; value <= 12; value++) {
        _deck.add(PlayingCard(suit, value));
      }
    }

    debugPrint('Created deck with ${_deck.length} cards');

    // Shuffle the deck
    _deck.shuffle();

    // Deal 12 cards to each player (48 total cards for 4 players in normal mode)
    final cardsPerPlayer = 12; // Standard 12 cards per player

    debugPrint('Dealing $cardsPerPlayer cards to each of ${_players.length} players');

    for (int i = 0; i < _players.length; i++) {
      final availableCards = _deck.length;
      final cardsToDeal = (availableCards >= cardsPerPlayer) ? cardsPerPlayer : availableCards;

      if (cardsToDeal <= 0) break;

      final playerCards = _deck.take(cardsToDeal).toList();
      _deck.removeRange(0, cardsToDeal);

      _players[i] = _players[i].copyWith(hand: playerCards);
      debugPrint('Player ${_players[i].username} dealt ${playerCards.length} cards');
    }

    debugPrint('Remaining cards in deck: ${_deck.length}');

    // Find the player with the 5 of spades and set them as the first player
    _setFirstPlayerWithFiveOfSpades();
  }

  // Find and set the player with 5 of spades as the first player
  void _setFirstPlayerWithFiveOfSpades() {
    // Find the player with the 5 of spades
    for (int i = 0; i < _players.length; i++) {
      final player = _players[i];
      for (final card in player.hand) {
        if (card.isFiveOfSpades) {
          _gameMaster = player.username;
          debugPrint('Player ${player.username} has 5 of spades and will start choosing game suit');
          _choosingGameSuitIndex = i;
          // Record who starts next round (rotates by 1 each round)
          _nextChooserIndex = (i + 1) % _players.length;
          debugPrint('The first player to play a card is the next player');
          _currentPlayerIndex = (i + 1) % _players.length;
          return;
        }
      }
    }

    // Fallback: if 5 of spades not found (shouldn't happen), use player after dealer
    _choosingGameSuitIndex = 0;
    _nextChooserIndex = 1 % _players.length;
    _currentPlayerIndex = (_dealerIndex + 1) % _players.length;
    debugPrint('Warning: 5 of spades not found! Starting with player ${_players[_currentPlayerIndex].username}');
  }

  /// Deals a fresh shuffled deck to all players without touching
  /// any player-order or suit-chooser fields.
  void _dealFreshCards() {
    final deck = <PlayingCard>[];
    for (final suit in CardSuit.values) {
      for (int value = 1; value <= 12; value++) {
        deck.add(PlayingCard(suit, value));
      }
    }
    deck.shuffle();

    const cardsPerPlayer = 12;
    for (int i = 0; i < _players.length; i++) {
      final playerCards = deck.take(cardsPerPlayer).toList();
      deck.removeRange(0, cardsPerPlayer);
      _players[i] = _players[i].copyWith(hand: playerCards);
      debugPrint('Player ${_players[i].username} dealt ${playerCards.length} cards (new round)');
    }
  }

  /// Starts a new round while keeping accumulated scores.
  /// The suit-chooser rotates: whoever chose last round's +1 position goes next.
  /// Only the current game master may call this.
  bool restartRound(String playerId) {
    if (_players.length != 4) {
      debugPrint('Cannot restart: need exactly 4 players, have ${_players.length}');
      return false;
    }
    if (_nextChooserIndex < 0 || _nextChooserIndex >= _players.length) {
      debugPrint('Cannot restart: nextChooserIndex=$_nextChooserIndex is invalid');
      return false;
    }

    final newChooserIndex = _nextChooserIndex;
    // Pre-compute the chooser for the round after this one
    _nextChooserIndex = (newChooserIndex + 1) % _players.length;

    _roundNumber++;

    // Reset round state — _scores is intentionally left untouched
    _tempScores = Score.empty();
    _status = GameStatus.playing;
    _choosingGameSuit = true;
    _choosingGameSuitIndex = newChooserIndex;
    _gameMaster = _players[newChooserIndex].username;
    _currentPlayerIndex = (newChooserIndex + 1) % _players.length;
    _gameSuit = GameSuit.none;
    _biddingInProgress = false;
    _biddingPlayerIndex = 0;
    _gameMode = GameMode.normal;
    _trickSuit = null;
    _trickNumber = 0;
    _trick.clear();
    _winnerInfo = null;

    // Deal fresh cards without re-running 5-of-spades logic
    _dealFreshCards();

    debugPrint('Round $_roundNumber started. Chooser: ${_players[newChooserIndex].username} (index $newChooserIndex)');
    _notifyChanges();
    return true;
  }

  void _setGameSuit(GameSuit suit) {
    _gameSuit = suit;
    debugPrint('Game suit set to: $_gameSuit');

    if (suit != GameSuit.delegate)
    {
      _choosingGameSuit = false;

      // After first player chooses suit, start bidding with next player
      _biddingPlayerIndex = _currentPlayerIndex;
      _biddingInProgress = true;
      _gameMode = GameMode.normal; // Reset to normal at start of bidding

      debugPrint('Bidding started with player: ${_players[_biddingPlayerIndex].username}');
    } else {
      _choosingGameSuitIndex = (_choosingGameSuitIndex + 2) % _players.length;
    }

    _notifyChanges();
  }

  /// Public method to set game suit - called by the first player
  bool setGameSuit(String playerId, GameSuit suit) {
    if (_gameSuit != GameSuit.none && _gameSuit != GameSuit.delegate) {
      debugPrint('Game suit already set');
      return false;
    }

    _setGameSuit(suit);
    return true;
  }

  /// Handle bidding action (Contrar, Recontrar, Sant Vicenç)
  bool makeBid(String playerId, bool accept) {
    if (!_biddingInProgress) {
      debugPrint('Not in bidding phase');
      return false;
    }

    if (_players.isEmpty || _biddingPlayerIndex >= _players.length) {
      return false;
    }

    final biddingPlayer = _players[_biddingPlayerIndex];
    if (biddingPlayer.username != playerId) {
      debugPrint('Not your turn to bid');
      return false;
    }

    if (accept) {
      // Escalate the game mode
      switch (_gameMode) {
        case GameMode.normal:
          _gameMode = GameMode.contra;
          debugPrint('Player $playerId chose Contrar');
          break;
        case GameMode.contra:
          _gameMode = GameMode.recontra;
          debugPrint('Player $playerId chose Recontrar');
          break;
        case GameMode.recontra:
          _gameMode = GameMode.santVicenc;
          debugPrint('Player $playerId chose Sant Vicenç');
          _completeBidding(); // Sant Vicenç is the final bid
          return true;
        case GameMode.santVicenc:
          // Should never reach here
          _completeBidding();
          return true;
      }

      // Move to next player for bidding
      _biddingPlayerIndex = (_biddingPlayerIndex + 1) % _players.length;

      // If we've come back to the player who chose the suit, end bidding
      if (_biddingPlayerIndex == _currentPlayerIndex) {
        _completeBidding();
      }
    } else {
      // Player passed, end bidding
      debugPrint('Player $playerId passed');
      _completeBidding();
    }

    _notifyChanges();
    return true;
  }

  /// Complete the bidding phase and start normal play
  void _completeBidding() {
    _biddingInProgress = false;

    debugPrint('Bidding complete. Game mode: $_gameMode. First player: ${_players[_currentPlayerIndex].username}');
  }

  // Play a card to the trick (only called by turn master)
  bool playCard(String username, PlayingCard card) {
    if (_status != GameStatus.playing) return false;
    if (_choosingGameSuit || _biddingInProgress) return false;

    final currentPlayer = this.currentPlayer;
    if (currentPlayer == null || currentPlayer.username != username) {
      return false;
    }

    if (!currentPlayer.hand.contains(card)) {
      return false;
    }

    final playerIndex = _players.indexWhere((p) => p.username == username);
    final updatedHand = List<PlayingCard>.from(currentPlayer.hand);
    updatedHand.remove(card);
    _players[playerIndex] = currentPlayer.copyWith(hand: updatedHand);

    // Add card to trick
    _trick.add(card);

    // Handle turn progression
    _progressTurn();

    _notifyChanges();
    return true;
  }

  bool isPlayable(PlayingCard card, String username) {
    if (_choosingGameSuit || _biddingInProgress) {
      debugPrint('Game suit or bidding in progress, cannot play card');
      return false;
    }

    final currentPlayer = _players[_currentPlayerIndex];
    if (currentPlayer.username != username) {
      debugPrint('Not current player\'s turn, cannot play card');
      return false;
    }

    if (_trick.isEmpty) {
      debugPrint('Trick is empty, can play any card');
      return true;
    }

    final currentPlayerCards = currentPlayer.hand;
    final playerCardsFromTrickSuit = currentPlayerCards.where((c) => c.suit == _trickSuit);
    final playerCardsFromGameSuit = currentPlayerCards.where((c) => c.suit == _gameSuit);

    final winningCard = _findWinningCard(_trick);
    final isTeamWinning = _trick.indexOf(winningCard) + 2 == _trick.length;

    if (playerCardsFromTrickSuit.isEmpty) {
      if (isTeamWinning) {
        debugPrint('Team winning, can play any card');
        return true;
      }

      if (playerCardsFromGameSuit.isEmpty) {
        debugPrint('No cards from trick or game suit, can play any card');
        return true;
      } else if (card.suit == _gameSuit) {
        if (winningCard != null && _couldWinTheTrick(currentPlayerCards, winningCard)) {
          if (_isBetterCard(card, winningCard)) {
            debugPrint('Card is better than winning card, can play');
            return true;
          } else {
            debugPrint('Cannot play, must win if possible');
            return false;
          }
        } else {
          debugPrint('Can play any card from the game suit because winning is impossible');
          return true;
        }
      } else {
        debugPrint('Must play a card from the game suit');
        return false;
      }
    } else if (card.suit == _trickSuit) {
      if (isTeamWinning) {
        debugPrint('Team winning, can play any card from the trick suit');
        return true;
      }
      if (winningCard != null && _couldWinTheTrick(currentPlayerCards, winningCard)) {
        if (_isBetterCard(card, winningCard)) {
          debugPrint('Card is better than winning card, can play');
          return true;
        } else {
          debugPrint('Cannot play, must win if possible');
          return false;
        }
      }
      debugPrint('Can play any card from the suit because winning is impossible');
      return true;
    }
    debugPrint('Must play a card from the trick suit');
    return false;
  }

  PlayingCard _findWinningCard(List<PlayingCard> cards) {
    PlayingCard winningCard = cards.first;
    for (final card in cards) {
      if (_isBetterCard(card, winningCard)) {
        winningCard = card;
      }
    }
    return winningCard;
  }

  bool _couldWinTheTrick(List<PlayingCard> cards, PlayingCard currentBest) {
    for (final card in cards) {
      if (_isBetterCard(card, currentBest)) {
        return true;
      }
    }
    return false;
  }

  bool _isBetterCard(PlayingCard newCard, PlayingCard currentBest) {
    if (newCard.suit == _gameSuit) {
      return currentBest.suit != _gameSuit || newCard > currentBest;
    }
    return newCard.suit == _trickSuit && newCard > currentBest;
  }

  // Handle turn progression (called by current turn master)
  void _progressTurn() {
    // Move to next player
    _currentPlayerIndex = (_currentPlayerIndex + 1) % _players.length;
    debugPrint("Current player changed to: ${_players[_currentPlayerIndex].username}");

    if (_trick.isNotEmpty && _trick.length == 1) {
      _trickSuit = _trick.first.suit;
    }
    
    // If trick is complete (all players played), handle trick end
    if (_trick.length >= _players.length) {
      _handleTrickEnd();
    
      // Check if game is finished (no more cards)
      if (_players.where((e) => e.hand.isNotEmpty).isEmpty) {
        _handleGameEnd();
      }
      
      return;
    }
  }

  // Handle end of trick (called by player who played last card)
  void _handleTrickEnd() {
    final winningCard = _findWinningCard(_trick);
    /// Get player that played the winning card
    final winnerIndex = (_trick.indexOf(winningCard) + _currentPlayerIndex) % _players.length;

    final trickWinner = _players[winnerIndex];

    // Award point to trick winner's team (simplified)
    var count = (List<PlayingCard> trick, int value) => trick.where((n) => n.value == value).length;
    final points = 1 + count(_trick, 9) * 5 + count(_trick, 1) * 4 + count(_trick, 12) * 3 + count(_trick, 11) * 2 + count(_trick, 10) * 1;
    addScoreByIndex(winnerIndex, points);

    debugPrint('Trick winner: ${trickWinner.username}, Current scores: $_tempScores');

    // Clear trick and start next one
    _trick.clear();
    _trickSuit = null;
    _trickNumber++;

    // Set trick winner as next turn master
    _currentPlayerIndex = winnerIndex;
  }

  void addScoreByIndex(int playerIndex, int points) {
    if (playerIndex % 2 == 0) {
      _tempScores = Score(
        _tempScores.team1Score + points,
        _tempScores.team2Score,
      );
    } else {
      _tempScores = Score(
        _tempScores.team1Score,
        _tempScores.team2Score + points,
      );
    }
  }

  Map<(String, String), int> getScoresByTeam() {
    return {
      (_players[0].username, _players[2].username): _scores.team1Score,
      (_players[1].username, _players[3].username): _scores.team2Score,
    };
  }

  // Handle game end (called by last active player)
  void _handleGameEnd() {
    debugPrint('Game ending. Final scores: $_tempScores');

    _status = GameStatus.finished;
    
    final mult = (_gameSuit == GameSuit.botifarra ? 1 : 0) + switch (_gameMode) {
      GameMode.contra => 1,
      GameMode.recontra => 2,
      GameMode.santVicenc => 3,
      _ => 0,
    };
    
    _tempScores = Score.calculate(
      [_tempScores.team1Score, _tempScores.team2Score],
      mult,
    );
    _scores = _scores + _tempScores;

    if (_tempScores.isTie) {
      _winnerInfo = null; // No specific winners in a tie
      debugPrint('The game ended in a tie! Both teams receive 0 points.');
    } else if (_tempScores.winningTeam == 1) {
      _winnerInfo = (_players[0].username, _players[2].username);
    } else {
      _winnerInfo = (_players[1].username, _players[3].username);
    }
  }

  // Update from JSON (for Firebase synchronization)
  void updateFromJson(Map<String, dynamic> json) {
    _status = GameStatus.values.firstWhere(
      (e) => e.toString() == 'GameStatus.${json['status']}',
      orElse: () => GameStatus.waiting,
    );

    _players = (json['players'] as List?)?.map((playerJson) => GamePlayer.fromJson(playerJson as Map<String, dynamic>)).toList() ?? [];

    _trick = (json['trick'] as List?)?.map((cardJson) => PlayingCard.fromJson(cardJson as Map<String, dynamic>)).toList() ?? [];

    _currentPlayerIndex = json['currentPlayerIndex'] as int? ?? 0;
    _dealerIndex = json['dealerIndex'] as int? ?? 0;

    _gameMaster = json['gameMaster'] as String?;
    _trickNumber = json['trickNumber'] as int? ?? 0;

    _scores = (json['scores'] as Map<String, dynamic>?) != null
        ? Score(
            (json['scores']['team1Score'] as int?) ?? 0,
            (json['scores']['team2Score'] as int?) ?? 0,
          )
        : Score.empty();
    _tempScores = (json['tempScores'] as Map<String, dynamic>?) != null
        ? Score(
            (json['tempScores']['team1Score'] as int?) ?? 0,
            (json['tempScores']['team2Score'] as int?) ?? 0,
          )
        : Score.empty();

    final gameSuitValue = json['gameSuit'] as int?;
    _gameSuit = GameSuit.values.firstWhere((e) => e.value == gameSuitValue);

    final gameModeValue = json['gameMode'] as int? ?? 0;
    _gameMode = GameMode.values.firstWhere((e) => e.value == gameModeValue, orElse: () => GameMode.normal);

    final trickSuitValue = json['trickSuit'] as int?;
    _trickSuit = trickSuitValue != null ? CardSuit.values.firstWhere((e) => e.value == trickSuitValue, orElse: () => CardSuit.clubs) : null;

    _choosingGameSuit = json['choosingGameSuit'] as bool? ?? false;
    _choosingGameSuitIndex = json['choosingGameSuitIndex'] as int? ?? 0;

    _biddingInProgress = json['biddingInProgress'] as bool? ?? false;
    _biddingPlayerIndex = json['biddingPlayerIndex'] as int? ?? 0;

    _roundNumber = json['roundNumber'] as int? ?? 0;
    _nextChooserIndex = json['nextChooserIndex'] as int? ?? -1;

    _notifyChanges();
  }

  // Convert to JSON (for Firebase synchronization)
  Map<String, dynamic> toJson() {
    return {
      'gameId': gameId,
      'status': _status.toString().split('.').last,
      'players': _players.map((player) => player.toJson()).toList(),
      'trick': _trick.map((card) => card.toJson()).toList(),
      'currentPlayerIndex': _currentPlayerIndex,
      'dealerIndex': _dealerIndex,
      'gameMaster': _gameMaster,
      'trickNumber': _trickNumber,
      'scores': _scores.toJson(),
      'tempScores': _tempScores.toJson(),
      'gameSuit': _gameSuit?.toJson(),
      'gameMode': _gameMode.toJson(),
      'trickSuit': _trickSuit?.toJson(),
      'choosingGameSuit': _choosingGameSuit,
      'choosingGameSuitIndex': _choosingGameSuitIndex,
      'biddingInProgress': _biddingInProgress,
      'biddingPlayerIndex': _biddingPlayerIndex,
      'roundNumber': _roundNumber,
      'nextChooserIndex': _nextChooserIndex,
    };
  }

  // Get player by username (ID)
  GamePlayer? getPlayerById(String username) {
    try {
      return _players.firstWhere((p) => p.username == username);
    } catch (e) {
      return null;
    }
  }

  // Check if it's a specific player's turn
  bool isPlayerTurn(String username) {
    final current = currentPlayer;
    return current != null && current.username == username && _status == GameStatus.playing;
  }

  bool isPlayerChoosingGameSuit(String username) {
    return _choosingGameSuit && _choosingGameSuitIndex == _players.indexOf(getPlayerById(username)!);
  }

  // Update a player's display name without changing their ID
  bool updatePlayerName(String oldUsername, String newUsername) {
    final playerIndex = _players.indexWhere((p) => p.username == oldUsername);
    if (playerIndex == -1) return false;

    _players[playerIndex] = _players[playerIndex].copyWith(username: newUsername);

    // Keep _gameMaster in sync — it is keyed by username
    if (_gameMaster == oldUsername) {
      _gameMaster = newUsername;
    }

    _notifyChanges();
    return true;
  }

  // Check if a player is the game master
  bool isGameMaster(String playerId) {
    return _gameMaster == playerId;
  }

  // Check if a player is the turn master
  bool isCurrentPlayerTurn(String playerId) {
    return _players[_currentPlayerIndex].username == playerId;
  }

  // Get player role for debugging
  String getPlayerRole(String playerId) {
    if (isGameMaster(playerId) && isCurrentPlayerTurn(playerId)) {
      return 'Game Master & Turn Master';
    } else if (isGameMaster(playerId)) {
      return 'Game Master';
    } else if (isCurrentPlayerTurn(playerId)) {
      return 'Turn Master';
    } else {
      return 'Player';
    }
  }
}
