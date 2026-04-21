import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../game_internals/card_suit.dart';
import '../game_internals/game_suit.dart';
import '../game_internals/multiplayer_game_state.dart';
import '../game_internals/playing_card.dart';
import '../l10n/app_localizations.dart';
import '../login/user_session.dart';
import '../multiplayer/game_room_controller.dart';
import '../settings/settings.dart';
import '../style/palette.dart';
import 'playing_card_widget.dart';

/// This widget displays the multiplayer game board with UNO-like 4-player layout
class MultiplayerBoardWidget extends StatefulWidget {
  const MultiplayerBoardWidget({super.key});

  @override
  State<MultiplayerBoardWidget> createState() => _MultiplayerBoardWidgetState();
}

class _MultiplayerBoardWidgetState extends State<MultiplayerBoardWidget> {
  List<PlayingCard> _reorderableHand = [];

  bool _haveSameCards(List<PlayingCard> cards, List<PlayingCard> otherCards) {
    return cards.length == otherCards.length &&
        cards.every((card) => otherCards.contains(card));
  }

  /// Get the display position for players relative to current user
  List<GamePlayer?> _arrangePlayersFromCurrent(List<GamePlayer> players, String currentUserId) {
    final currentPlayerIndex = players.indexWhere((p) => p.username == currentUserId);
    if (currentPlayerIndex == -1) return [null, null, null, null];

    final arranged = <GamePlayer?>[];
    for (int i = 0; i < 4; i++) {
      final playerIndex = (currentPlayerIndex + i) % players.length;
      if (playerIndex < players.length) {
        arranged.add(players[playerIndex]);
      } else {
        arranged.add(null);
      }
    }
    return arranged;
  }

