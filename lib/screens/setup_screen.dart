import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../game/ludo_engine.dart';
import '../models/app_bg_theme.dart';
import '../models/bot_difficulty.dart';
import '../models/player.dart';
import '../models/player_color.dart';
import '../services/avatar_storage.dart';
import '../services/player_profile_store.dart';
import '../services/theme_store.dart';
import '../widgets/app_background.dart';
import '../widgets/ludo_colors.dart';
import '../widgets/piece_avatar.dart';
import 'game_screen.dart';

class SetupScreen extends StatefulWidget {
  const SetupScreen({super.key});

  @override
  State<SetupScreen> createState() => _SetupScreenState();
}

class _SlotConfig {
  PlayerColor color;
  String name;
  bool isHuman = true;
  String? photoPath;

  _SlotConfig({required this.color, required this.name});
}

class _SetupScreenState extends State<SetupScreen> {
  int _playerCount = 4;
  BotDifficulty _botDifficulty = BotDifficulty.medium;
  late List<_SlotConfig> _slots;
  final _picker = ImagePicker();
  bool _loadingProfiles = true;

  @override
  void initState() {
    super.initState();
    _slots = [
      for (var i = 0; i < PlayerColor.values.length; i++)
        _SlotConfig(color: PlayerColor.values[i], name: 'Player ${i + 1}'),
    ];
    _loadSavedProfiles();
  }

  Future<void> _loadSavedProfiles() async {
    final saved = await PlayerProfileStore.load();
    if (!mounted) return;
    setState(() {
      // Name is remembered across launches; photo is deliberately not --
      // it resets to blank every time the app is closed and reopened.
      for (var i = 0; i < saved.length && i < _slots.length; i++) {
        if (saved[i].name.isEmpty) continue;
        _slots[i].name = saved[i].name;
      }
      _loadingProfiles = false;
    });
  }

  void _swapColor(_SlotConfig slot, PlayerColor newColor) {
    if (slot.color == newColor) return;
    final other = _slots.firstWhere((s) => s.color == newColor);
    setState(() {
      final oldColor = slot.color;
      slot.color = newColor;
      other.color = oldColor;
    });
  }

