
import 'dart:math';

/// Encapsulates scores for both teams and the arithmetic to compute them.
class Score {
  final int team1Score;
  final int team2Score;

  const Score(this.team1Score, this.team2Score);
  
  factory Score.empty() {
    return Score(0, 0);
  }

  /// Factory to calculate scores with multipliers
  factory Score.calculate(List<int> rawScores, int mult) {
    final team1 = rawScores[0];
    final team2 = rawScores[1];
    
    if (team1 == team2) {
      return Score(0, 0);
    } else if (team1 > team2) {
      return Score(
        (team1 - 36) * pow(2, mult) as int,
        0,
      );
    } else {
      return Score(
        0,
        (team2 - 36) * pow(2, mult) as int,
      );
    }
  }

  /// Determine if the game is a tie
  bool get isTie => team1Score == team2Score;

  /// Determine the winning team (1 or 2), or null if tie
  int? get winningTeam => isTie ? null : (team1Score > team2Score ? 1 : 2);

  @override
  Map<String, dynamic> toJson() => {'team1Score': team1Score, 'team2Score': team2Score};
  
  Score operator +(Score other) => Score(team1Score + other.team1Score, team2Score + other.team2Score);
}
