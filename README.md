# Ludo (local pass-and-play + AI bots)

A fully offline Ludo game for Android: 2-4 players, any mix of humans
(pass-and-play on one device) and AI bots (easy/medium/hard). No network,
no accounts, no ads SDKs -- everything runs on-device.

## What's here

- `lib/models/` -- `Piece`, `LudoPlayer`, `PlayerColor`, `BotDifficulty`.
- `lib/game/` -- pure-Dart rules engine (`ludo_engine.dart`), board math
  (`board_path.dart`, `board_layout.dart`), dice (`dice_roller.dart`), and
  the AI (`ai_bot.dart`). No Flutter dependency, unit tested in isolation.
- `lib/widgets/` -- the `CustomPainter` board (`board_painter.dart`), the
  piece/photo avatar (`piece_avatar.dart`), and the widget that lays pieces
  out on top of the board (`board_widget.dart`).
- `lib/screens/` -- `setup_screen.dart` (player count, name/photo, bot
  difficulty) and `game_screen.dart` (board, dice, turn indicator, roll
  history/frequency panel, win dialog with replay).
- `lib/services/` -- `avatar_storage.dart` copies a picked photo into the
  app's own documents directory so it survives across launches;
  `player_profile_store.dart` persists player name + photo via
  `shared_preferences`.
- `test/ludo_engine_test.dart` -- engine unit tests (base exit, captures on
  safe/non-safe cells, extra turn on 6, three-6s forfeit, win detection).

## Running it on a physical Android device

1. Install [Flutter](https://docs.flutter.dev/get-started/install) and make
   sure `flutter doctor` reports no blocking issues for Android.
2. On your Android phone: enable Developer Options (Settings -> About
   phone -> tap "Build number" 7 times), then enable **USB debugging**
   inside Developer Options.
3. Plug the phone into your computer via USB and accept the "Allow USB
   debugging?" prompt on the phone.
4. From the project root:

   ```bash
   flutter pub get
   flutter devices        # confirm your phone shows up
   flutter run             # builds, installs, and launches on the phone
   ```

   Use `flutter run --release` for a faster, non-debug build once you're
   just playing rather than iterating on code.

5. To produce an installable APK without a debugger attached:

   ```bash
   flutter build apk --release
   ```

   The APK is written to `build/app/outputs/flutter-apk/app-release.apk`.

## Running the tests

```bash
flutter test
```

## Notes

- The dice (`DiceRoller`) intentionally uses `Random.secure()` with no
  seeding or weighting, and the game screen always shows the full roll
  history and per-face frequency -- this is a deliberate "provably fair"
  trust feature, not a debug leftover.
- Bots never touch the dice roll; they only decide which of the pieces the
  roll makes legal to move.
- Photos are displayed cropped to a circle at render time (no separate
  image-processing dependency); the underlying file is copied into the
  app's private storage the first time it's picked.
