enum GameSuit {
  none(0),
  clubs(1),
  diamonds(2),
  hearts(3),
  spades(4),
  botifarra(5),
  delegate(6);
  
  final int value;
  
  const GameSuit(this.value);
  
  String get asCharacter => switch (this) {
    GameSuit.none => '',
    GameSuit.clubs => '♣',
    GameSuit.diamonds => '♦',
    GameSuit.hearts => '♥',
    GameSuit.spades => '♠',
    GameSuit.botifarra => '🃏',
    GameSuit.delegate => 'Delegate',
  };
  
  GameSuitColor get color => switch (this) {
    GameSuit.none => GameSuitColor.black,
    GameSuit.spades || GameSuit.clubs => GameSuitColor.black,
    GameSuit.diamonds || GameSuit.hearts => GameSuitColor.red,
    GameSuit.botifarra => GameSuitColor.black,
    GameSuit.delegate => GameSuitColor.black,
  };
  
  @override
  String toString() => asCharacter;
  
  int toJson() => value;
}

enum GameSuitColor {
  black,
  red,
}

enum GameMode {
  normal(0),
  contra(1),
  recontra(2),
  santVicenc(3);
  
  final int value;
  
  const GameMode(this.value);
  
  int toJson() => value;
}