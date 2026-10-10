import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import 'package:formation/core/theme/theme.dart';
import 'package:formation/features/assistant_manager/domain/assistant_models.dart';

/// Source art is 848×1264 with the feet on the same line in every pose.
const _artAspect = 848 / 1264;

/// The character, full height, idling with a slow bob and cross-fading between
/// poses. A lime glow sits behind it so it reads against the glass.
class CharacterFigure extends StatelessWidget {
  const CharacterFigure({required this.character, required this.pose, this.height = 260, super.key});

  final AssistantCharacter character;
  final AssistantPose pose;
  final double height;

  @override
  Widget build(BuildContext context) {
    final still = MediaQuery.disableAnimationsOf(context);
    final figure = AnimatedSwitcher(
      duration: const Duration(milliseconds: 280),
      child: Image.asset(
        character.image(pose),
        key: ValueKey('${character.id}_${pose.name}'),
        height: height,
        width: height * _artAspect,
        fit: BoxFit.contain,
        gaplessPlayback: true,
      ),
    );

    return SizedBox(
      height: height,
      width: height * _artAspect,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: const Alignment(0, -0.3),
                  radius: 0.7,
                  colors: [AppColors.primary.withValues(alpha: 0.18), Colors.transparent],
                ),
              ),
            ),
          ),
          if (still)
            figure
          else
            figure
                .animate(onPlay: (c) => c.repeat(reverse: true))
                .moveY(begin: 0, end: -4, duration: 1800.ms, curve: Curves.easeInOut),
        ],
      ),
    );
  }
}

/// Head and shoulders, cropped from the full figure, for the sheet header.
class CharacterHead extends StatelessWidget {
  const CharacterHead({required this.character, required this.pose, this.size = 52, super.key});

  final AssistantCharacter character;
  final AssistantPose pose;
  final double size;

  @override
  Widget build(BuildContext context) {
    // Scaled so the head fills the circle: the art's head sits in roughly the
    // top fifth of the canvas, centred.
    final artWidth = size * 2.7;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.surfaceElevated,
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.6), width: 1.5),
      ),
      clipBehavior: Clip.antiAlias,
      child: OverflowBox(
        maxWidth: artWidth,
        maxHeight: artWidth / _artAspect,
        alignment: const Alignment(0, -1),
        child: Transform.translate(
          offset: Offset(0, -size * 0.12),
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 280),
            child: Image.asset(
              character.image(pose),
              key: ValueKey('${character.id}_${pose.name}'),
              width: artWidth,
              fit: BoxFit.fitWidth,
              alignment: Alignment.topCenter,
              gaplessPlayback: true,
            ),
          ),
        ),
      ),
    );
  }
}