  Future<void> _pickPhoto(_SlotConfig slot) async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera),
              title: const Text('Take a photo'),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Choose from gallery'),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (source == null) return;

    final picked = await _picker.pickImage(source: source, imageQuality: 85);
    if (picked == null) return;

    final stablePath = await AvatarStorage.persist(
      picked.path,
      slot.color.name,
    );
    if (!mounted) return;
    setState(() => slot.photoPath = stablePath);
  }

  Future<void> _startGame() async {
    final activeSlots = _slots.take(_playerCount).toList();

    // Always save one entry per slot index (not just the active/human
    // ones) so a reload lines back up positionally -- otherwise skipping
    // a bot slot here shifts every later slot's saved name/photo up by
    // one on the next launch (see _loadSavedProfiles).
    await PlayerProfileStore.save([
      for (var i = 0; i < _slots.length; i++)
        if (i < _playerCount && _slots[i].isHuman)
          SavedProfile(name: _slots[i].name)
        else
          const SavedProfile(name: ''),
    ]);

    final players = [
      for (final slot in activeSlots)
        LudoPlayer(
          color: slot.color,
          name: slot.isHuman
              ? (slot.name.trim().isEmpty ? slot.color.label : slot.name.trim())
              : '${slot.color.label} Bot',
          isBot: !slot.isHuman,
          botDifficulty: slot.isHuman ? null : _botDifficulty,
          photoPath: slot.isHuman ? slot.photoPath : null,
        ),
    ];

    if (!mounted) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => GameScreen(engine: LudoEngine(players: players)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final activeSlots = _slots.take(_playerCount).toList();

    return ValueListenableBuilder(
      valueListenable: ThemeStore.current,
      builder: (context, theme, _) => Scaffold(
        appBar: PreferredSize(
          preferredSize: const Size.fromHeight(kToolbarHeight),
          child: AppBar(
            title: const Text('New Game'),
            backgroundColor: theme.appBarColor,
            foregroundColor: Colors.white,
          ),
        ),
        body: AppBackground(
          child: SafeArea(
            child: _loadingProfiles
                ? const Center(child: CircularProgressIndicator())
                // The whole page scrolls as one piece -- previously the
                // player list was the only scrollable region (Expanded +
                // ListView) sandwiched between fixed selectors above and
                // the theme row/Start button below, so with 3-4 players
                // the last slot card would run out of room and visually
                // collide with the fixed content beneath it instead of
                // scrolling into view cleanly.
                : SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                          child: Center(
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 240),
                              child: _CountSelector3D(
                                value: _playerCount,
                                theme: theme,
                                onChanged: (v) => setState(() => _playerCount = v),
                              ),
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                          child: Center(
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 240),
                              child: _DifficultySelector3D(
                                value: _botDifficulty,
                                theme: theme,
                                onChanged: (d) => setState(() => _botDifficulty = d),
                              ),
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Column(
                            children: [
                              for (final slot in activeSlots)
                                Center(
                                  child: ConstrainedBox(
                                    constraints: const BoxConstraints(maxWidth: 240),
                                    child: _SlotCard(
                                      slot: slot,
                                      theme: theme,
                                      onPickPhoto: () => _pickPhoto(slot),
                                      onChanged: () => setState(() {}),
                                      onColorSelect: (color) => _swapColor(slot, color),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                          child: Center(
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 240),
                              child: _ThemeRow(current: theme),
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: Center(
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 240),
                              child: _GlossyButton(label: 'Start Game', theme: theme, onTap: _startGame),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}

/// A glossy inset-track segmented control for the 2/3/4 player-count
/// choice -- a real physical-toggle look (dark recessed track, raised
/// cream tab on the selected value) instead of Material's flat
/// [SegmentedButton].
class _CountSelector3D extends StatelessWidget {
  final int value;
  final AppBgTheme theme;
  final ValueChanged<int> onChanged;

  const _CountSelector3D({required this.value, required this.theme, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final kids = theme.isKids;
    return Container(
      padding: EdgeInsets.all(kids ? 4 : 5),
      decoration: BoxDecoration(
        color: kids ? Colors.white : Colors.black.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(kids ? 14 : 16),
        border: kids ? Border.all(color: const Color(0xFF1B1B1B), width: 2.5) : null,
        boxShadow: kids
            ? null
            : [BoxShadow(color: Colors.black.withValues(alpha: 0.35), blurRadius: 4, blurStyle: BlurStyle.inner)],
      ),
      child: Row(
        children: [
          for (final count in [2, 3, 4]) ...[
            Expanded(child: _segment(count)),
            if (count != 4) SizedBox(width: kids ? 5 : 6),
          ],
        ],
      ),
    );
  }

  Widget _segment(int count) {
    final selected = count == value;
    final kids = theme.isKids;
    return GestureDetector(
      onTap: () => onChanged(count),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: EdgeInsets.symmetric(vertical: kids ? 6 : 9),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: kids && selected ? const Color(0xFF3FA9DB) : null,
          border: kids && selected ? Border.all(color: const Color(0xFF1B1B1B), width: 2.5) : null,
          gradient: !kids && selected
              ? const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFFFFFDF7), Color(0xFFE8DDC0)],
                )
              : null,
          boxShadow: !kids && selected
              ? [
                  BoxShadow(color: Colors.white.withValues(alpha: 0.9), blurRadius: 2, blurStyle: BlurStyle.inner, offset: const Offset(0, 1)),
                  BoxShadow(color: Colors.black.withValues(alpha: 0.12), blurRadius: 3, blurStyle: BlurStyle.inner, offset: const Offset(0, -2)),
                  BoxShadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 6, offset: const Offset(0, 3)),
                ]
              : null,
        ),
        child: Center(
          child: Text(
            '$count',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: kids
                  ? (selected ? Colors.white : const Color(0xFF1B1B1B))
                  : (selected ? const Color(0xFF7A5A1F) : Colors.white.withValues(alpha: 0.6)),
            ),
          ),
        ),
      ),
    );
  }
}

/// A single app-wide difficulty picker for every bot slot at once, in the
/// same glossy segmented-track style as [_CountSelector3D] -- replaces the
/// old per-slot dropdown so choosing "Easy" applies to all bots in the
/// match instead of needing to be set on each one individually.
class _DifficultySelector3D extends StatelessWidget {
  final BotDifficulty value;
  final AppBgTheme theme;
  final ValueChanged<BotDifficulty> onChanged;

  const _DifficultySelector3D({required this.value, required this.theme, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final kids = theme.isKids;
    return Container(
      padding: EdgeInsets.all(kids ? 4 : 5),
      decoration: BoxDecoration(
        color: kids ? Colors.white : Colors.black.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(kids ? 14 : 16),
        border: kids ? Border.all(color: const Color(0xFF1B1B1B), width: 2.5) : null,
        boxShadow: kids
            ? null
            : [BoxShadow(color: Colors.black.withValues(alpha: 0.35), blurRadius: 4, blurStyle: BlurStyle.inner)],
      ),
      child: Row(
        children: [
          for (final d in BotDifficulty.values) ...[
            Expanded(child: _segment(d)),
            if (d != BotDifficulty.hard) SizedBox(width: kids ? 5 : 6),
          ],
        ],
      ),
    );
  }

  Widget _segment(BotDifficulty d) {
    final selected = d == value;
    final kids = theme.isKids;
    return GestureDetector(
      onTap: () => onChanged(d),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: EdgeInsets.symmetric(vertical: kids ? 6 : 9),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: kids && selected ? const Color(0xFF3FA9DB) : null,
          border: kids && selected ? Border.all(color: const Color(0xFF1B1B1B), width: 2.5) : null,
          gradient: !kids && selected
              ? const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFFFFFDF7), Color(0xFFE8DDC0)],
                )
              : null,
          boxShadow: !kids && selected
              ? [
                  BoxShadow(color: Colors.white.withValues(alpha: 0.9), blurRadius: 2, blurStyle: BlurStyle.inner, offset: const Offset(0, 1)),
                  BoxShadow(color: Colors.black.withValues(alpha: 0.12), blurRadius: 3, blurStyle: BlurStyle.inner, offset: const Offset(0, -2)),
                  BoxShadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 6, offset: const Offset(0, 3)),
                ]
              : null,
        ),
        child: Center(
          child: Text(
            d.label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: kids
                  ? (selected ? Colors.white : const Color(0xFF1B1B1B))
                  : (selected ? const Color(0xFF7A5A1F) : Colors.white.withValues(alpha: 0.6)),
            ),
          ),
        ),
      ),
    );
  }
}