  @override
  Widget build(BuildContext context) {
    final gameRoomController = context.watch<GameRoomController?>();
    final userSession = context.watch<UserSession>();
    final palette = context.watch<Palette>();

    if (gameRoomController == null || !userSession.isLoggedIn) {
      return const Center(child: CircularProgressIndicator());
    }

    return LayoutBuilder(builder: (context, constraints) {
      final otherCardWidth = (constraints.maxWidth * 0.2).clamp(78.0, 150.0);
      final otherCardHeight = otherCardWidth * 1.4;
      final topRowHeight = otherCardHeight + 30;

      return StreamBuilder<MultiplayerGameState>(
        initialData: gameRoomController.gameState,
        stream: gameRoomController.gameState.stream,
        builder: (context, snapshot) {
          // Handle connection lost/error
          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.cloud_off, size: 64, color: palette.ink.withValues(alpha: 0.5)),
                  const SizedBox(height: 16),
                  Text(
                    'Lost connection to game',
                    style: TextStyle(
                      color: palette.ink,
                      fontSize: 18,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            );
          }

          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final gameState = snapshot.data!;
          final currentUser = userSession.username;

          if (!gameState.players.any((p) => p.username == currentUser)) {
            return Center(
              child: Text(
                'You are not in this game',
                style: TextStyle(color: palette.ink, fontSize: 18),
              ),
            );
          }

          final arranged = _arrangePlayersFromCurrent(gameState.players, currentUser);
          final isMyTurn = gameState.isPlayerTurn(currentUser);
          final isInteractingBlocked = gameState.choosingGameSuit || gameState.biddingInProgress;
          final canPlayCards = gameState.isGameActive && isMyTurn && !isInteractingBlocked;
          final canReorderCards = !isInteractingBlocked;

          final current = arranged[0];
          final topPlayers = [arranged[1], arranged[2], arranged[3]];

          if (current != null) {
            if (!_haveSameCards(_reorderableHand, current.hand)) {
              debugPrint('reordered: ${_reorderableHand.length}\nhand: ${current.hand.length}');
              _reorderableHand = List.from(current.hand);
            }
          }

          String? waitingMessage;
          if (gameState.choosingGameSuit && !gameState.isPlayerChoosingGameSuit(currentUser)) {
             if (gameState.players.isNotEmpty && gameState.choosingGameSuitIndex < gameState.players.length) {
                final choosingPlayer = gameState.players[gameState.choosingGameSuitIndex].username;
                waitingMessage = context.waitingForSuit.replaceAll('{name}', choosingPlayer);
             }
          } else if (gameState.biddingInProgress) {
             if (gameState.players.isNotEmpty &&
                 gameState.biddingPlayerIndex < gameState.players.length &&
                 gameState.players[gameState.biddingPlayerIndex].username != currentUser) {
                final biddingPlayer = gameState.players[gameState.biddingPlayerIndex].username;
                waitingMessage = context.waitingForBid.replaceAll('{name}', biddingPlayer);
             }
          }

          return Stack(
            children: [
              Column(
                children: [
                  const SizedBox(height: 4),
                  // Top players' cards
                  SizedBox(
                    height: topRowHeight,
                    child: Stack(
                      alignment: Alignment.center,
                      children: topPlayers.asMap().entries.map((entry) {
                        final index = entry.key;
                        final player = entry.value;
                        if (player == null) return const SizedBox.shrink();
                        final spacing = (constraints.maxWidth * 0.3).clamp(otherCardWidth + 6.0, 160.0);
                        final centerX = constraints.maxWidth / 2;
                        final leftOffset = centerX + (index - 1) * spacing - (otherCardWidth / 2);
                        return Positioned(
                          left: leftOffset,
                          child: _buildOtherPlayer(
                            player,
                            gameState,
                            palette,
                            otherCardWidth,
                            otherCardHeight,
                            isEnemy: index != 1,
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildStatsPanel(gameState),
                  const SizedBox(height: 12),
                  Expanded(
                    child: _buildTrickArea(
                      gameState,
                      gameRoomController,
                      palette,
                      currentUser,
                      canPlayCards,
                    ),
                  ),
                  if (current != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 10, left: 10, right: 10),
                      child: _buildCurrentPlayer(
                        current,
                        gameState,
                        gameRoomController,
                        palette,
                        canPlayCards,
                        canReorderCards,
                      ),
                    ),
                ],
              ),
              if (waitingMessage != null)
                Positioned.fill(
                  child: Container(
                    color: Colors.black54,
                child: Center(
                  child: Card(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 24.0, horizontal: 32.0),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const CircularProgressIndicator(),
                          const SizedBox(height: 24),
                          Text(
                            waitingMessage!,
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: palette.ink,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
        },
      );
    });
  }

  Widget _buildTrickArea(
    MultiplayerGameState gameState,
    GameRoomController gameRoomController,
    Palette palette,
    String currentUser,
    bool canPlayCards,
  ) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: palette.backgroundMain,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            spreadRadius: 2,
          ),
        ],
      ),
      child: DragTarget<PlayingCard>(
        onAcceptWithDetails: (details) {
          if (!canPlayCards) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(context.notYourTurn),
                duration: Duration(seconds: 2),
              ),
            );
            return;
          }

          if (!gameState.isPlayable(details.data, currentUser)) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(context.thisCardCannotBePlayed),
                duration: const Duration(seconds: 2),
              ),
            );
            return;
          }

          if (gameRoomController.isCurrentPlayerTurn()) {
            gameRoomController.playCard(details.data);
          }
        },
        builder: (context, candidateData, rejectedData) {
          final isHighlighted = candidateData.isNotEmpty;

          return Container(
            decoration: BoxDecoration(
              color: isHighlighted ? palette.backgroundMain.withOpacity(0.9) : palette.backgroundMain.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isHighlighted ? Colors.green : palette.ink.withOpacity(0.3),
                width: isHighlighted ? 3 : 1,
              ),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
            child: SizedBox(
              width: double.infinity,
              child: gameState.trick.isEmpty
                  ? Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.crop_square,
                          size: 48,
                          color: palette.ink.withOpacity(0.3),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          context.trickArea,
                          style: TextStyle(
                            color: palette.ink.withOpacity(0.5),
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          gameRoomController.isCurrentPlayerTurn() ? context.dropCardsHere : context.waitYourTurn,
                          style: TextStyle(
                            color: palette.ink.withOpacity(0.4),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    )
                  : _buildTrickCards(gameState.trick),
            ),
          );
        },
      ),
    );
  }

