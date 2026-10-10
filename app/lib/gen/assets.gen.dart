// dart format width=80

/// GENERATED CODE - DO NOT MODIFY BY HAND
/// *****************************************************
///  FlutterGen
/// *****************************************************

// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: deprecated_member_use,directives_ordering,implicit_dynamic_list_literal,unnecessary_import

import 'package:flutter/widgets.dart';

class $AssetsBrandGen {
  const $AssetsBrandGen();

  /// File path: assets/brand/formation_black.png
  AssetGenImage get formationBlack =>
      const AssetGenImage('assets/brand/formation_black.png');

  /// File path: assets/brand/formation_logo_nobg.png
  AssetGenImage get formationLogoNobg =>
      const AssetGenImage('assets/brand/formation_logo_nobg.png');

  /// File path: assets/brand/formation_white.png
  AssetGenImage get formationWhite =>
      const AssetGenImage('assets/brand/formation_white.png');

  /// List of all assets
  List<AssetGenImage> get values => [
    formationBlack,
    formationLogoNobg,
    formationWhite,
  ];
}

class $AssetsCharactersGen {
  const $AssetsCharactersGen();

  /// File path: assets/characters/analyst_celebrating.webp
  AssetGenImage get analystCelebrating =>
      const AssetGenImage('assets/characters/analyst_celebrating.webp');

  /// File path: assets/characters/analyst_concerned.webp
  AssetGenImage get analystConcerned =>
      const AssetGenImage('assets/characters/analyst_concerned.webp');

  /// File path: assets/characters/analyst_neutral.webp
  AssetGenImage get analystNeutral =>
      const AssetGenImage('assets/characters/analyst_neutral.webp');

  /// File path: assets/characters/analyst_thinking.webp
  AssetGenImage get analystThinking =>
      const AssetGenImage('assets/characters/analyst_thinking.webp');

  /// File path: assets/characters/maverick_celebrating.webp
  AssetGenImage get maverickCelebrating =>
      const AssetGenImage('assets/characters/maverick_celebrating.webp');

  /// File path: assets/characters/maverick_concerned.webp
  AssetGenImage get maverickConcerned =>
      const AssetGenImage('assets/characters/maverick_concerned.webp');

  /// File path: assets/characters/maverick_neutral.webp
  AssetGenImage get maverickNeutral =>
      const AssetGenImage('assets/characters/maverick_neutral.webp');

  /// File path: assets/characters/maverick_thinking.webp
  AssetGenImage get maverickThinking =>
      const AssetGenImage('assets/characters/maverick_thinking.webp');

  /// File path: assets/characters/mentor_celebrating.webp
  AssetGenImage get mentorCelebrating =>
      const AssetGenImage('assets/characters/mentor_celebrating.webp');

  /// File path: assets/characters/mentor_concerned.webp
  AssetGenImage get mentorConcerned =>
      const AssetGenImage('assets/characters/mentor_concerned.webp');

  /// File path: assets/characters/mentor_neutral.webp
  AssetGenImage get mentorNeutral =>
      const AssetGenImage('assets/characters/mentor_neutral.webp');

  /// File path: assets/characters/mentor_thinking.webp
  AssetGenImage get mentorThinking =>
      const AssetGenImage('assets/characters/mentor_thinking.webp');

  /// File path: assets/characters/scout_celebrating.webp
  AssetGenImage get scoutCelebrating =>
      const AssetGenImage('assets/characters/scout_celebrating.webp');

  /// File path: assets/characters/scout_concerned.webp
  AssetGenImage get scoutConcerned =>
      const AssetGenImage('assets/characters/scout_concerned.webp');

  /// File path: assets/characters/scout_neutral.webp
  AssetGenImage get scoutNeutral =>
      const AssetGenImage('assets/characters/scout_neutral.webp');

  /// File path: assets/characters/scout_thinking.webp
  AssetGenImage get scoutThinking =>
      const AssetGenImage('assets/characters/scout_thinking.webp');

  /// File path: assets/characters/veteran_celebrating.webp
  AssetGenImage get veteranCelebrating =>
      const AssetGenImage('assets/characters/veteran_celebrating.webp');

  /// File path: assets/characters/veteran_concerned.webp
  AssetGenImage get veteranConcerned =>
      const AssetGenImage('assets/characters/veteran_concerned.webp');

