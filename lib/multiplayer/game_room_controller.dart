import 'dart:async';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../game_internals/game_suit.dart';
import '../game_internals/multiplayer_game_state.dart';
import '../game_internals/playing_card.dart';

class GameRoomController {
  static const int maxPlayersPerGame = 4;
  static const String gamesCollection = 'games';
  static const String highscoresCollection = 'highscores';

  MultiplayerGameState? _gameState;
  StreamSubscription<DocumentSnapshot>? _gameSubscription;
  String? _currentGameId;
  String? _currentUsername;
  String _gameIdToJoin = '';

  FirebaseFirestore get _firestore => FirebaseFirestore.instance;

  GameRoomController() {
  }

  MultiplayerGameState get gameState {
    if (_gameState == null) {
      throw StateError('No active game state. Call joinOrCreateGame first.');
    }
    return _gameState!;
  }

  /// Get current game ID (for persistence)
  String? get currentGameId => _currentGameId;

  /// Joins or creates a game session with the specified game ID
  Future<MultiplayerGameState> joinOrCreateGame(String username, {String? gameId}) async {
    debugPrint('Joining or creating game: $gameId, player: $username');
    _currentUsername = username;
    setGameId(gameId);

    try {
      // Try to find an available game with the specified ID
      debugPrint('Finding available game with ID: $_gameIdToJoin');
      final availableGame = await _findAvailableGame(_gameIdToJoin);

      if (availableGame != null) {
        // Join existing game
        debugPrint('Joining existing game: ${availableGame.id}');
        await _joinGame(availableGame.id, username);
        return gameState;
      } else {
        debugPrint('Creating new game');
        // Create new game with a unique ID based on the specified one
        final uniqueGameId = await _generateUniqueGameId(_gameIdToJoin);

        return await _createNewGame(uniqueGameId, _currentUsername ?? 'Player');
      }
    } catch (e) {
      throw GameRoomException('Failed to join or create game: $e');
    }
  }

  /// Creates a new game room with the specified ID
  Future<MultiplayerGameState> _createNewGame(String gameId, String username) async {
    try {
      final newGameState = MultiplayerGameState(
        gameId: gameId,
        status: GameStatus.waiting,
      );
    } catch (e) {
    }
    final newGameState = MultiplayerGameState(
      gameId: gameId,
      status: GameStatus.waiting,
    );

    // Add the creator as the first player
    newGameState.addPlayer(username);

    // Save to Firestore
    await _firestore.collection(gamesCollection).doc(gameId).set(newGameState.toJson());

    _currentGameId = gameId;
    _gameState = newGameState;

    // Start listening for updates
    _subscribeToGameUpdates(gameId);

    return newGameState;
  }
  /// Finds an available game with the specified ID or creates a new one
  Future<DocumentSnapshot?> _findAvailableGame(String gameId) async {
    // First try to find the exact game ID
    final gameDoc = await _firestore.collection(gamesCollection).doc(gameId).get();

    if (gameDoc.exists) {
      final data = gameDoc.data()!;
      final players = data['players'] as List? ?? [];
      final status = data['status'] as String? ?? 'waiting';

      // Check if game is joinable
      if (status == 'waiting' && players.length < maxPlayersPerGame) {
        return gameDoc;
      }
    }

    // If exact game ID is not available, try to find games with same base ID
    final query = await _firestore.collection(gamesCollection).where('status', isEqualTo: 'waiting').get();

    for (final doc in query.docs) {
      final data = doc.data();
      final players = data['players'] as List? ?? [];
      final docGameId = doc.id;

      // Check if this game has the same base ID and is joinable
      if (docGameId.startsWith(gameId) && players.length < maxPlayersPerGame) {
        return doc;
      }
    }

    return null;
  }

  /// Generate a unique game ID, handling conflicts
  Future<String> _generateUniqueGameId(String baseGameId) async {
    // First try the base game ID
    final baseDoc = await _firestore.collection(gamesCollection).doc(baseGameId).get();
    if (!baseDoc.exists) {
      return baseGameId;
    }

    // If base ID exists, try numbered variations
    int counter = 2;
    while (counter < 100) {
      // Limit attempts to prevent infinite loops
      final candidateId = '${baseGameId}_$counter';
      final doc = await _firestore.collection(gamesCollection).doc(candidateId).get();
      if (!doc.exists) {
        return candidateId;
      }
      counter++;
    }

    // If all numbered variations are taken, use timestamp
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    return '${baseGameId}_$timestamp';
  }