/// A compact 3D on/off toggle in the same bevel language as the rest of
/// the app, replacing Material's flat [Switch].
class _Toggle3D extends StatelessWidget {
  final bool value;
  final AppBgTheme theme;
  final ValueChanged<bool> onChanged;

  const _Toggle3D({required this.value, required this.theme, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final kids = theme.isKids;
    return GestureDetector(
      onTap: () => onChanged(!value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: 30,
        height: 18,
        padding: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(9),
          color: kids ? (value ? const Color(0xFF57C23A) : Colors.white) : null,
          border: kids ? Border.all(color: const Color(0xFF1B1B1B), width: 2) : null,
          gradient: kids
              ? null
              : LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: value ? const [Color(0xFF4A5F92), Color(0xFF2A3E66)] : const [Color(0xFFB9C4D6), Color(0xFF8F9DB4)],
                ),
          boxShadow: kids ? null : const [BoxShadow(color: Colors.black26, blurRadius: 3, blurStyle: BlurStyle.inner, offset: Offset(0, 1))],
        ),
        child: AnimatedAlign(
          duration: const Duration(milliseconds: 150),
          curve: Curves.easeOut,
          alignment: value ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            width: 14,
            height: 14,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: kids ? Colors.white : null,
              border: kids ? Border.all(color: const Color(0xFF1B1B1B), width: 1.5) : null,
              gradient: kids
                  ? null
                  : const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Colors.white, Color(0xFFDBE2EE)],
                    ),
              boxShadow: kids ? null : [BoxShadow(color: Colors.black.withValues(alpha: 0.4), blurRadius: 2, offset: const Offset(0, 1))],
            ),
          ),
        ),
      ),
    );
  }
}

/// A glossy navy pill button, matching the leave-game dialog's button
/// style, used for the primary "Start Game" action.
class _GlossyButton extends StatelessWidget {
  final String label;
  final AppBgTheme theme;
  final VoidCallback onTap;