  /// File path: assets/characters/veteran_neutral.webp
  AssetGenImage get veteranNeutral =>
      const AssetGenImage('assets/characters/veteran_neutral.webp');

  /// File path: assets/characters/veteran_thinking.webp
  AssetGenImage get veteranThinking =>
      const AssetGenImage('assets/characters/veteran_thinking.webp');

  /// List of all assets
  List<AssetGenImage> get values => [
    analystCelebrating,
    analystConcerned,
    analystNeutral,
    analystThinking,
    maverickCelebrating,
    maverickConcerned,
    maverickNeutral,
    maverickThinking,
    mentorCelebrating,
    mentorConcerned,
    mentorNeutral,
    mentorThinking,
    scoutCelebrating,
    scoutConcerned,
    scoutNeutral,
    scoutThinking,
    veteranCelebrating,
    veteranConcerned,
    veteranNeutral,
    veteranThinking,
  ];
}

class $AssetsIconsGen {
  const $AssetsIconsGen();

  /// File path: assets/icons/.gitkeep
  String get aGitkeep => 'assets/icons/.gitkeep';

  /// File path: assets/icons/seeker.png
  AssetGenImage get seeker => const AssetGenImage('assets/icons/seeker.png');

  /// File path: assets/icons/solana.png
  AssetGenImage get solana => const AssetGenImage('assets/icons/solana.png');

  /// File path: assets/icons/usdc.png
  AssetGenImage get usdc => const AssetGenImage('assets/icons/usdc.png');

  /// List of all assets
  List<dynamic> get values => [aGitkeep, seeker, solana, usdc];
}

class $AssetsImagesGen {
  const $AssetsImagesGen();

  /// File path: assets/images/.gitkeep
  String get aGitkeep => 'assets/images/.gitkeep';

  /// List of all assets
  List<String> get values => [aGitkeep];
}

abstract final class Assets {
  static const $AssetsBrandGen brand = $AssetsBrandGen();
  static const $AssetsCharactersGen characters = $AssetsCharactersGen();
  static const $AssetsIconsGen icons = $AssetsIconsGen();
  static const $AssetsImagesGen images = $AssetsImagesGen();
}

class AssetGenImage {
  const AssetGenImage(
    this._assetName, {
    this.size,
    this.flavors = const {},
    this.animation,
  });

  final String _assetName;

  final Size? size;
  final Set<String> flavors;
  final AssetGenImageAnimation? animation;

  Image image({
    Key? key,
    AssetBundle? bundle,
    ImageFrameBuilder? frameBuilder,
    ImageErrorWidgetBuilder? errorBuilder,
    String? semanticLabel,
    bool excludeFromSemantics = false,
    double? scale,
    double? width,
    double? height,
    Color? color,
    Animation<double>? opacity,
    BlendMode? colorBlendMode,
    BoxFit? fit,
    AlignmentGeometry alignment = Alignment.center,
    ImageRepeat repeat = ImageRepeat.noRepeat,
    Rect? centerSlice,
    bool matchTextDirection = false,
    bool gaplessPlayback = true,
    bool isAntiAlias = false,
    String? package,
    FilterQuality filterQuality = FilterQuality.medium,
    int? cacheWidth,
    int? cacheHeight,
  }) {
    return Image.asset(
      _assetName,
      key: key,
      bundle: bundle,
      frameBuilder: frameBuilder,
      errorBuilder: errorBuilder,
      semanticLabel: semanticLabel,
      excludeFromSemantics: excludeFromSemantics,
      scale: scale,
      width: width,
      height: height,
      color: color,
      opacity: opacity,
      colorBlendMode: colorBlendMode,
      fit: fit,
      alignment: alignment,
      repeat: repeat,
      centerSlice: centerSlice,
      matchTextDirection: matchTextDirection,
      gaplessPlayback: gaplessPlayback,
      isAntiAlias: isAntiAlias,
      package: package,
      filterQuality: filterQuality,
      cacheWidth: cacheWidth,
      cacheHeight: cacheHeight,
    );
  }

  ImageProvider provider({AssetBundle? bundle, String? package}) {
    return AssetImage(_assetName, bundle: bundle, package: package);
  }

  String get path => _assetName;

  String get keyName => _assetName;
}

class AssetGenImageAnimation {
  const AssetGenImageAnimation({
    required this.isAnimation,
    required this.duration,
    required this.frames,
  });

  final bool isAnimation;
  final Duration duration;
  final int frames;
}
