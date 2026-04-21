import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../game_internals/multiplayer_game_state.dart';
import '../l10n/app_localizations.dart';
import '../l10n/localization_service.dart';
import '../multiplayer/game_room_controller.dart';
import '../login/user_session.dart';
import '../style/my_button.dart';
import '../style/palette.dart';
import '../style/user_top_bar.dart';

class LobbyScreen extends StatefulWidget {
  const LobbyScreen({super.key});

  @override
  State<LobbyScreen> createState() => _LobbyScreenState();
}

class _LobbyScreenState extends State<LobbyScreen> {
  late final UserSession _userSession;
  StreamSubscription? _gameStateSubscription;
  bool _isJoining = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    setState(() {
      _error = null;
      _isJoining = true;
    });
    _userSession = context.read<UserSession>();
    _joinOrCreateGame();
  }

  @override
  void dispose() {
    _gameStateSubscription?.cancel();
    super.dispose();
  }

  Future<void> _joinOrCreateGame() async {
    try {
      debugPrint('Joining or creating game...');
      final userSession = context.read<UserSession>();
      if (!userSession.isLoggedIn) {
        if (mounted) {
          debugPrint('User not logged in');
          GoRouter.of(context).go('/login');
        }
        return;
      }

      // Set the game room controller in user session for lifecycle management
      userSession.setGameRoomController(_userSession.gameRoomController ?? GameRoomController());

      if (!userSession.hasLobbyGame) {
        debugPrint('No lobby game set up... Joining or creating game');
        await userSession.gameRoomController!.joinOrCreateGame(
          userSession.username,
          gameId: userSession.gameId,
        );
      }

      debugPrint('Waiting in lobby...');

      // Listen for game state changes
      _gameStateSubscription = userSession.gameRoomController!.gameState.stream.listen((state) {
        if (mounted) {
          if (state.status == GameStatus.playing) {
            debugPrint('Game has started');
            // Game has started, navigate to play screen
            GoRouter.of(context).go('/play');
          }
        }
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isJoining = false;
      });
    } finally {
      setState(() {
        _isJoining = false;
      });
    }
  }

  void _leaveGame() async {
    final userSession = context.read<UserSession>();
    await userSession.leaveGame();

    if (mounted) {
      debugPrint('User left game');
      GoRouter.of(context).go('/login');
    }
  }

  void _showGameIdDialog() async {
    final userSession = context.read<UserSession>();
    final controller = TextEditingController(text: userSession.gameId);

    final newGameId = await showDialog<String>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(context.changeGame),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(context.enterNewGameId),
              const SizedBox(height: 16),
              TextField(
                controller: controller,
                decoration: InputDecoration(
                  labelText: context.gameId,
                  hintText: context.gameIdHint,
                  border: const OutlineInputBorder(),
                ),
                textInputAction: TextInputAction.done,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(context.cancel),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(controller.text.trim()),
              child: Text(context.joinGameButton),
            ),
          ],
        );
      },
    );

    if (newGameId != null && newGameId != userSession.gameId) {
      // Leave current game
      await _userSession.gameRoomController?.leaveGame();

      // Update game ID and rejoin
      userSession.setGameId(newGameId);
      await _joinOrCreateGame();
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.watch<Palette>();
    final userSession = context.watch<UserSession>();
    // Watch LocalizationService to rebuild when language changes
    context.watch<LocalizationService>();

    return Scaffold(
      backgroundColor: palette.backgroundMain,
      body: SafeArea(
        child: Column(
          children: [
            // Top bar with user actions
            const UserTopBarInline(),
            // Main content
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      context.cardinyoliLobby,
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: palette.ink,
                        fontFamily: 'Permanent Marker',
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          context.welcomeBack.replaceAll('{username}', userSession.username),
                          style: TextStyle(
                            fontSize: 18,
                            color: palette.ink,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        if (userSession.gameRoomController != null) ...[
                          const SizedBox(width: 8),
                          Icon(
                            Icons.devices,
                            color: palette.ink.withValues(alpha: 0.6),
                            size: 16,
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 40),
                    if (_isJoining) ...[
                      const Center(child: CircularProgressIndicator()),
                      const SizedBox(height: 20),
                      Text(
                        context.loading,
                        style: TextStyle(
                          fontSize: 16,
                          color: palette.ink,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ] else if (_error != null) ...[
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.red.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.red),
                        ),
                        child: Column(
                          children: [
                            Icon(Icons.error, color: Colors.red, size: 48),
                            const SizedBox(height: 8),
                            Text(
                              context.errorJoiningGame,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.red,
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _error!,
                              style: TextStyle(color: Colors.red),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      MyButton(
                        onPressed: _joinOrCreateGame,
                        child: Text(context.tryAgain),
                      ),
                    ] else ...[
                      StreamBuilder<MultiplayerGameState>(
                        initialData: _userSession.gameRoomController!.gameState,
                        stream: _userSession.gameRoomController!.gameState.stream,
                        builder: (context, snapshot) {
                          if (snapshot.hasError) {
                            return Center(child: Text(context.somethingWentWrong));
                          }

                          if (!snapshot.hasData) {
                            return const Center(child: CircularProgressIndicator());
                          }

                          final gameState = snapshot.data!;
                          final isGameMaster = gameState.isGameMaster(userSession.username);
                          return Column(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(20),
                                decoration: BoxDecoration(
                                  color: palette.backgroundPlaySession.withValues(alpha: 0.3),
                                  borderRadius: BorderRadius.circular(12),
                                  border: isGameMaster ? Border.all(color: Colors.orange, width: 2) : null,
                                ),
                                child: Column(
                                  children: [
                                    Text(
                                      '${context.gameCode}: ${gameState.gameId}',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: palette.ink,
                                      ),
                                    ),
                                    if (isGameMaster) ...[
                                      const SizedBox(height: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: Colors.orange.withValues(alpha: 0.2),
                                          borderRadius: BorderRadius.circular(12),
                                          border: Border.all(color: Colors.orange),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            const Icon(Icons.star, color: Colors.orange, size: 16),
                                            const SizedBox(width: 4),
                                            Text(
                                              context.gameMaster,
                                              style: TextStyle(
                                                color: Colors.orange,
                                                fontSize: 12,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                    const SizedBox(height: 8),
                                    Text(
                                      '${context.gameId}: ${gameState.gameId}',
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: palette.ink.withValues(alpha: 0.7),
                                      ),
                                    ),
                                    const SizedBox(height: 16),
                                    Text(
                                      '${context.playersJoined} (${gameState.players.length}/4):',
                                      style: TextStyle(
                                        fontSize: 16,
                                        color: palette.ink,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    ...gameState.players.map((player) => Padding(
                                          padding: const EdgeInsets.symmetric(vertical: 2),
                                          child: Row(
                                            mainAxisAlignment: MainAxisAlignment.center,
                                            children: [
                                              Icon(
                                                Icons.person,
                                                color: palette.ink,
                                                size: 16,
                                              ),
                                              const SizedBox(width: 8),
                                              Text(
                                                player.username,
                                                style: TextStyle(
                                                  color: palette.ink,
                                                  fontWeight: player.username == userSession.username ? FontWeight.bold : FontWeight.normal,
                                                ),
                                              ),
                                              if (player.username == userSession.username)
                                                Text(
                                                  ' ${context.you}',
                                                  style: TextStyle(
                                                    color: palette.ink.withValues(alpha: 0.7),
                                                    fontSize: 12,
                                                  ),
                                                ),
                                            ],
                                          ),
                                        )),
                                    if (gameState.players.length < 4) ...[
                                      const SizedBox(height: 12),
                                      Text(
                                        context.waitingForPlayers,
                                        style: TextStyle(
                                          color: palette.ink.withValues(alpha: 0.7),
                                          fontStyle: FontStyle.italic,
                                        ),
                                      ),
                                    ] else ...[
                                      const SizedBox(height: 12),
                                      if (isGameMaster) ...[
                                        Text(
                                          context.readyToStart,
                                          style: TextStyle(
                                            color: Colors.green,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        MyButton(
                                          onPressed: () async {
                                            try {
                                              final success = await _userSession.gameRoomController!.startGameAsGameMaster();
                                              if (success && mounted && context.mounted) {
                                                GoRouter.of(context).go('/play');
                                              }
                                            } catch (e) {
                                              if (mounted && context.mounted) {
                                                ScaffoldMessenger.of(context).showSnackBar(
                                                  SnackBar(
                                                    content: Text('${context.startingGame} $e'),
                                                    backgroundColor: Colors.red,
                                                  ),
                                                );
                                              }
                                            }
                                          },
                                          child: Text(context.startingGame),
                                        ),
                                      ] else ...[
                                        Text(
                                          context.waitingForGameMaster,
                                          style: TextStyle(
                                            color: Colors.green,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ],
                                  ],
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ],
                    const SizedBox(height: 40),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        Expanded(
                          child: MyButton(
                            onPressed: _leaveGame,
                            child: Text(context.leaveGame),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: MyButton(
                            onPressed: _showGameIdDialog,
                            child: Text(context.changeGame),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
