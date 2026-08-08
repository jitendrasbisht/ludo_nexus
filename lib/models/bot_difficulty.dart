enum BotDifficulty { easy, medium, hard }

extension BotDifficultyX on BotDifficulty {
  String get label {
    switch (this) {
      case BotDifficulty.easy:
        return 'Easy';
      case BotDifficulty.medium:
        return 'Medium';
      case BotDifficulty.hard:
        return 'Hard';
    }
  }
}
