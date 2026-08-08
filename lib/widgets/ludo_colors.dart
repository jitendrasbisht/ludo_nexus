import 'package:flutter/material.dart';

import '../models/player_color.dart';

extension PlayerColorPaint on PlayerColor {
  Color get material {
    switch (this) {
      case PlayerColor.red:
        return const Color(0xFFFF0000);
      case PlayerColor.green:
        return const Color(0xFF00B050);
      case PlayerColor.yellow:
        return const Color(0xFFFFFF00);
      case PlayerColor.blue:
        return const Color(0xFF00B0F0);
    }
  }
}