  Widget _buildTrickCards(List<PlayingCard> trick) {
    return Stack(
      children: [
        ...trick.asMap().entries.map((entry) {
          final index = entry.key;
          final card = entry.value;

          Widget positionedCard;
          switch (index) {
            case 0: // Bottom
              positionedCard = Positioned(
                bottom: 10,
                left: 0,
                right: 0,
                child: Center(child: PlayingCardWidget.multiplayer(card: card, isPlayable: false, customWidth: 50, customHeight: 70)),
              );
              break;
            case 1: // Right
              positionedCard = Positioned(
                right: 10,
                top: 0,
                bottom: 0,
                child: Center(child: PlayingCardWidget.multiplayer(card: card, isPlayable: false, customWidth: 50, customHeight: 70)),
              );
              break;
            case 2: // Top
              positionedCard = Positioned(
                top: 10,
                left: 0,
                right: 0,
                child: Center(child: PlayingCardWidget.multiplayer(card: card, isPlayable: false, customWidth: 50, customHeight: 70)),
              );
              break;
            case 3: // Left
              positionedCard = Positioned(
                left: 10,
                top: 0,
                bottom: 0,
                child: Center(child: PlayingCardWidget.multiplayer(card: card, isPlayable: false, customWidth: 50, customHeight: 70)),
              );
              break;
            default:
              positionedCard = const SizedBox.shrink();
          }

          return positionedCard;
        }),
      ],
    );
  }

