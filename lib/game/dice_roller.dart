import 'dart:math';

/// Rolls a fair, uniformly-random 6-sided die and keeps a full history of
/// every roll made during a match. The history is exposed so the UI can
/// show players a transparent roll log / frequency chart -- this is the
/// "provably fair" trust feature: nothing about the dice is hidden or
/// weighted, and players can check the distribution themselves.
class DiceRoller {
  final Random _random = Random.secure();
  final List<int> history = [];

  int roll() {
    final value = _random.nextInt(6) + 1;
    history.add(value);
    return value;
  }

  /// Count of how many times each face (1-6) has come up this match.
  Map<int, int> get frequency {
    final freq = {for (var i = 1; i <= 6; i++) i: 0};
    for (final v in history) {
      freq[v] = (freq[v] ?? 0) + 1;
    }
    return freq;
  }

  void reset() => history.clear();
}
