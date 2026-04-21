import 'package:flutter/widgets.dart';
import '../game_internals/multiplayer_game_state.dart';
import '../multiplayer/game_room_controller.dart';

class UserSession extends ChangeNotifier {
  String _username = '';
  bool _isLoggedIn = false;
  GameRoomController? _gameRoomController = GameRoomController();
  String? _gameId;
  bool _hasActiveGame = false;
  bool _hasLobbyGame = false;

  String get username => _username;
  bool get isLoggedIn => _isLoggedIn;
  // Game ID is a 6 letter random string
  String get gameId => _gameId ?? '';
  bool get hasActiveGame => _hasActiveGame;
  bool get hasLobbyGame => _hasLobbyGame;
  GameRoomController? get gameRoomController => _gameRoomController;

  Future<bool> login(String username) async {
    debugPrint('Logging in...');
    if (username.trim().isEmpty) {
      throw Exception('Username cannot be empty');
    }

    // Use username directly as the player identifier
    _username = username.trim();

    _isLoggedIn = true;
    // Check if user has an active game
    await _checkForActiveGame();

    notifyListeners();

    return true;
  }

  /// Set the game room controller for lifecycle management
  void setGameRoomController(GameRoomController? controller) {
    _gameRoomController = controller;
  }

  /// Set the game ID to join
  void setGameId(String gameId) {
    _gameId = gameId.isEmpty ? '' : gameId;
    _gameRoomController?.setGameId(_gameId!);
    notifyListeners();
  }

  /// Handle app lifecycle changes
  void handleAppLifecycleChange(AppLifecycleState state) {
    debugPrint('📱 App lifecycle state: $state');

    if (state == AppLifecycleState.detached) {
      // App is being closed, log out the player
      if (_isLoggedIn) {
        debugPrint('🚪 App closing, logging out user');
        logout();
      }
    }
  }


  /// Check if the user has an active game or lobby to resume
  Future<void> _checkForActiveGame() async {
    if (!_isLoggedIn) return;

    try {
      // Create a temporary game room controller to check for games
      final tempController = GameRoomController();

      debugPrint('Checking for existing games for user: $_username');

      final gameFound = await tempController.findAnyGameForUser(_username);

      debugPrint('Game found: $gameFound');

      if (gameFound != null && gameFound.status == GameStatus.playing) {
        _gameId = gameFound.gameId;
        _hasActiveGame = true;
        _hasLobbyGame = false;
        debugPrint('✅ Found ACTIVE playing game for $_username: ${gameFound.gameId} (status: ${gameFound.status})');
      } else if (gameFound != null && (gameFound.status == GameStatus.waiting || gameFound.status == GameStatus.ready)) {
        _gameId = gameFound.gameId;
        _hasActiveGame = false;
        _hasLobbyGame = true;
        debugPrint('✅ Found LOBBY game for $_username: ${gameFound.gameId} (${gameFound.players.length}/4 players, status: ${gameFound.status})');
      } else if (gameFound != null && gameFound.status == GameStatus.finished) {
        debugPrint('Game found finished already. Will start new game.');
        _gameId = null;
        _hasActiveGame = false;
        _hasLobbyGame = false;
      } else {
        debugPrint('No games found for $_username. Creating new game...');
        _gameId = null;
        _hasActiveGame = false;
        _hasLobbyGame = false;
      }

      tempController.dispose();
    } catch (e) {
      debugPrint('❌ Error checking for games for $_username: $e');
      _gameId = null;
      _hasActiveGame = false;
      _hasLobbyGame = false;
    }
  }

  /// Resume an active game
  Future<void> resumeActiveGame() async {
    if (!_hasActiveGame || _gameId == null || !_isLoggedIn) {
      throw Exception('No active game to resume');
    }

    try {
      debugPrint('🎮 Resuming active game $_gameId for $_username');
      _gameRoomController = GameRoomController();

      await _gameRoomController!.resumeGame(_gameId!, _username);

      // Clear the active game flags since we're now connected
      _gameId = null;
      _hasActiveGame = false;
      _hasLobbyGame = false;

      debugPrint('✅ Successfully resumed active game for $_username');
      notifyListeners();
    } catch (e) {
      debugPrint('❌ Failed to resume active game for $_username: $e');
      _gameRoomController?.dispose();
      _gameRoomController = null;
      throw Exception('Failed to resume game: $e');
    }
  }

  /// Resume a lobby game
  Future<void> resumeLobbyGame() async {
    if (!_hasLobbyGame || _gameId == null || !_isLoggedIn) {
      throw Exception('No lobby game to resume');
    }

    try {
      debugPrint('🏛️ Resuming lobby game $_gameId for $_username');
      _gameRoomController = GameRoomController();

      await _gameRoomController!.resumeGame(_gameId!, _username);

      _hasActiveGame = false;
      _hasLobbyGame = true;

      debugPrint('✅ Successfully resumed lobby for $_username');
      notifyListeners();
    } catch (e) {
      debugPrint('❌ Failed to resume lobby for $_username: $e');
      _gameRoomController?.dispose();
      _gameRoomController = null;
      throw Exception('Failed to resume lobby: $e');
    }
  }

  /// Change username without affecting game state
  Future<void> changeUsername(String newUsername) async {
    if (newUsername.trim().isEmpty) {
      throw Exception('Username cannot be empty');
    }

    if (newUsername.trim().length > 50) {
      throw Exception('Username must be less than 50 characters');
    }

    // Check for valid characters
    if (!RegExp(r'^[\p{L}\p{N}_\-\s]+$', unicode: true).hasMatch(newUsername.trim())) {
      throw Exception('Username can only contain letters, numbers, spaces, hyphens, and underscores');
    }

    final oldUsername = _username;
    _username = newUsername.trim();

    // If we have an active game, update the player name in the game
    if (_gameRoomController != null) {
      try {
        await _gameRoomController!.updatePlayerName(oldUsername, _username);
      } catch (e) {
        // Revert username change if game update failed
        _username = oldUsername;
        throw Exception('Failed to update name in game: $e');
      }
    }

    notifyListeners();
  }

  Future<void> _clearActiveSession() async {
    if (_isLoggedIn && _gameRoomController != null) {
      try {
        await _gameRoomController!.clearSession();
      } catch (e) {
        debugPrint('Error during cleanup: $e');
      }
    }
  }

  Future<void> leaveGame() async {
    if (_isLoggedIn && _gameRoomController != null) {
      try {
        debugPrint('Leaving game...');
        await _gameRoomController!.leaveGame();
      } catch (e) {
        // Ignore errors during cleanup
        debugPrint('Error during cleanup: $e');
      }
    }

    _isLoggedIn = false; // So that you don't get redirected back to the lobby or into a game.
    _gameRoomController = null;
    _gameId = null;
    _hasActiveGame = false;
    _hasLobbyGame = false;

    notifyListeners();
  }

  /// Logout the user
  Future<void> logout() async {
    debugPrint('Logging out user: $_username');

    await _clearActiveSession();

    _username = '';
    _isLoggedIn = false;
    _gameRoomController = null;
    _gameId = null;
    _hasActiveGame = false;
    _hasLobbyGame = false;
    // Don't reset game room controller or game ID - user stays in game

    notifyListeners();
  }
}
