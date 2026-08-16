import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../game/ludo_engine.dart';
import '../models/bot_difficulty.dart';
import '../models/player.dart';
import '../models/player_color.dart';
import '../services/avatar_storage.dart';
import '../services/player_profile_store.dart';
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
  BotDifficulty botDifficulty = BotDifficulty.medium;

  _SlotConfig({required this.color, required this.name});
}

class _SetupScreenState extends State<SetupScreen> {
  int _playerCount = 4;
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
      for (var i = 0; i < saved.length && i < _slots.length; i++) {
        if (saved[i].name.isNotEmpty) _slots[i].name = saved[i].name;
        _slots[i].photoPath = saved[i].photoPath;
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

    await PlayerProfileStore.save([
      for (final slot in activeSlots.where((s) => s.isHuman))
        SavedProfile(name: slot.name, photoPath: slot.photoPath),
    ]);

    final players = [
      for (final slot in activeSlots)
        LudoPlayer(
          color: slot.color,
          name: slot.isHuman
              ? (slot.name.trim().isEmpty ? slot.color.label : slot.name.trim())
              : '${slot.color.label} Bot',
          isBot: !slot.isHuman,
          botDifficulty: slot.isHuman ? null : slot.botDifficulty,
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

    return Scaffold(
      appBar: AppBar(
        title: const Text('New Game'),
        backgroundColor: const Color(0xFF2A3E66),
        foregroundColor: Colors.white,
      ),
      body: AppBackground(
        child: SafeArea(
          child: _loadingProfiles
              ? const Center(child: CircularProgressIndicator())
              : Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          SegmentedButton<int>(
                            segments: const [
                              ButtonSegment(value: 2, label: Text('2')),
                              ButtonSegment(value: 3, label: Text('3')),
                              ButtonSegment(value: 4, label: Text('4')),
                            ],
                            selected: {_playerCount},
                            onSelectionChanged: (s) =>
                                setState(() => _playerCount = s.first),
                            style: ButtonStyle(
                              foregroundColor: WidgetStateProperty.resolveWith(
                                (states) =>
                                    states.contains(WidgetState.selected)
                                    ? Colors.black
                                    : Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: activeSlots.length,
                        itemBuilder: (context, index) => _SlotCard(
                          slot: activeSlots[index],
                          onPickPhoto: () => _pickPhoto(activeSlots[index]),
                          onChanged: () => setState(() {}),
                          onColorSelect: (color) =>
                              _swapColor(activeSlots[index], color),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          onPressed: _startGame,
                          child: const Padding(
                            padding: EdgeInsets.all(12),
                            child: Text(
                              'Start Game',
                              style: TextStyle(fontSize: 16),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

class _SlotCard extends StatelessWidget {
  final _SlotConfig slot;
  final VoidCallback onPickPhoto;
  final VoidCallback onChanged;
  final ValueChanged<PlayerColor> onColorSelect;

  const _SlotCard({
    required this.slot,
    required this.onPickPhoto,
    required this.onChanged,
    required this.onColorSelect,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFC7E0FA), Color(0xFF8FBEF0)],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.5)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF143264).withValues(alpha: 0.18),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
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
                    size: 42,
                    photoPath: slot.photoPath,
                    initial: slot.name.isNotEmpty
                        ? slot.name[0].toUpperCase()
                        : '?',
                    isBot: !slot.isHuman,
                  ),
                ),
                const SizedBox(width: 10),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (final color in PlayerColor.values)
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: GestureDetector(
                          onTap: () => onColorSelect(color),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 120),
                            width: 26,
                            height: 26,
                            decoration: BoxDecoration(
                              color: color.material,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: color == slot.color
                                    ? Colors.black87
                                    : Colors.white,
                                width: color == slot.color ? 3 : 1.5,
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                const Spacer(),
                const Text('Bot', style: TextStyle(fontSize: 12)),
                Transform.scale(
                  scale: 0.8,
                  child: Switch(
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    value: !slot.isHuman,
                    onChanged: (isBot) {
                      slot.isHuman = !isBot;
                      onChanged();
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            if (slot.isHuman)
              TextFormField(
                key: ValueKey('name_${slot.color.name}'),
                initialValue: slot.name,
                decoration: const InputDecoration(
                  hintText: 'Player name',
                  isDense: true,
                ),
                onChanged: (v) => slot.name = v,
              )
            else
              DropdownButton<BotDifficulty>(
                value: slot.botDifficulty,
                isExpanded: true,
                items: [
                  for (final d in BotDifficulty.values)
                    DropdownMenuItem(value: d, child: Text(d.label)),
                ],
                onChanged: (d) {
                  if (d != null) {
                    slot.botDifficulty = d;
                    onChanged();
                  }
                },
              ),
          ],
        ),
      ),
    );
  }
}
