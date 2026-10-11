import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:formation/core/theme/theme.dart';
import 'package:formation/features/assistant_manager/domain/assistant_models.dart';
import 'package:formation/features/assistant_manager/ui/cubits/assistant_cubit.dart';

/// Source art is 848×1264 with the feet on the same line in every pose.
const _artAspect = 848 / 1264;

/// The picture for [character] in [pose]: the bundled art for a preset, or
/// the drawing fetched for a custom one (a placeholder until it arrives).
Widget _art(
  BuildContext context,
  AssistantCharacter character,
  AssistantPose pose, {
  double? width,
  double? height,
  BoxFit fit = BoxFit.contain,
  Alignment alignment = Alignment.center,
}) {
  final key = ValueKey('${character.id}_${pose.name}');
  if (!character.isCustom) {
    return Image.asset(
      character.image(pose),
      key: key,
      width: width,
      height: height,
      fit: fit,
      alignment: alignment,
      gaplessPlayback: true,
    );
  }
  Uint8List? bytes;
  try {
    final images = context.select<AssistantCubit, Map<AssistantPose, Uint8List>>((c) => c.state.avatarImages);
    bytes = images[pose] ?? images[AssistantPose.neutral];
  } on ProviderNotFoundException {
    bytes = null; // outside the signed-in app (onboarding) there is no custom character
  }
  if (bytes == null) {
    return SizedBox(
      key: key,
      width: width,
      height: height,
      child: const Center(child: Icon(Icons.person, color: AppColors.textMuted)),
    );
  }
  return Image.memory(
    bytes,
    key: key,
    width: width,
    height: height,
    fit: fit,
    alignment: alignment,
    gaplessPlayback: true,
  );
}

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
    Widget figure = AnimatedSwitcher(
      duration: const Duration(milliseconds: 280),
      child: _art(context, character, pose, height: height, width: height * _artAspect),
    );
    // A drawn avatar keeps its dark backdrop (it isn't cut out like the
    // presets), so it's framed rather than left as a hard-edged rectangle.
    if (character.isCustom) {
      figure = ClipRRect(borderRadius: BorderRadius.circular(18), child: figure);
    }

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
            child: _art(
              context,
              character,
              pose,
              width: artWidth,
              fit: BoxFit.fitWidth,
              alignment: Alignment.topCenter,
            ),
          ),
        ),
      ),
    );
  }
}
