import 'dart:math';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../l10n/app_localizations.dart';
import '../l10n/localization_service.dart';
import '../multiplayer/game_room_controller.dart';
import '../style/my_button.dart';
import '../style/palette.dart';
import 'user_session.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  TextEditingController _usernameController = TextEditingController();
  final TextEditingController _gameIdController = TextEditingController(text: '');
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  bool _showResumeOption = false;
  String? _activeGameId;
  List<Map<String, dynamic>> _availableGames = [];
  bool _loadingGames = false;

  @override
  void dispose() {
    _usernameController.dispose();
    _gameIdController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    final userSession = context.read<UserSession>();
    _usernameController = TextEditingController(text: userSession.username);

    // Fetch available games on startup
    _fetchAvailableGames();
  }

  void _fetchAvailableGames() async {
    setState(() {
      _loadingGames = true;
    });

    try {
      final controller = GameRoomController();
      final games = await controller.getAvailableGames('');

      if (mounted) {
        setState(() {
          // Get top 3 fullest games
          _availableGames = games.take(3).toList();
          _loadingGames = false;
        });
      }

      controller.dispose();
    } catch (e) {
      debugPrint('Error fetching available games: $e');
      if (mounted) {
        setState(() {
          _availableGames = [];
          _loadingGames = false;
        });
      }
    }
  }

  void _login() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final userSession = context.read<UserSession>();
      await userSession.login(_usernameController.text.trim());

      // Check if user has an active game or lobby game
      if (userSession.hasActiveGame || userSession.hasLobbyGame) {
        setState(() {
          _showResumeOption = true;
          _activeGameId = userSession.gameId;
        });
      } else {
        userSession.setGameId(_gameIdController.text.trim());

        if (mounted) {
          GoRouter.of(context).go('/lobby');
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${context.loginFailed} $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _resumeGame() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final userSession = context.read<UserSession>();

      if (userSession.hasActiveGame) {
        await userSession.resumeActiveGame();
        if (mounted) {
          GoRouter.of(context).go('/play'); // Go to play screen for active games
        }
      } else if (userSession.hasLobbyGame) {
        await userSession.resumeLobbyGame();
        if (mounted) {
          GoRouter.of(context).go('/lobby'); // Go to lobby for waiting games
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${context.failedToResumeGame} $e'),
            backgroundColor: Colors.red,
          ),
        );
        setState(() {
          _showResumeOption = false;
          _activeGameId = null;
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _startNewGame() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final userSession = context.read<UserSession>();
      userSession.setGameId(_gameIdController.text.trim());

      if (mounted) {
        GoRouter.of(context).go('/lobby');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _showResumeOption = false;
          _activeGameId = null;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.watch<Palette>();
    // Watch LocalizationService to rebuild when language changes
    context.watch<LocalizationService>();

    return Scaffold(
      backgroundColor: palette.backgroundMain,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Cardinyoli',
                  style: TextStyle(
                    fontSize: 48,
                    fontWeight: FontWeight.bold,
                    color: palette.ink,
                    fontFamily: 'Permanent Marker',
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                Text(
                  context.enterUsername,
                  style: TextStyle(
                    fontSize: 18,
                    color: palette.ink,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 40),
                if (!_showResumeOption) ...[
                  TextFormField(
                    controller: _usernameController,
                    decoration: InputDecoration(
                      labelText: context.username,
                      hintText: context.usernamePlaceholder,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      prefixIcon: const Icon(Icons.person),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return context.usernameEmpty;
                      }
                      if (value.trim().length > 50) {
                        return context.usernameTooLong;
                      }
                      // Check for valid characters (Unicode letters, numbers, and basic symbols)
                      if (!RegExp(r'^[\p{L}\p{N}_\-\s]+$', unicode: true).hasMatch(value.trim())) {
                        return 'Username can only contain letters, numbers, spaces, hyphens, and underscores';
                      }
                      return null;
                    },
                    textInputAction: TextInputAction.next,
                    enabled: !_isLoading,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _gameIdController,
                    decoration: InputDecoration(
                      labelText: context.gameId,
                      hintText: context.gameIdHint,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      prefixIcon: const Icon(Icons.games),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        var r = Random();
                        value = String.fromCharCodes(List.generate(6, (index) => r.nextInt(33) + 89));
                        return null;
                      }
                      if (value.trim().length > 30) {
                        return 'Game ID must be less than 30 characters';
                      }
                      // Check for valid characters
                      if (!RegExp(r'^[\p{L}\p{N}_\-\s]+$', unicode: true).hasMatch(value.trim())) {
                        return 'Game ID can only contain letters, numbers, spaces, hyphens, and underscores';
                      }
                      return null;
                    },
                    textInputAction: TextInputAction.done,
                    onFieldSubmitted: (_) => _login(),
                    enabled: !_isLoading,
                  ),
                  // Show available games
                  if (!_loadingGames && _availableGames.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: Text(
                        _availableGames
                            .map((game) => '${game['gameId']} (${game['playerCount']}/${game['maxPlayers']})')
                            .join(', '),
                        style: TextStyle(
                          fontSize: 12,
                          color: palette.ink.withValues(alpha: 0.5),
                          fontStyle: FontStyle.italic,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  const SizedBox(height: 24),
                  MyButton(
                    onPressed: _isLoading ? null : _login,
                    child: _isLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(context.joinGameButton),
                  ),
                  const SizedBox(height: 16),
                  MyButton(
                    onPressed: _isLoading
                        ? null
                        : () {
                            GoRouter.of(context).go('/');
                          },
                    child: Text(context.cancel),
                  ),
                ] else ...[
                  // Resume game section
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: palette.backgroundPlaySession.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: palette.ink.withValues(alpha: 0.3)),
                    ),
                    child: Column(
                      children: [
                        Icon(
                          Icons.play_circle_fill,
                          color: Colors.green,
                          size: 48,
                        ),
                        const SizedBox(height: 12),
                        Consumer<UserSession>(
                          builder: (context, userSession, child) {
                            final isActiveGame = userSession.hasActiveGame;

                            return Column(
                              children: [
                                Text(
                                  isActiveGame ? context.activeGameFound : context.lobbyGameFound,
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: palette.ink,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  isActiveGame
                                      ? context.welcomeBackActive.replaceAll('{username}', _usernameController.text)
                                      : context.welcomeBackLobby.replaceAll('{username}', _usernameController.text),
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: palette.ink.withValues(alpha: 0.8),
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            );
                          },
                        ),
                        if (_activeGameId != null) ...[
                          const SizedBox(height: 8),
                          Text(
                            '${context.gameIdLabel} $_activeGameId',
                            style: TextStyle(
                              fontSize: 14,
                              color: palette.ink.withValues(alpha: 0.6),
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  MyButton(
                    onPressed: _isLoading ? null : _resumeGame,
                    child: _isLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Consumer<UserSession>(
                            builder: (context, userSession, child) {
                              return Text(userSession.hasActiveGame ? context.resumeGame : context.returnToLobby);
                            },
                          ),
                  ),
                  const SizedBox(height: 16),
                  MyButton(
                    onPressed: _isLoading ? null : _startNewGame,
                    child: Text(context.startNewGame),
                  ),
                  const SizedBox(height: 16),
                  TextButton(
                    onPressed: _isLoading
                        ? null
                        : () {
                            setState(() {
                              _showResumeOption = false;
                              _activeGameId = null;
                            });
                          },
                    child: Text(
                      context.backToLogin,
                      style: TextStyle(color: palette.ink.withValues(alpha: 0.7)),
                    ),
                  ),
                ],
                const SizedBox(height: 40),
                Text(
                  context.gameNeedsFourPlayers,
                  style: TextStyle(
                    fontSize: 14,
                    color: palette.ink.withValues(alpha: 0.7),
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
