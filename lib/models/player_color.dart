enum PlayerColor { red, green, yellow, blue }

extension PlayerColorX on PlayerColor {
  String get label {
    switch (this) {
      case PlayerColor.red:
        return 'Red';
      case PlayerColor.green:
        return 'Green';
      case PlayerColor.yellow:
        return 'Yellow';
      case PlayerColor.blue:
        return 'Blue';
    }
  }
}
