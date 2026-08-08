import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../game/ludo_engine.dart';
import '../models/bot_difficulty.dart';
import '../models/player.dart';
import '../models/player_color.dart';
import '../services/avatar_storage.dart';
import '../services/player_profile_store.dart';
import '../widgets/ludo_colors.dart';
import '../widgets/piece_avatar.dart';
import 'game_screen.dart';

class SetupScreen extends StatefulWidget {
  const SetupScreen({super.key});

  @override
  State<SetupScreen> createState() => _SetupScreenState();
}

class _SlotConfig {
  final PlayerColor color;
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
      for (final color in PlayerColor.values) _SlotConfig(color: color, name: color.label),
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

    final stablePath = await AvatarStorage.persist(picked.path, slot.color.name);
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
    Navigator.of(context).push(MaterialPageRoute(
      builder: (context) => GameScreen(engine: LudoEngine(players: players)),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final activeSlots = _slots.take(_playerCount).toList();

    return Scaffold(
      appBar: AppBar(title: const Text('New Game')),
      body: _loadingProfiles
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      const Text('Players', style: TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(width: 16),
                      SegmentedButton<int>(
                        segments: const [
                          ButtonSegment(value: 2, label: Text('2')),
                          ButtonSegment(value: 3, label: Text('3')),
                          ButtonSegment(value: 4, label: Text('4')),
                        ],
                        selected: {_playerCount},
                        onSelectionChanged: (s) => setState(() => _playerCount = s.first),
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
                        child: Text('Start Game', style: TextStyle(fontSize: 16)),
                      ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}

class _SlotCard extends StatelessWidget {
  final _SlotConfig slot;
  final VoidCallback onPickPhoto;
  final VoidCallback onChanged;

  const _SlotCard({required this.slot, required this.onPickPhoto, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            GestureDetector(
              onTap: slot.isHuman ? onPickPhoto : null,
              child: PieceAvatar(
                color: slot.color,
                size: 56,
                photoPath: slot.photoPath,
                initial: slot.name.isNotEmpty ? slot.name[0].toUpperCase() : '?',
                isBot: !slot.isHuman,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        slot.color.label,
                        style: TextStyle(color: slot.color.material, fontWeight: FontWeight.bold),
                      ),
                      const Spacer(),
                      const Text('Bot'),
                      Switch(
                        value: !slot.isHuman,
                        onChanged: (isBot) {
                          slot.isHuman = !isBot;
                          onChanged();
                        },
                      ),
                    ],
                  ),
                  if (slot.isHuman)
                    TextFormField(
                      key: ValueKey('name_${slot.color.name}'),
                      initialValue: slot.name,
                      decoration: const InputDecoration(hintText: 'Player name', isDense: true),
                      onChanged: (v) => slot.name = v,
                    )
                  else
                    DropdownButton<BotDifficulty>(
                      value: slot.botDifficulty,
                      isExpanded: true,
                      items: [
                        for (final d in BotDifficulty.values) DropdownMenuItem(value: d, child: Text(d.label)),
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
          ],
        ),
      ),
    );
  }
}
