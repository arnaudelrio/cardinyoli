import 'package:flutter/material.dart';
import 'package:flutter_img/flutter_img.dart';
import 'package:provider/provider.dart';

import '../audio/audio_controller.dart';
import '../audio/sounds.dart';
import '../game_internals/card_suit.dart';
import '../game_internals/playing_card.dart';
import '../settings/settings.dart';

class PlayingCardWidget extends StatelessWidget {
  // A standard playing card is 57.1mm x 88.9mm.
  static const double width = 57.1;
  static const double height = 88.9;

  final PlayingCard? card;
  final bool isPlayable;
  final bool showBack;
  final double? customWidth;
  final double? customHeight;

  final bool isRedBack;

  const PlayingCardWidget({
    this.card,
    this.isPlayable = true,
    this.showBack = false,
    this.customWidth = 60,
    this.customHeight = 80,
    this.isRedBack = false,
    super.key,
  });

  // Constructor for multiplayer mode
  const PlayingCardWidget.multiplayer({
    required this.card,
    required this.isPlayable,
    this.showBack = false,
    this.customWidth = 60,
    this.customHeight = 80,
    this.isRedBack = false,
    super.key,
  });

  // Constructor for card back
  const PlayingCardWidget.back({
    this.customWidth = 60,
    this.customHeight = 80,
    this.isRedBack = false,
    super.key,
  })  : card = null,
        isPlayable = false,
        showBack = true;

  /// Get the asset path for a card
  String _getCardAssetPath(PlayingCard? card, bool isPoker) {
    if (card == null) {
      return 'assets/cards/back${isRedBack ? '_red' : ''}.png';
    }

    // Map suit to letter
    String suitLetter;
    switch (card.suit) {
      case CardSuit.clubs:
        suitLetter = 'C';
        break;
      case CardSuit.diamonds:
        suitLetter = 'D';
        break;
      case CardSuit.hearts:
        suitLetter = 'H';
        break;
      case CardSuit.spades:
        suitLetter = 'S';
        break;
    }

    // Map value to letter/number
    String valueLetter;
    switch (card.value) {
      case 1:
        valueLetter = 'A';
        break;
      case 10:
        valueLetter = 'J';
        break;
      case 11:
        valueLetter = 'Q';
        break;
      case 12:
        valueLetter = 'K';
        break;
      default:
        valueLetter = card.value.toString();
        break;
    }

    // Get whether to use poker cards or regular cards
    String cardVersion = isPoker ? 'poker/' : 'catalan/';
    // String format = isPoker ? '.png' : '.jpg';

    return 'assets/cards/$cardVersion$valueLetter$suitLetter.jpg';
  }

  @override
  Widget build(BuildContext context) {
    final cardWidth = customWidth ?? width;
    final cardHeight = customHeight ?? height;
    final settings = context.read<SettingsController>();

    return ValueListenableBuilder<bool>(
      valueListenable: settings.usePokerCards,
      builder: (context, isPoker, _) {
        Widget cardWidget;

        if (showBack || card == null) {
          // Show card back
          final backAsset = isRedBack ? 'assets/cards/2B.jpg' : 'assets/cards/1B.jpg';
          cardWidget = SizedBox(
            width: cardWidth,
            height: cardHeight,
            child: Img(backAsset),
          );
        } else {
          // Show card front with error handling
          final assetPath = _getCardAssetPath(card!, isPoker);
          cardWidget = SizedBox(
            width: cardWidth,
            height: cardHeight,
            child: Img(
              assetPath,
              width: cardWidth,
              height: cardHeight,
              fit: BoxFit.contain,
            ),
          );
        }

        /// Cards that aren't in a player's hand are not draggable.
        if (!isPlayable) return cardWidget;

        return Draggable(
          feedback: Transform.rotate(
            angle: 0.1,
            child: cardWidget,
          ),
          data: PlayingCardDragData(card!),
          childWhenDragging: Opacity(
            opacity: 0.5,
            child: cardWidget,
          ),
          onDragStarted: () {
            final audioController = context.read<AudioController>();
            audioController.playSfx(SfxType.huhsh);
          },
          onDragEnd: (details) {
            final audioController = context.read<AudioController>();
            audioController.playSfx(SfxType.wssh);
          },
          child: cardWidget,
        );
      },
    );
  }
}

@immutable
class PlayingCardDragData {
  final PlayingCard card;

  const PlayingCardDragData(this.card);
}