  /// Returns a widget for a [GameSuit] symbol.
  /// Poker → Unicode glyph; Catalan → icon PNG.
  /// Botifarra and delegate always fall back to text/emoji.
  Widget _buildGameSuitSymbol(GameSuit? suit, bool isPoker) {
    if (suit == null || suit == GameSuit.none) {
      return const Text('N/A', style: TextStyle(fontSize: 16));
    }
    final color = suit.color == GameSuitColor.red ? Colors.red : Colors.black;
    switch (suit) {
      case GameSuit.botifarra:
        return const Text('🃏', style: TextStyle(fontSize: 18));
      case GameSuit.delegate:
        return Text('→', style: TextStyle(fontSize: 18, color: color));
      case GameSuit.clubs:
        return isPoker
            ? Text('♣', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color))
            : Image.asset('assets/icons/castellers.jpg', width: 22, height: 22, fit: BoxFit.contain);
      case GameSuit.diamonds:
        return isPoker
            ? Text('♦', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color))
            : Image.asset('assets/icons/diables.jpg', width: 22, height: 22, fit: BoxFit.contain);
      case GameSuit.hearts:
        return isPoker
            ? Text('♥', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color))
            : Image.asset('assets/icons/sardanes.jpg', width: 22, height: 22, fit: BoxFit.contain);
      case GameSuit.spades:
        return isPoker
            ? Text('♠', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color))
            : Image.asset('assets/icons/bastoners.jpg', width: 22, height: 22, fit: BoxFit.contain);
      case GameSuit.none:
        return const Text('N/A', style: TextStyle(fontSize: 16));
    }
  }

  /// Returns a widget for a [CardSuit] symbol.
  /// Poker → Unicode glyph; Catalan → icon PNG.
  Widget _buildCardSuitSymbol(CardSuit? suit, bool isPoker) {
    if (suit == null) {
      return const Text('N/A', style: TextStyle(fontSize: 16));
    }
    final color = suit.color == CardSuitColor.red ? Colors.red : Colors.black;
    switch (suit) {
      case CardSuit.clubs:
        return isPoker
            ? Text('♣', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color))
            : Image.asset('assets/icons/castellers.jpg', width: 22, height: 22, fit: BoxFit.contain);
      case CardSuit.diamonds:
        return isPoker
            ? Text('♦', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color))
            : Image.asset('assets/icons/diables.jpg', width: 22, height: 22, fit: BoxFit.contain);
      case CardSuit.hearts:
        return isPoker
            ? Text('♥', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color))
            : Image.asset('assets/icons/sardanes.jpg', width: 22, height: 22, fit: BoxFit.contain);
      case CardSuit.spades:
        return isPoker
            ? Text('♠', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color))
            : Image.asset('assets/icons/bastoners.jpg', width: 22, height: 22, fit: BoxFit.contain);
    }
  }

  Widget _buildStatsPanel(MultiplayerGameState gameState) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.85),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(blurRadius: 8, color: Colors.black12)],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Compact suits panel
          ValueListenableBuilder<bool>(
            valueListenable: context.read<SettingsController>().usePokerCards,
            builder: (context, isPoker, _) {
              return Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 6),
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [BoxShadow(blurRadius: 4, color: Colors.black12)],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Row(
                      children: [
                        Text(context.trickSuit, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                        const SizedBox(width: 2),
                        _buildCardSuitSymbol(gameState.trickSuit, isPoker),
                      ],
                    ),
                    const SizedBox(width: 16),
                    Row(
                      children: [
                        Text(context.gameSuit, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                        const SizedBox(width: 2),
                        _buildGameSuitSymbol(gameState.gameSuit, isPoker),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: 8),
          // Compact team panels with overlapping VS
          Builder(
            builder: (context) {
              final scores = gameState.getScoresByTeam().entries.toList();
              if (scores.length < 2) {
                return const SizedBox.shrink();
              }
              final team1 = scores[0];
              final team2 = scores[1];
              return SizedBox(
                height: 50,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        // Team 1 panel
                        Expanded(
                          child: Container(
                            margin: const EdgeInsets.only(right: 4),
                            padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(10),
                              boxShadow: [BoxShadow(blurRadius: 2, color: Colors.black12)],
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Flexible(
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text(
                                        '${team1.key.$1}',
                                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                        overflow: TextOverflow.fade,
                                        softWrap: false,
                                        maxLines: 1,
                                      ),
                                      Text(
                                        '${team1.key.$2}',
                                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                        overflow: TextOverflow.fade,
                                        softWrap: false,
                                        maxLines: 1,
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  '${team1.value}',
                                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(width: 6),
                              ],
                            ),
                          ),
                        ),
                        // Spacer for VS overlap
                        SizedBox(width: 8),
                        // Team 2 panel
                        Expanded(
                          child: Container(
                            margin: const EdgeInsets.only(left: 4),
                            padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(10),
                              boxShadow: [BoxShadow(blurRadius: 2, color: Colors.black12)],
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.start,
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                const SizedBox(width: 6),
                                Text(
                                  '${team2.value}',
                                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(width: 6),
                                Flexible(
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        '${team2.key.$1}',
                                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                        overflow: TextOverflow.fade,
                                        softWrap: false,
                                        maxLines: 1,
                                      ),
                                      Text(
                                        '${team2.key.$2}',
                                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                        overflow: TextOverflow.fade,
                                        softWrap: false,
                                        maxLines: 1,
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    // Overlapping VS box
                    Positioned(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.grey[400]!, width: 1),
                        ),
                        child: Text(
                          'VS',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: Colors.black87,
                            letterSpacing: 1.5,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildCurrentPlayer(
    GamePlayer player,
    MultiplayerGameState gameState,
    GameRoomController gameRoomController,
    Palette palette,
    bool canPlayCards,
    bool canReorderCards,
  ) {
    final isActive = gameState.currentPlayer?.username == player.username;

    return Container(
      height: 160,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: Column(
        children: [
          // Player info
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: isActive ? Colors.green.withOpacity(0.2) : Colors.transparent,
              borderRadius: BorderRadius.circular(20),
              border: isActive ? Border.all(color: Colors.green, width: 2) : null,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.person,
                  size: 16,
                  color: isActive ? Colors.green : palette.ink,
                ),
                const SizedBox(width: 4),
                Text(
                  player.username,
                  style: TextStyle(
                    color: isActive ? Colors.green : palette.ink,
                    fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
                if (isActive) ...[
                  const SizedBox(width: 4),
                  const Icon(Icons.play_arrow, size: 16, color: Colors.green),
                ],
              ],
            ),
          ),
          // Cards in hand
          Expanded(
            child: LayoutBuilder(builder: (context, constraints) {
              final handCount = _reorderableHand.length;
              final availableWidth = constraints.maxWidth;

              final double cardWidth = 70.0;
              final double cardHeight = cardWidth * 1.5;

              double step;
              double totalHandDisplayWidth;
              double startX;

              if (handCount == 0) {
                step = 0.0;
                totalHandDisplayWidth = 0.0;
                startX = 0.0;
              } else if (handCount == 1) {
                step = cardWidth;
                totalHandDisplayWidth = cardWidth;
                startX = (availableWidth - cardWidth) / 2;
              } else {
                final double idealStepToFillWidth = (availableWidth - cardWidth) / (handCount - 1);

                if (idealStepToFillWidth > cardWidth) {
                  step = cardWidth;
                } else {
                  step = idealStepToFillWidth;
                }

                totalHandDisplayWidth = cardWidth + (handCount - 1) * step;

                startX = (availableWidth - totalHandDisplayWidth) / 2;
              }

              final clampedStartX = startX;

              return SizedBox(
                height: cardHeight,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: _reorderableHand.asMap().entries.map((entry) {
                    final index = entry.key;
                    final card = entry.value;
                    final left = clampedStartX + index * step;

                    final cardWidget = PlayingCardWidget.multiplayer(
                      card: card,
                      isPlayable: canPlayCards,
                      customWidth: cardWidth,
                      customHeight: cardHeight,
                    );

                    return AnimatedPositioned(
                      key: ValueKey(card),
                      duration: const Duration(milliseconds: 180),
                      curve: Curves.easeOut,
                      left: left,
                      child: Draggable<PlayingCard>(
                        data: card,
                        feedback: Transform.rotate(
                          angle: -0.05,
                          child: PlayingCardWidget.multiplayer(
                            card: card,
                            isPlayable: false,
                            customWidth: 70,
                            customHeight: 100,
                          ),
                        ),
                        childWhenDragging: Opacity(
                          opacity: 0.4,
                          child: cardWidget,
                        ),
                        onDragEnd: (details) {
                          if (details.wasAccepted) {
                            _reorderableHand.removeAt(index);
                            return;
                          }

                          if (!canReorderCards || handCount < 2) {
                            return;
                          }

                          final renderBox = context.findRenderObject() as RenderBox?;
                          if (renderBox == null) {
                            return;
                          }

                          final localOffset = renderBox.globalToLocal(details.offset);
                          final targetIndex = ((localOffset.dx - clampedStartX + (step / 2)) / step)
                              .clamp(0, handCount - 1)
                              .round();

                          if (targetIndex != index) {
                            setState(() {
                              final item = _reorderableHand.removeAt(index);
                              final insertIndex = targetIndex > index ? targetIndex - 1 : targetIndex;
                              _reorderableHand.insert(insertIndex, item);
                            });
                          }
                        },
                        child: cardWidget,
                      ),
                    );
                  }).toList(),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildOtherPlayer(
    GamePlayer player,
    MultiplayerGameState gameState,
    Palette palette,
    double cardWidth,
    double cardHeight, {
    bool isEnemy = false,
  }) {
    final isActive = gameState.currentPlayer?.username == player.username;

    return SizedBox(
      width: cardWidth + 16,
      // Allow height to grow slightly if text wraps, but constrain width
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Card (face down)
          SizedBox(
            width: cardWidth,
            height: cardHeight,
            child: PlayingCardWidget.back(
              customWidth: cardWidth,
              customHeight: cardHeight,
              isRedBack: isEnemy,
            ),
          ),
          const SizedBox(height: 8),
          // Player info
          SizedBox(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
              decoration: BoxDecoration(
                color: isActive ? Colors.green.withOpacity(0.2) : Colors.transparent,
                borderRadius: BorderRadius.circular(20),
                border: isActive ? Border.all(color: Colors.green, width: 2) : null,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (isActive) ...[
                    const Icon(Icons.play_arrow, size: 14, color: Colors.green),
                  ] else ...[
                    Icon(Icons.person, size: 14, color: palette.ink),
                  ],
                  const SizedBox(width: 4),
                  Flexible(
                    child: Text(
                      player.username,
                      style: TextStyle(
                        color: isActive ? Colors.green : palette.ink,
                        fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                        fontSize: 12,
                      ),
                      overflow: TextOverflow.fade,
                      maxLines: 1,
                      softWrap: false,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