  /// Joins an existing game
  Future<void> _joinGame(String gameId, String username) async {
    final gameDoc = await _firestore.collection(gamesCollection).doc(gameId).get();

    final gameData = gameDoc.data()!;
    final gameState = MultiplayerGameState(gameId: gameId);
    gameState.updateFromJson(gameData);

    // Check if game is joinable
    if (gameState.status != GameStatus.waiting) {
      throw GameRoomException('Game is not accepting new players');
    }

    // Check if user is already in the game
    final existingPlayer = gameState.getPlayerById(username);
    if (existingPlayer != null) {
      // User is already in the game, just rejoin
      _currentGameId = gameId;
      _gameState = gameState;
      _subscribeToGameUpdates(gameId);
      return;
    }

    if (gameState.players.length >= maxPlayersPerGame) {
      throw GameRoomException('Game is full');
    }

    // Add player to the game
    if (!gameState.addPlayer(username)) {
      throw GameRoomException('Failed to join game');
    }

    if (gameState.players.length == maxPlayersPerGame) {
      gameState.setStatus(GameStatus.ready);
    }
    // Update Firestore
    await _firestore.collection(gamesCollection).doc(gameId).update(gameState.toJson());

    _currentGameId = gameId;
    _gameState = gameState;

    // Start listening for updates
    _subscribeToGameUpdates(gameId);
  }

  /// Subscribe to real-time game updates
  void _subscribeToGameUpdates(String gameId) {
    _gameSubscription?.cancel();

    _gameSubscription = _firestore.collection(gamesCollection).doc(gameId).snapshots().listen((snapshot) {
      if (snapshot.exists && _gameState != null) {
        final data = snapshot.data()!;
        _gameState!.updateFromJson(data);
      }
    }, onError: (error) {
      debugPrint('Error listening to game updates: $error');
    });
  }

  /// Play a card in the current game (only if player is turn master)
  Future<bool> playCard(PlayingCard card) async {
    if (_gameState == null || _currentGameId == null || _currentUsername == null) {
      return false;
    }

    // Update session activity
    await _updateSessionActivity();

    // Check if it's this player's turn
    if (!_gameState!.isPlayerTurn(_currentUsername!)) {
      return false;
    }

    // Attempt to play the card locally first
    if (!_gameState!.playCard(_currentUsername!, card)) {
      return false;
    }

    try {
      // Update Firestore with the new game state
      await _firestore.collection(gamesCollection).doc(_currentGameId!).update(_gameState!.toJson());

      return true;
    } catch (e) {
      debugPrint('Error updating game state: $e');
      // Could implement retry logic or rollback here
      return false;
    }
  }

  Future<bool> isPlayable(PlayingCard card) async {
    if (_gameState == null || _currentGameId == null || _currentUsername == null) {
      return false;
    }

    try {
      // Check if the card is playable locally
      return _gameState!.isPlayable(card, _currentUsername!);
    } catch (e) {
      debugPrint('Error updating game state: $e');
      // Could implement retry logic or rollback here
      return false;
    }
  }

  /// Leave the current game
  Future<void> leaveGame() async {
    if (_gameState == null || _currentGameId == null || _currentUsername == null) {
      return;
    }

    try {
      // If no players left, delete the game
      if (_gameState!.players.isEmpty || _gameState!.status == GameStatus.playing || _gameState!.status == GameStatus.finished || _gameState!.gameMaster == _currentUsername!) {
        await _firestore.collection(gamesCollection).doc(_currentGameId!).delete();
      } else {
        // Remove player from game state
        _gameState!.removePlayer(_currentUsername!);

        if (_gameState!.status == GameStatus.ready) {
          _gameState!.setStatus(GameStatus.waiting);
        }
        // Update the game state in Firestore
        await _firestore.collection(gamesCollection).doc(_currentGameId!).update(_gameState!.toJson());
      }
    } catch (e) {
      debugPrint('Error leaving game: $e');
    } finally {
      _cleanup();
    }
  }

  /// Clear the active session
  Future<void> clearSession() async {
    if (_gameState == null || _currentGameId == null || _currentUsername == null) {
      return;
    }

    try {
      // Session cleared
    } catch (e) {
      debugPrint('Error leaving game: $e');
    } finally {
      _cleanup();
    }
  }

  /// Get the current player's hand
  List<PlayingCard> getCurrentPlayerHand() {
    if (_gameState == null || _currentUsername == null) {
      return [];
    }

    final player = _gameState!.getPlayerById(_currentUsername!);
    return player?.hand ?? [];
  }

