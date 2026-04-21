import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:logging/logging.dart' hide Level;
import 'package:provider/provider.dart';

import '../audio/audio_controller.dart';
import '../audio/sounds.dart';
import '../game_internals/game_suit.dart';
import '../game_internals/multiplayer_game_state.dart';
import '../game_internals/score.dart';
import '../l10n/app_localizations.dart';
import '../login/user_session.dart';
import '../multiplayer/game_room_controller.dart';
import '../settings/settings.dart';
import '../style/confetti.dart';
import '../style/my_button.dart';
import '../style/palette.dart';
import '../style/user_top_bar.dart';
import 'multiplayer_board_widget.dart';

/// Multiplayer play screen.
///
/// This file implements defenses against duplicate dialogs stacking up:
/// - Tracks the last shown suit chooser (round + chooser index) and the last
///   shown bidding (round + bidder index).
/// - Tracks whether a dialog is currently open to avoid showing concurrent ones.
/// - Centralizes the logic to attempt to show dialogs into helper methods.
class MultiplayerPlaySessionScreen extends StatefulWidget {
  const MultiplayerPlaySessionScreen({super.key});

  @override
  State<MultiplayerPlaySessionScreen> createState() => _MultiplayerPlaySessionScreenState();
}

class _MultiplayerPlaySessionScreenState extends State<MultiplayerPlaySessionScreen> {
  static final _log = Logger('MultiplayerPlaySessionScreen');

  static const _celebrationDuration = Duration(milliseconds: 2000);

  bool _duringCelebration = false;
  GameRoomController? _gameRoomController;
  StreamSubscription<MultiplayerGameState>? _gameStateSubscription;

  // Prevent duplicate celebration navigation for the same round.
  int _celebratedRound = -1;

  // Prevent duplicate dialogs:
  // Track last round and chooser index for suit selection shown.
  int _lastShownSuitRound = -1;
  int _lastShownSuitChooserIndex = -1;

  // Track last round and bidding player index for bidding dialog shown.
  int _lastShownBiddingRound = -1;
  int _lastShownBiddingPlayerIndex = -1;

  // Global guard so we don't open multiple dialogs on top of each other.
  bool _isDialogOpen = false;

