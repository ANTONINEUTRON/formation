import 'package:flutter/material.dart';

import 'package:formation/core/theme/theme.dart';
import 'package:formation/features/assistant_manager/domain/assistant_models.dart';
import 'package:formation/features/assistant_manager/ui/widgets/character_view.dart';

/// "Pick your Assistant Manager": the five characters, swiped one at a time,
/// each standing in its neutral pose with its name, line and leaning.
class CharacterPicker extends StatefulWidget {
  const CharacterPicker({
    required this.characters,
    required this.onPicked,
    this.currentId,
    super.key,
  });

  final List<AssistantCharacter> characters;
  final Future<void> Function(String characterId) onPicked;

  /// Set when changing an existing choice, so the picker opens on it.
  final String? currentId;

  @override
  State<CharacterPicker> createState() => _CharacterPickerState();
}

class _CharacterPickerState extends State<CharacterPicker> {
  late final PageController _pages;
  late int _index;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _index = widget.currentId == null
        ? 0
        : widget.characters.indexWhere((c) => c.id == widget.currentId).clamp(0, 99);
    _pages = PageController(initialPage: _index, viewportFraction: 0.72);
  }

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final character = widget.characters[_index];
    return Column(
      children: [
        const SizedBox(height: 4),
        Text(
          'Pick your Assistant Manager',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: 4),
        const Text(
          'You make the calls. They advise.',
          style: TextStyle(color: AppColors.textSecondary),
        ),
        Expanded(
          child: PageView.builder(
            controller: _pages,
            itemCount: widget.characters.length,
            onPageChanged: (i) => setState(() => _index = i),
            itemBuilder: (context, i) {
              final selected = i == _index;
              return AnimatedScale(
                scale: selected ? 1 : 0.86,
                duration: const Duration(milliseconds: 200),
                child: AnimatedOpacity(
                  opacity: selected ? 1 : 0.45,
                  duration: const Duration(milliseconds: 200),
                  child: GestureDetector(
                    onTap: () => _pages.animateToPage(
                      i,
                      duration: const Duration(milliseconds: 250),
                      curve: Curves.easeOut,
                    ),
                    child: LayoutBuilder(
                      builder: (context, box) => Center(
                        child: CharacterFigure(
                          character: widget.characters[i],
                          pose: selected ? AssistantPose.celebrating : AssistantPose.neutral,
                          height: box.maxHeight,
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        _Dots(count: widget.characters.length, index: _index),
        const SizedBox(height: 12),
        Text(
          character.name,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w700,
              ),
        ),
        const SizedBox(height: 2),
        Text(
          character.tagline,
          textAlign: TextAlign.center,
          style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
        ),
        const SizedBox(height: 8),
        _StyleChip(style: character.style),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: _busy
                ? null
                : () async {
                    setState(() => _busy = true);
                    await widget.onPicked(character.id);
                    if (mounted) setState(() => _busy = false);
                  },
            child: Text(
              widget.currentId == character.id ? 'Keep ${character.name}' : 'Sign ${character.name}',
            ),
          ),
        ),
      ],
    );
  }
}

class _StyleChip extends StatelessWidget {
  const _StyleChip({required this.style});

  final String style;

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (style) {
      'safe' => ('Plays it safe', AppColors.tierStable),
      'bold' => ('Plays it bold', AppColors.warning),
      _ => ('Balanced', AppColors.tierBalanced),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.7)),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w600, letterSpacing: 0.4),
      ),
    );
  }
}

class _Dots extends StatelessWidget {
  const _Dots({required this.count, required this.index});

  final int count;
  final int index;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 0; i < count; i++)
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            margin: const EdgeInsets.symmetric(horizontal: 3),
            width: i == index ? 18 : 6,
            height: 6,
            decoration: BoxDecoration(
              color: i == index ? AppColors.primary : AppColors.border,
              borderRadius: BorderRadius.circular(3),
            ),
          ),
      ],
    );
  }
}