  /// Check if it's the current player's turn
  bool isMyTurn() {
    if (_gameState == null || _currentUsername == null) {
      return false;
    }
    return _gameState!.isPlayerTurn(_currentUsername!);
  }

  /// Clean up resources
  void _cleanup() {
    _gameSubscription?.cancel();
    _gameSubscription = null;
    _gameState = null;
    _currentGameId = null;
    _currentUsername = null;
  }

  /// Start periodic session cleanup

  /// Clean up abandoned games
  Future<void> _cleanupAbandonedGames() async {
    try {
      final gamesSnapshot = await _firestore.collection(gamesCollection).get();

      for (final gameDoc in gamesSnapshot.docs) {
        final gameData = gameDoc.data();
        final gameState = MultiplayerGameState(gameId: gameDoc.id);
        gameState.updateFromJson(gameData);

        // If game is empty, clean it up
        if (gameState.players.isEmpty) {
          debugPrint('Deleting abandoned game ${gameDoc.id}');
          await _firestore.collection(gamesCollection).doc(gameDoc.id).delete();
        }
      }
    } catch (e) {
      debugPrint('Error cleaning up abandoned games: $e');
    }
  }

  /// Update session activity
  Future<void> _updateSessionActivity() async {
    if (_currentUsername == null) {
      return;
    }

    try {
      // Session activity tracking removed
    } catch (e) {
      debugPrint('Error updating session activity: $e');
    }
  }

  /// Set game ID to join
  void setGameId(String? gameId) {
    debugPrint('Setting game ID to $gameId');
    _gameIdToJoin = gameId != null && gameId.isNotEmpty ? gameId : String.fromCharCodes(List.generate(6, (index) => Random().nextInt(26) + 97));
    debugPrint('Game ID set to $_gameIdToJoin');
  }

  /// Get available games for a specific game ID
  Future<List<Map<String, dynamic>>> getAvailableGames(String gameId) async {
    try {
      final query = await _firestore.collection(gamesCollection).where('status', isEqualTo: 'waiting').get();

      debugPrint('Looking for available games');

      final availableGames = <Map<String, dynamic>>[];

      for (final doc in query.docs) {
        final data = doc.data();
        final docGameId = doc.id;
        final players = data['players'] as List? ?? [];

        // Check if this game matches the requested game ID pattern
        if (docGameId == gameId || docGameId.startsWith('${gameId}_') || gameId == '') {
          debugPrint('Found game');
          if (players.length < maxPlayersPerGame) {
            availableGames.add({
              'gameId': docGameId,
              'playerCount': players.length,
              'maxPlayers': maxPlayersPerGame,
              'players': players,
            });
          }
        }
      }

      // Sort by player count (fuller games first)
      availableGames.sort((a, b) => (b['playerCount'] as int).compareTo(a['playerCount'] as int));

      return availableGames;
    } catch (e) {
      debugPrint('Error getting available games: $e');
      return [];
    }
  }

  /// Find any game (including lobby) for a specific user
  Future<MultiplayerGameState?> findAnyGameForUser(String username) async {
    try {
      final gamesSnapshot = await _firestore.collection(gamesCollection).get();
      debugPrint('Looking for any game for $username');

      for (final gameDoc in gamesSnapshot.docs) {
        final gameData = gameDoc.data();
        final gameState = MultiplayerGameState(gameId: gameDoc.id);
        gameState.updateFromJson(gameData);

        // Check if user is in this game (any status)
        final player = gameState.getPlayerById(username);
        if (player != null) {
          debugPrint('Found game for $username: ${gameState.gameId} (status: ${gameState.status})');
          return gameState;
        }
      }

      debugPrint('No games found for $username');
      return null;
    } catch (e) {
      debugPrint('Error finding any game for user $username: $e');
      return null;
    }
  }

  /// Resume a game for a specific user
  Future<void> resumeGame(String gameId, String username) async {
    try {
      debugPrint('Resuming game...');
      final gameDoc = await _firestore.collection(gamesCollection).doc(gameId).get();

      if (!gameDoc.exists) {
        throw GameRoomException('Game not found');
      }

      final gameData = gameDoc.data()!;
      final gameState = MultiplayerGameState(gameId: gameId);
      gameState.updateFromJson(gameData);

      debugPrint('Looking for game');
      // Check if user is in the game
      final player = gameState.getPlayerById(username);
      if (player == null) {
        throw GameRoomException('User is not in this game');
      }

      _currentUsername = username;
      _currentGameId = gameId;
      _gameState = gameState;

      debugPrint('Found game');

      // Start listening for updates
      _subscribeToGameUpdates(gameId);
    } catch (e) {
      throw GameRoomException('Failed to resume game: $e');
    }
  }

