import 'dart:math';

import 'package:flutter/foundation.dart';

import 'card_suit.dart';

@immutable
class PlayingCard {
  static final _random = Random();

  final CardSuit suit;

  final int value;

  const PlayingCard(this.suit, this.value);

  factory PlayingCard.fromJson(Map<String, dynamic> json) {
    return PlayingCard(
      CardSuit.values
          .singleWhere((e) => e.value == json['suit']),
      json['value'] as int,
    );
  }

  factory PlayingCard.random([Random? random]) {
    random ??= _random;
    // Values: Ace (1), 2-9, Jack (10), Queen (11), King (12)
    // Note: The '10' card itself is typically removed in 48-card Spanish decks,
    // where Jack is value 10, Knight 11, King 12.
    // If using a poker-style deck as per displayValue, then 10 is Jack.
    // Assuming values 1-12, where 10 is Jack.
    final values = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12];
    return PlayingCard(
      CardSuit.values[random.nextInt(CardSuit.values.length)],
      values[random.nextInt(values.length)],
    );
  }

  @override
  int get hashCode => Object.hash(suit, value);

  @override
  bool operator ==(Object other) {
    return other is PlayingCard && other.suit == suit && other.value == value;
  }

  // Helper to get the custom strength of a card value for comparison
  // Ranking order for Botifarra: 9 > A > K > Q > J > 8 > 7 > 6 > 5 > 4 > 3 > 2
  // Note: The '10' card is assumed to be removed from the deck if using values 1-12 with J, Q, K.
  // The 'J' card corresponds to value 10 in this implementation.
  int _getRankStrength(int cardValue) {
    switch (cardValue) {
      case 9: return 14; // Nou (Manilla) - Highest rank
      case 1: return 13; // As (Ace)
      case 12: return 12; // Rei (King)
      case 11: return 11; // Reina (Queen)
      case 10: return 10; // Cavall/Sota (Jack, value 10)
      case 8: return 8;
      case 7: return 7;
      case 6: return 6;
      case 5: return 5;
      case 4: return 4;
      case 3: return 3;
      case 2: return 2; // Lowest rank
      default: return 0; // Should not happen with valid card values
    }
  }

  @override
  /// Compares card values based on Botifarra ranking: 9 > A > K > Q > J > 8 > 7 > 6 > 5 > 4 > 3 > 2.
  bool operator >(Object other) {
    if (other is! PlayingCard) return false;
    return _getRankStrength(value) > _getRankStrength(other.value);
  }

  @override
  bool operator <(Object other) {
    if (other is! PlayingCard) return false;
    return _getRankStrength(value) < _getRankStrength(other.value);
  }

  @override
  bool operator >=(Object other) {
    if (other is! PlayingCard) return false;
    return _getRankStrength(value) >= _getRankStrength(other.value);
  }

  @override
  bool operator <=(Object other) {
    if (other is! PlayingCard) return false;
    return _getRankStrength(value) <= _getRankStrength(other.value);
  }


  Map<String, dynamic> toJson() => {
        'suit': suit.value,
        'value': value,
      };

  /// Get the display name for the card value
  String get displayValue {
    switch (value) {
      case 1:
        return 'A';
      case 10:
        return 'J';
      case 11:
        return 'Q';
      case 12:
        return 'K';
      default:
        return value.toString();
    }
  }

  /// Check if this is the 5 of spades (used to determine first player)
  bool get isFiveOfSpades => suit == CardSuit.spades && value == 5;

  @override
  String toString() {
    return '$suit$displayValue';
  }
}