  @override
  Widget build(BuildContext context) {
    final palette = context.watch<Palette>();
    final userSession = context.watch<UserSession>();

    if (!userSession.isLoggedIn) {
      // Redirect to login if not logged in
      WidgetsBinding.instance.addPostFrameCallback((_) {
        GoRouter.of(context).go('/login');
      });
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    // If user doesn't have an active game controller, redirect to lobby
    if (_gameRoomController == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        GoRouter.of(context).go('/lobby');
      });
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return MultiProvider(
      providers: [
        Provider<GameRoomController?>.value(value: _gameRoomController),
      ],
      child: IgnorePointer(
        // Ignore all input during the celebration animation.
        ignoring: _duringCelebration,
        child: Scaffold(
          backgroundColor: palette.backgroundPlaySession,
          body: SafeArea(
            child: Column(
              children: [
                // Top bar with user actions: keep this inside the SafeArea so it
                // doesn't overlap notch/status icons.
                const UserTopBarInline(),

                // Main game board (takes remaining space) — allow the board
                // subtree to draw into the top system area while keeping the top
                // inline bar safe. We do this by removing the top MediaQuery
                // padding only for the board subtree.
                MediaQuery.removePadding(
                  context: context,
                  removeTop: true,
                  child: Expanded(
                    child: Stack(
                      children: [
                        // Game board
                        const MultiplayerBoardWidget(),

                        // Confetti overlay
                        if (_duringCelebration)
                          Positioned.fill(
                            child: IgnorePointer(
                              child: Confetti(
                                isStopped: !_duringCelebration,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),

                // Bottom controls
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  child: _buildBottomControls(palette),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBottomControls(Palette palette) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: palette.backgroundMain.withOpacity(0.9),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          MyButton(
            onPressed: _leaveGame,
            child: Text(context.leaveGame),
          ),
          Expanded(
            child: StreamBuilder<MultiplayerGameState>(
              stream: _gameRoomController!.gameState.stream,
              // Provide the current in-memory state as initialData so the UI
              // doesn't render empty while the stream establishes.
              initialData: _gameRoomController!.gameState,
              builder: (context, snapshot) {
                // Prefer snapshot data if present, otherwise fall back to the
                // controller's current in-memory state (provided via initialData).
                final gameState = snapshot.data ?? _gameRoomController!.gameState;

                // Obtain the session once (avoid duplicate reads)
                final userSession = context.watch<UserSession>();

                // If there's no gameState available, show a lightweight placeholder
                if (gameState == null) {
                  return Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        context.gameNotStarted,
                        style: TextStyle(color: palette.ink, fontSize: 16),
                      ),
                    ],
                  );
                }

                final isMyTurn = gameState.isPlayerTurn(userSession.username);

                return Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      gameState.choosingGameSuit || gameState.biddingInProgress
                          ? context.gameNotStarted
                          : (isMyTurn
                              ? context.yourTurn
                              : context.waitingForTurn.replaceAll('{name}', gameState.currentPlayer?.username ?? context.defaultPlayerName)),
                      style: TextStyle(
                        color: isMyTurn ? Colors.green : palette.ink,
                        fontSize: 16,
                        fontWeight: isMyTurn ? FontWeight.bold : FontWeight.normal,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          context.trickDisplay.replaceAll('{count}', gameState.trick.length.toString()),
                          style: TextStyle(
                            color: palette.ink.withOpacity(0.7),
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Text(
                          context.roundDisplay.replaceAll('{count}', (gameState.trickNumber + 1).toString()),
                          style: TextStyle(
                            color: palette.ink.withOpacity(0.7),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  @override
  void initState() {
    super.initState();

    // Get game room controller from user session
    final userSession = context.read<UserSession>();
    _gameRoomController = userSession.gameRoomController;

    if (_gameRoomController != null) {
      // If we're returning from a win/lose screen and the game is still in
      // finished state, pre-mark that round as already celebrated so we
      // don't immediately navigate back to the end screen.
      try {
        final gs = _gameRoomController!.gameState;
        if (gs.status == GameStatus.finished) {
          _celebratedRound = gs.roundNumber;
        }
      } catch (_) {
        // gameState throws if no active game; safe to ignore here
      }

      _subscribeToGameUpdates();

      // Also try to show any pending dialogs immediately (controller might
      // already contain the updated state if restartRound was called).
      _showPendingDialogs();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    // Check if controller was lost (e.g., after app was backgrounded)
    if (_gameRoomController == null) {
      final userSession = context.read<UserSession>();
      if (userSession.gameRoomController != null) {
        debugPrint('🔄 Restoring game controller after app resume');
        _gameRoomController = userSession.gameRoomController;
        _subscribeToGameUpdates();

        // Also attempt to show any pending dialogs after restoring.
        _showPendingDialogs();
      }
    }
  }

  @override
  void dispose() {
    _gameStateSubscription?.cancel();
    super.dispose();
  }

  void _subscribeToGameUpdates() {
    _gameStateSubscription?.cancel();

    _gameStateSubscription = _gameRoomController!.gameState.stream.listen(
      (gameState) {
        if (!mounted) return;

        // Check for game end conditions — only trigger once per round
        if (gameState.status == GameStatus.finished && gameState.roundNumber > _celebratedRound) {
          _celebratedRound = gameState.roundNumber;
          _showGameEndCelebration(gameState);
        }

        final currentUser = context.read<UserSession>().username;

        // Use centralized helpers to attempt to show dialogs. Helpers are
        // idempotent and will not show duplicates.
        _showPendingDialogs();

        final palette = context.read<Palette>();

        if (gameState.status == GameStatus.waiting || gameState.status == GameStatus.ready) {
          showDialog(
            context: context,
            builder: (BuildContext dialogContext) {
              return AlertDialog(
                backgroundColor: palette.backgroundMain,
                title: Text(context.ending, style: TextStyle(color: palette.ink)),
                content: Text(context.gameWasEnded),
                actions: [
                  TextButton(
                    onPressed: () async {
                      Navigator.of(dialogContext).pop();
                      final userSession = context.read<UserSession>();
                      await userSession.logout();
                      if (mounted) {
                        GoRouter.of(context).go('/login');
                      }
                    },
                    child: Text(context.ok, style: TextStyle(color: palette.ink)),
                  ),
                ],
              );
            },
          );
        }
      },
      onError: (error) {
        _log.severe('Error in game state stream: $error');
      },
    );
  }

  /// Attempt to show pending dialogs based on the in-memory state.
  /// This defers to the centralized per-dialog helpers which ensure idempotency.
  void _showPendingDialogs() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      try {
        if (!mounted || _gameRoomController == null) return;
        final gs = _gameRoomController!.gameState;
        if (gs == null) return;

        final currentUser = context.read<UserSession>().username;

        if ((gs.gameSuit == GameSuit.none || gs.gameSuit == GameSuit.delegate) &&
            gs.status == GameStatus.playing &&
            gs.isPlayerChoosingGameSuit(currentUser)) {
          _tryShowSuitSelection(gs);
          return;
        }

        if (gs.biddingInProgress &&
            gs.biddingPlayerIndex < gs.players.length &&
            gs.players[gs.biddingPlayerIndex].username == currentUser) {
          _tryShowBidding(gs);
          return;
        }
      } catch (e) {
        _log.fine('Could not inspect game state for pending dialogs: $e');
      }
    });
  }

  /// Centralized helper to show the suit selection dialog exactly once per
  /// chooser/round. Safe to call repeatedly.
  Future<void> _tryShowSuitSelection(MultiplayerGameState gs) async {
    try {
      if (!mounted || _gameRoomController == null) return;

      // If dialog already open, don't stack anything.
      if (_isDialogOpen) return;

      final currentUser = context.read<UserSession>().username;

      // Double-check conditions (caller may pass gs even if not strictly needed).
      if (!(gs.gameSuit == GameSuit.none || gs.gameSuit == GameSuit.delegate)) return;
      if (gs.status != GameStatus.playing) return;
      if (!gs.isPlayerChoosingGameSuit(currentUser)) return;

      // Prevent re-showing for the same round & chooser index.
      if (gs.roundNumber == _lastShownSuitRound && gs.choosingGameSuitIndex == _lastShownSuitChooserIndex) {
        return;
      }

      _isDialogOpen = true;

      final palette = context.read<Palette>();
      final isPoker = context.read<SettingsController>().pokerCards;

      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext dialogContext) {
          return AlertDialog(
            backgroundColor: palette.backgroundMain,
            title: Text(
              context.chooseGameSuit,
              style: TextStyle(color: palette.ink, fontWeight: FontWeight.bold),
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildSuitButton(
                    dialogContext,
                    GameSuit.clubs,
                    isPoker
                        ? const Text('♣', style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Colors.black))
                        : Image.asset('assets/icons/castellers.jpg', width: 32, height: 44, fit: BoxFit.contain),
                    isPoker ? context.clubs : context.castellers,
                    palette,
                  ),
                  const SizedBox(height: 10),
                  _buildSuitButton(
                    dialogContext,
                    GameSuit.diamonds,
                    isPoker
                        ? const Text('♦', style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Colors.red))
                        : Image.asset('assets/icons/diables.jpg', width: 32, height: 44, fit: BoxFit.contain),
                    isPoker ? context.diamonds : context.diables,
                    palette,
                  ),
                  const SizedBox(height: 10),
                  _buildSuitButton(
                    dialogContext,
                    GameSuit.hearts,
                    isPoker
                        ? const Text('♥', style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Colors.red))
                        : Image.asset('assets/icons/sardanes.jpg', width: 32, height: 44, fit: BoxFit.contain),
                    isPoker ? context.hearts : context.sardanes,
                    palette,
                  ),
                  const SizedBox(height: 10),
                  _buildSuitButton(
                    dialogContext,
                    GameSuit.spades,
                    isPoker
                        ? const Text('♠', style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Colors.black))
                        : Image.asset('assets/icons/bastoners.jpg', width: 32, height: 44, fit: BoxFit.contain),
                    isPoker ? context.spades : context.bastoners,
                    palette,
                  ),
                  const SizedBox(height: 10),
                  _buildSuitButton(
                    dialogContext,
                    GameSuit.botifarra,
                    const Text('🃏', style: TextStyle(fontSize: 26)),
                    context.botifarra,
                    palette,
                  ),
                  if (!(gs.gameSuit == GameSuit.delegate)) ...[
                    const SizedBox(height: 10),
                    _buildSuitButton(
                      dialogContext,
                      GameSuit.delegate,
                      const Icon(Icons.arrow_forward, size: 24),
                      context.delegate,
                      palette,
                    ),
                  ],
                ],
              ),
            ),
          );
        },
      );

      // After dialog closed, record that we showed it for this round & chooser.
      _lastShownSuitRound = gs.roundNumber;
      _lastShownSuitChooserIndex = gs.choosingGameSuitIndex;
    } catch (e) {
      _log.fine('Error while showing suit selection dialog: $e');
    } finally {
      _isDialogOpen = false;
    }
  }

  /// Centralized helper to show the bidding dialog exactly once per bidder/round.
  Future<void> _tryShowBidding(MultiplayerGameState gs) async {
    try {
      if (!mounted || _gameRoomController == null) return;

      if (_isDialogOpen) return;

      final currentUser = context.read<UserSession>().username;

      if (!gs.biddingInProgress) return;
      if (gs.biddingPlayerIndex >= gs.players.length) return;
      if (gs.players[gs.biddingPlayerIndex].username != currentUser) return;

      // Prevent re-showing for the same round & bidding player index.
      if (gs.roundNumber == _lastShownBiddingRound && gs.biddingPlayerIndex == _lastShownBiddingPlayerIndex) {
        return;
      }

      _isDialogOpen = true;

      final palette = context.read<Palette>();

      // Determine what the next bid would be
      String bidAction;
      switch (gs.gameMode) {
        case GameMode.normal:
          bidAction = context.contra;
          break;
        case GameMode.contra:
          bidAction = context.recontra;
          break;
        case GameMode.recontra:
          bidAction = context.santVicenc;
          break;
        case GameMode.santVicenc:
          // Should never reach here, but just in case
          _isDialogOpen = false;
          return;
      }

      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext dialogContext) {
          return AlertDialog(
            backgroundColor: palette.backgroundMain,
            title: Text(
              context.bidding,
              style: TextStyle(color: palette.ink, fontWeight: FontWeight.bold),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${context.doYouWantTo} $bidAction?',
                  style: TextStyle(color: palette.ink, fontSize: 16),
                ),
                const SizedBox(height: 10),
                Text(
                  context.thisWillIncreaseStakes,
                  style: TextStyle(color: palette.ink.withValues(alpha: 0.7), fontSize: 14),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () {
                  final userSession = context.read<UserSession>();
                  _gameRoomController?.makeBid(userSession.username, false);
                  Navigator.of(dialogContext).pop();
                },
                child: Text(
                  context.pass,
                  style: TextStyle(color: palette.ink.withValues(alpha: 0.7)),
                ),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                ),
                onPressed: () {
                  final userSession = context.read<UserSession>();
                  _gameRoomController?.makeBid(userSession.username, true);
                  Navigator.of(dialogContext).pop();
                },
                child: Text(
                  bidAction,
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          );
        },
      );

      // After dialog closed, record we showed it for this round & bidder.
      _lastShownBiddingRound = gs.roundNumber;
      _lastShownBiddingPlayerIndex = gs.biddingPlayerIndex;
    } catch (e) {
      _log.fine('Error while showing bidding dialog: $e');
    } finally {
      _isDialogOpen = false;
    }
  }

  void _showGameEndCelebration(MultiplayerGameState gameState) async {
    setState(() {
      _duringCelebration = true;
    });

    final audioController = context.read<AudioController>();

    // Play celebration sound
    audioController.playSfx(SfxType.congrats);

    // Wait for celebration
    await Future.delayed(_celebrationDuration);

    if (!mounted) return;

    final mult = (gameState.gameSuit == GameSuit.botifarra ? 1 : 0) + switch (gameState.gameMode) {
      GameMode.contra => 1,
      GameMode.recontra => 2,
      GameMode.santVicenc => 3,
      _ => 0,
    };

    // Create score object (simplified for now)
    final score = gameState.tempScores.team1Score >= gameState.tempScores.team2Score
        ? gameState.tempScores.team1Score
        : gameState.tempScores.team2Score;

    setState(() {
      _duringCelebration = false;
    });

    if (gameState.tempScores.isTie) {
      // Navigate to tie screen
      GoRouter.of(context).go('/play/tie', extra: {
        'score': score,
        'cumulatedScore': gameState.scores,
      });
    } else {
      final (winnerName1, winnerName2) = gameState.winnerInfo!;
      final userSession = context.read<UserSession>();

      if (userSession.username == winnerName1 || userSession.username == winnerName2) {
        // Navigate to win screen
        GoRouter.of(context).go('/play/win', extra: {
          'score': score,
          'winnerName1': winnerName1,
          'winnerName2': winnerName2,
          'cumulatedScore': gameState.scores,
        });
      } else {
        GoRouter.of(context).go('/play/lost', extra: {
          'score': score,
          'winnerName1': winnerName1,
          'winnerName2': winnerName2,
          'cumulatedScore': gameState.scores,
        });
      }
    }
  }

  void _leaveGame() async {
    // Show confirmation dialog
    final shouldLeave = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        final palette = context.read<Palette>();
        return AlertDialog(
          backgroundColor: palette.backgroundMain,
          title: Text(
            context.leaveGameTitle,
            style: TextStyle(color: palette.ink),
          ),
          content: Text(
            context.leaveGameConfirmAll,
            style: TextStyle(color: palette.ink),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text(
                context.cancel,
                style: TextStyle(color: palette.ink.withValues(alpha: 0.7)),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: Text(
                context.leave,
                style: TextStyle(color: palette.ink),
              ),
            ),
          ],
        );
      },
    );

    if (shouldLeave == true) {
      // Leave the game properly
      try {
        await _gameRoomController?.leaveGame();
      } catch (e) {
        _log.warning('Error leaving game: $e');
      } finally {
        if (mounted) {
          GoRouter.of(context).go('/lobby');
        }
      }
    }
  }

  void _showSuitSelectionDialog(bool hideDelegate) {
    // This method remains for compatibility with other codepaths - prefer
    // using `_tryShowSuitSelection` which prevents duplicates. This method
    // will show an unconditional dialog (but still will be prevented by the
    // global _isDialogOpen guard if it was called while a different dialog is open).
    final palette = context.read<Palette>();
    final isPoker = context.read<SettingsController>().pokerCards;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          backgroundColor: palette.backgroundMain,
          title: Text(
            context.chooseGameSuit,
            style: TextStyle(color: palette.ink, fontWeight: FontWeight.bold),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildSuitButton(
                  dialogContext,
                  GameSuit.clubs,
                  isPoker
                      ? const Text('♣', style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Colors.black))
                      : Image.asset('assets/icons/castellers.jpg', width: 32, height: 44, fit: BoxFit.contain),
                  isPoker ? context.clubs : context.castellers,
                  palette,
                ),
                const SizedBox(height: 10),
                _buildSuitButton(
                  dialogContext,
                  GameSuit.diamonds,
                  isPoker
                      ? const Text('♦', style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Colors.red))
                      : Image.asset('assets/icons/diables.jpg', width: 32, height: 44, fit: BoxFit.contain),
                  isPoker ? context.diamonds : context.diables,
                  palette,
                ),
                const SizedBox(height: 10),
                _buildSuitButton(
                  dialogContext,
                  GameSuit.hearts,
                  isPoker
                      ? const Text('♥', style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Colors.red))
                      : Image.asset('assets/icons/sardanes.jpg', width: 32, height: 44, fit: BoxFit.contain),
                  isPoker ? context.hearts : context.sardanes,
                  palette,
                ),
                const SizedBox(height: 10),
                _buildSuitButton(
                  dialogContext,
                  GameSuit.spades,
                  isPoker
                      ? const Text('♠', style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Colors.black))
                      : Image.asset('assets/icons/bastoners.jpg', width: 32, height: 44, fit: BoxFit.contain),
                  isPoker ? context.spades : context.bastoners,
                  palette,
                ),
                const SizedBox(height: 10),
                _buildSuitButton(
                  dialogContext,
                  GameSuit.botifarra,
                  const Text('🃏', style: TextStyle(fontSize: 26)),
                  context.botifarra,
                  palette,
                ),
                if (!hideDelegate) ...[
                  const SizedBox(height: 10),
                  _buildSuitButton(
                    dialogContext,
                    GameSuit.delegate,
                    const Icon(Icons.arrow_forward, size: 24),
                    context.delegate,
                    palette,
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSuitButton(BuildContext dialogContext, GameSuit suit, Widget icon, String label, Palette palette) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: suit.color == GameSuitColor.red ? Colors.red.shade100 : Colors.grey.shade200,
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        ),
        onPressed: () {
          final userSession = context.read<UserSession>();
          _gameRoomController?.setGameSuit(userSession.username, suit);
          Navigator.of(dialogContext).pop();
        },
        child: Row(
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            SizedBox(width: 40, child: Center(child: icon)),
            const SizedBox(width: 12),
            Text(
              label,
              style: TextStyle(
                color: suit.color == GameSuitColor.red ? Colors.red.shade900 : Colors.black,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showBiddingDialog(GameMode currentMode) {
    // This method remains for compatibility with other codepaths - prefer
    // using `_tryShowBidding` which prevents duplicates. This method will show
    // an unconditional dialog (but still will be prevented by the global
    // _isDialogOpen guard if it was called while a different dialog is open).
    final palette = context.read<Palette>();

    // Determine what the next bid would be
    String bidAction;
    switch (currentMode) {
      case GameMode.normal:
        bidAction = context.contra;
        break;
      case GameMode.contra:
        bidAction = context.recontra;
        break;
      case GameMode.recontra:
        bidAction = context.santVicenc;
        break;
      case GameMode.santVicenc:
        // Should never reach here, but just in case
        return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          backgroundColor: palette.backgroundMain,
          title: Text(
            context.bidding,
            style: TextStyle(color: palette.ink, fontWeight: FontWeight.bold),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '${context.doYouWantTo} $bidAction?',
                style: TextStyle(color: palette.ink, fontSize: 16),
              ),
              const SizedBox(height: 10),
              Text(
                context.thisWillIncreaseStakes,
                style: TextStyle(color: palette.ink.withValues(alpha: 0.7), fontSize: 14),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                final userSession = context.read<UserSession>();
                _gameRoomController?.makeBid(userSession.username, false);
                Navigator.of(dialogContext).pop();
              },
              child: Text(
                context.pass,
                style: TextStyle(color: palette.ink.withValues(alpha: 0.7)),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
              ),
              onPressed: () {
                final userSession = context.read<UserSession>();
                _gameRoomController?.makeBid(userSession.username, true);
                Navigator.of(dialogContext).pop();
              },
              child: Text(
                bidAction,
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        );
      },
    );
  }
}