  /// Update a player's display name in the current game
  Future<void> updatePlayerName(String oldUsername, String newUsername) async {
    debugPrint('Updating player name...');

    if (_gameState == null || _currentGameId == null) {
      return;
    }

    try {
      // Update the player's display name using the game state method
      if (!_gameState!.updatePlayerName(oldUsername, newUsername)) {
        throw GameRoomException('Player not found in game');
      }

      // Update in Firestore
      await _firestore.collection(gamesCollection).doc(_currentGameId!).update(_gameState!.toJson());

      // Update current username for this session
      _currentUsername = newUsername;
    } catch (e) {
      throw GameRoomException('Failed to update player name: $e');
    }
  }

  /// Check if current player is the game master
  bool isGameMaster() {
    if (_gameState == null || _currentUsername == null) return false;
    return _gameState!.isGameMaster(_currentUsername!);
  }

  /// Check if current player is the turn master
  bool isCurrentPlayerTurn() {
    if (_gameState == null || _currentUsername == null) return false;
    return _gameState!.isCurrentPlayerTurn(_currentUsername!);
  }

  /// Get current player's role
  String getPlayerRole() {
    if (_gameState == null || _currentUsername == null) return 'Unknown';
    return _gameState!.getPlayerRole(_currentUsername!);
  }

  /// Start game as game master (only if player is game master)
  Future<bool> startGameAsGameMaster() async {
    if (_gameState == null || _currentGameId == null || _currentUsername == null) {
      return false;
    }

    if (!_gameState!.isGameMaster(_currentUsername!)) {
      debugPrint('Only game master can start the game');
      return false;
    }

    try {
      if (_gameState!.startGameAsGameMaster(_currentUsername!)) {
        debugPrint('Game started as game master');
        // Update in Firestore
        await _firestore.collection(gamesCollection).doc(_currentGameId!).update(_gameState!.toJson());

        return true;
      }
    } catch (e) {
      debugPrint('Failed to start game as game master: $e');
    }

    return false;
  }

  /// Set game suit (called by first player)
  Future<bool> setGameSuit(String playerId, GameSuit suit) async {
    if (_gameState == null || _currentGameId == null || _currentUsername == null) {
      return false;
    }

    // Update session activity
    await _updateSessionActivity();

    // Attempt to set game suit locally first
    if (!_gameState!.setGameSuit(playerId, suit)) {
      return false;
    }

    try {
      // Update Firestore with the new game state
      await _firestore.collection(gamesCollection).doc(_currentGameId!).update(_gameState!.toJson());

      return true;
    } catch (e) {
      debugPrint('Error updating game state: $e');
      return false;
    }
  }

  /// Make bid (called during bidding phase)
  Future<bool> makeBid(String playerId, bool accept) async {
    if (_gameState == null || _currentGameId == null || _currentUsername == null) {
      return false;
    }

    // Update session activity
    await _updateSessionActivity();

    // Attempt to make bid locally first
    if (!_gameState!.makeBid(playerId, accept)) {
      return false;
    }

    try {
      // Update Firestore with the new game state
      await _firestore.collection(gamesCollection).doc(_currentGameId!).update(_gameState!.toJson());

      return true;
    } catch (e) {
      debugPrint('Error updating game state: $e');
      return false;
    }
  }

  /// Restart the current round, preserving accumulated scores.
  /// Only succeeds if the current player is the game master.
  /// All other clients will receive the update via Firestore.
  Future<bool> restartRound() async {
    if (_gameState == null || _currentGameId == null || _currentUsername == null) {
      return false;
    }

    if (!_gameState!.restartRound(_currentUsername!)) {
      debugPrint('$_currentUsername is not the game master — cannot restart round');
      return false;
    }

    try {
      await _firestore
          .collection(gamesCollection)
          .doc(_currentGameId!)
          .update(_gameState!.toJson());
      debugPrint('Round restarted and pushed to Firestore');
      return true;
    } catch (e) {
      debugPrint('Failed to push restarted round to Firestore: $e');
      return false;
    }
  }

  /// Dispose of the controller
  void dispose() {
    _cleanup();
  }
}

class GameRoomException implements Exception {
  final String message;

  GameRoomException(this.message);

  @override
  String toString() => 'GameRoomException: $message';
}
