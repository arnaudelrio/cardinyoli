enum CardSuit {
  clubs(1),
  spades(2),
  hearts(3),
  diamonds(4);

  final int value;

  const CardSuit(this.value);

  String get asCharacter => switch (this) {
    CardSuit.spades => '♠',
    CardSuit.hearts => '♥',
    CardSuit.diamonds => '♦',
    CardSuit.clubs => '♣'
  };

  CardSuitColor get color => switch (this) {
    CardSuit.spades || CardSuit.clubs => CardSuitColor.black,
    CardSuit.hearts || CardSuit.diamonds => CardSuitColor.red
  };

  @override
  String toString() => asCharacter;
  
  int toJson() => value;
}

enum CardSuitColor {
  black,
  red,
}