  const _GlossyButton({required this.label, required this.theme, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final kids = theme.isKids;
    return SizedBox(
      width: double.infinity,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(24),
          child: Container(
            padding: EdgeInsets.symmetric(vertical: kids ? 11 : 14),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              color: kids ? const Color(0xFFFF5C5C) : null,
              border: kids ? Border.all(color: const Color(0xFF1B1B1B), width: 3) : null,
              gradient: kids
                  ? null
                  : const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFF4A5F92), Color(0xFF1C2C4E)],
                    ),
              boxShadow: kids
                  ? [BoxShadow(color: Colors.black.withValues(alpha: 0.35), offset: const Offset(2, 2))]
                  : [
                      BoxShadow(color: Colors.white.withValues(alpha: 0.3), blurRadius: 3, blurStyle: BlurStyle.inner, offset: const Offset(0, 2)),
                      BoxShadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 6, blurStyle: BlurStyle.inner, offset: const Offset(0, -5)),
                      BoxShadow(color: Colors.black.withValues(alpha: 0.35), blurRadius: 10, offset: const Offset(0, 5)),
                    ],
            ),
            child: Text(label, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
          ),
        ),
      ),
    );
  }
}

class _SlotCard extends StatelessWidget {
  final _SlotConfig slot;
  final AppBgTheme theme;
  final VoidCallback onPickPhoto;
  final VoidCallback onChanged;
  final ValueChanged<PlayerColor> onColorSelect;

  const _SlotCard({
    required this.slot,
    required this.theme,
    required this.onPickPhoto,
    required this.onChanged,
    required this.onColorSelect,
  });

  @override
  Widget build(BuildContext context) {
    final kids = theme.isKids;
    return Container(
      margin: EdgeInsets.symmetric(vertical: kids ? 3 : 4),
      decoration: BoxDecoration(
        color: kids ? Colors.white : null,
        gradient: kids
            ? null
            : const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFFC7E0FA), Color(0xFF8FBEF0)],
              ),
        borderRadius: BorderRadius.circular(14),
        border: kids ? Border.all(color: const Color(0xFF1B1B1B), width: 2.5) : null,
        boxShadow: kids
            ? [BoxShadow(color: Colors.black.withValues(alpha: 0.25), offset: const Offset(2, 2))]
            : [
                BoxShadow(color: Colors.white.withValues(alpha: 0.7), blurRadius: 2, blurStyle: BlurStyle.inner, offset: const Offset(0, 2)),
                BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 6, blurStyle: BlurStyle.inner, offset: const Offset(0, -6)),
                BoxShadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 8, offset: const Offset(0, 4)),
              ],
      ),
      child: Padding(
        padding: kids ? const EdgeInsets.fromLTRB(9, 6, 9, 6) : const EdgeInsets.fromLTRB(10, 8, 10, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                GestureDetector(
                  onTap: slot.isHuman ? onPickPhoto : null,
                  child: PieceAvatar(
                    color: slot.color,
                    size: kids ? 29 : 34,
                    photoPath: slot.photoPath,
                    initial: slot.name.isNotEmpty ? slot.name[0].toUpperCase() : '?',
                    isBot: !slot.isHuman,
                  ),
                ),
                SizedBox(width: kids ? 7 : 8),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (final color in PlayerColor.values)
                      Padding(
                        padding: EdgeInsets.only(right: kids ? 5 : 6),
                        child: GestureDetector(
                          onTap: () => onColorSelect(color),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 120),
                            width: kids ? 18 : 21,
                            height: kids ? 18 : 21,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: RadialGradient(
                                center: const Alignment(-0.3, -0.3),
                                colors: [Color.lerp(color.material, Colors.white, 0.45)!, color.material],
                              ),
                              boxShadow: const [
                                BoxShadow(color: Colors.black26, blurRadius: 3, blurStyle: BlurStyle.inner, offset: Offset(0, -2)),
                                BoxShadow(color: Colors.white54, blurRadius: 2, blurStyle: BlurStyle.inner, offset: Offset(0, 1.5)),
                              ],
                              border: Border.all(
                                color: kids
                                    ? const Color(0xFF1B1B1B)
                                    : (color == slot.color ? Colors.black87 : Colors.white),
                                width: color == slot.color ? (kids ? 3.5 : 3) : (kids ? 2 : 1.5),
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(width: 6),
                const Text('Bot', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                const SizedBox(width: 5),
                _Toggle3D(
                  value: !slot.isHuman,
                  theme: theme,
                  onChanged: (isBot) {
                    slot.isHuman = !isBot;
                    onChanged();
                  },
                ),
              ],
            ),
            const SizedBox(height: 4),
            if (slot.isHuman)
              TextFormField(
                key: ValueKey('name_${slot.color.name}'),
                initialValue: slot.name,
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                decoration: const InputDecoration(
                  hintText: 'Player name',
                  isDense: true,
                ),
                onChanged: (v) => slot.name = v,
              ),
          ],
        ),
      ),
    );
  }
}

/// A full-width, clearly-labeled row above Start Game that opens
/// [_ThemePickerSheet] -- replaces the old AppBar corner icon, which was
/// easy to miss entirely. Shows a beautified gradient palette icon plus
/// the current theme's name so the active choice is visible at a glance.
class _ThemeRow extends StatelessWidget {
  final AppBgTheme current;

  const _ThemeRow({required this.current});

  Future<void> _openPicker(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => _ThemePickerSheet(current: current),
    );
  }

  @override
  Widget build(BuildContext context) {
    final kids = current.isKids;
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: () => _openPicker(context),
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          decoration: BoxDecoration(
            color: kids ? Colors.white : Colors.black.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(14),
            border: kids ? Border.all(color: const Color(0xFF1B1B1B), width: 2.5) : null,
            boxShadow: kids
                ? [BoxShadow(color: Colors.black.withValues(alpha: 0.2), offset: const Offset(3, 3))]
                : [BoxShadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 4, blurStyle: BlurStyle.inner)],
          ),
          child: Row(
            children: [
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const SweepGradient(
                    colors: [
                      Color(0xFFE85D8A),
                      Color(0xFFE8B84B),
                      Color(0xFF6EC6FF),
                      Color(0xFF8A5CD6),
                      Color(0xFFE85D8A),
                    ],
                  ),
                  border: kids ? Border.all(color: const Color(0xFF1B1B1B), width: 2) : null,
                  boxShadow: const [
                    BoxShadow(color: Colors.black26, blurRadius: 3, blurStyle: BlurStyle.inner, offset: Offset(0, -1)),
                  ],
                ),
                child: const Icon(Icons.palette_rounded, color: Colors.white, size: 16),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Theme: ${current.label}',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: kids ? const Color(0xFF1B1B1B) : Colors.white,
                  ),
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: kids ? const Color(0xFF1B1B1B) : Colors.white.withValues(alpha: 0.7),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Tapping a swatch applies that theme immediately (live preview) but
/// keeps the sheet open, so you can flip through a few before settling --
/// it only closes when you tap outside it (the modal scrim) or swipe it
/// down, not the instant you pick something.
class _ThemePickerSheet extends StatefulWidget {
  final AppBgTheme current;

  const _ThemePickerSheet({required this.current});

  @override
  State<_ThemePickerSheet> createState() => _ThemePickerSheetState();
}

class _ThemePickerSheetState extends State<_ThemePickerSheet> {
  late AppBgTheme _selected = widget.current;

  void _choose(AppBgTheme theme) {
    if (theme == _selected) return;
    setState(() => _selected = theme);
    ThemeStore.select(theme);
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Container(
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 22),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFFDF6E6), Color(0xFFF2E6C4)],
          ),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.35), blurRadius: 24, offset: const Offset(0, 10))],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Choose a theme',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF2A3E66)),
            ),
            const SizedBox(height: 4),
            Text(
              'Tap outside to close',
              style: TextStyle(fontSize: 11, color: const Color(0xFF2A3E66).withValues(alpha: 0.55)),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                for (final theme in AppBgTheme.values)
                  GestureDetector(
                    onTap: () => _choose(theme),
                    child: Column(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: RadialGradient(
                              center: const Alignment(-0.3, -0.3),
                              colors: [Color.lerp(theme.swatchColor, Colors.white, 0.35)!, theme.swatchColor],
                            ),
                            border: Border.all(
                              color: theme == _selected ? Colors.black87 : Colors.white,
                              width: theme == _selected ? 3 : 1.5,
                            ),
                            boxShadow: const [
                              BoxShadow(color: Colors.black26, blurRadius: 4, blurStyle: BlurStyle.inner, offset: Offset(0, -2)),
                              BoxShadow(color: Colors.white54, blurRadius: 2, blurStyle: BlurStyle.inner, offset: Offset(0, 1.5)),
                            ],
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          theme.label,
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF2A3E66)),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
