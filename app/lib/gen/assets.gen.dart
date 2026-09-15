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

  /// File path: assets/brand/symbians_black.png
  AssetGenImage get symbiansBlack =>
      const AssetGenImage('assets/brand/symbians_black.png');

  /// File path: assets/brand/symbians_logo_1024.png
  AssetGenImage get symbiansLogo1024 =>
      const AssetGenImage('assets/brand/symbians_logo_1024.png');

  /// File path: assets/brand/symbians_logo_nobg.png
  AssetGenImage get symbiansLogoNobg =>
      const AssetGenImage('assets/brand/symbians_logo_nobg.png');

  /// File path: assets/brand/symbians_white.png
  AssetGenImage get symbiansWhite =>
      const AssetGenImage('assets/brand/symbians_white.png');

  /// List of all assets
  List<AssetGenImage> get values => [
    symbiansBlack,
    symbiansLogo1024,
    symbiansLogoNobg,
    symbiansWhite,
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

class $AssetsSpritesGen {
  const $AssetsSpritesGen();

  /// Directory path: assets/sprites/grass
  $AssetsSpritesGrassGen get grass => const $AssetsSpritesGrassGen();

  /// File path: assets/sprites/grass03.png
  AssetGenImage get grass03 =>
      const AssetGenImage('assets/sprites/grass03.png');

  /// List of all assets
  List<AssetGenImage> get values => [grass03];
}

class $AssetsSpritesGrassGen {
  const $AssetsSpritesGrassGen();

  /// File path: assets/sprites/grass/Grass01.png
  AssetGenImage get grass01 =>
      const AssetGenImage('assets/sprites/grass/Grass01.png');

  /// File path: assets/sprites/grass/Grass02.png
  AssetGenImage get grass02 =>
      const AssetGenImage('assets/sprites/grass/Grass02.png');

  /// File path: assets/sprites/grass/Grass03.png
  AssetGenImage get grass03 =>
      const AssetGenImage('assets/sprites/grass/Grass03.png');

  /// File path: assets/sprites/grass/Grass04.png
  AssetGenImage get grass04 =>
      const AssetGenImage('assets/sprites/grass/Grass04.png');

  /// File path: assets/sprites/grass/Grass05.png
  AssetGenImage get grass05 =>
      const AssetGenImage('assets/sprites/grass/Grass05.png');

  /// File path: assets/sprites/grass/Grass06.png
  AssetGenImage get grass06 =>
      const AssetGenImage('assets/sprites/grass/Grass06.png');

  /// File path: assets/sprites/grass/Grass07.png
  AssetGenImage get grass07 =>
      const AssetGenImage('assets/sprites/grass/Grass07.png');

  /// File path: assets/sprites/grass/Grass08.png
  AssetGenImage get grass08 =>
      const AssetGenImage('assets/sprites/grass/Grass08.png');

  /// File path: assets/sprites/grass/Grass09.png
  AssetGenImage get grass09 =>
      const AssetGenImage('assets/sprites/grass/Grass09.png');

  /// File path: assets/sprites/grass/Grass10.png
  AssetGenImage get grass10 =>
      const AssetGenImage('assets/sprites/grass/Grass10.png');

  /// File path: assets/sprites/grass/Grass11.png
  AssetGenImage get grass11 =>
      const AssetGenImage('assets/sprites/grass/Grass11.png');

  /// File path: assets/sprites/grass/Grass12.png
  AssetGenImage get grass12 =>
      const AssetGenImage('assets/sprites/grass/Grass12.png');

  /// File path: assets/sprites/grass/Grass13.png
  AssetGenImage get grass13 =>
      const AssetGenImage('assets/sprites/grass/Grass13.png');

  /// File path: assets/sprites/grass/Grass14.png
  AssetGenImage get grass14 =>
      const AssetGenImage('assets/sprites/grass/Grass14.png');

  /// File path: assets/sprites/grass/Grass15.png
  AssetGenImage get grass15 =>
      const AssetGenImage('assets/sprites/grass/Grass15.png');

  /// File path: assets/sprites/grass/Grass16.png
  AssetGenImage get grass16 =>
      const AssetGenImage('assets/sprites/grass/Grass16.png');

  /// File path: assets/sprites/grass/Grass17.png
  AssetGenImage get grass17 =>
      const AssetGenImage('assets/sprites/grass/Grass17.png');

  /// File path: assets/sprites/grass/Readme.txt
  String get readme => 'assets/sprites/grass/Readme.txt';

  /// List of all assets
  List<dynamic> get values => [
    grass01,
    grass02,
    grass03,
    grass04,
    grass05,
    grass06,
    grass07,
    grass08,
    grass09,
    grass10,
    grass11,
    grass12,
    grass13,
    grass14,
    grass15,
    grass16,
    grass17,
    readme,
  ];
}

class Assets {
  const Assets._();

  static const $AssetsBrandGen brand = $AssetsBrandGen();
  static const $AssetsIconsGen icons = $AssetsIconsGen();
  static const $AssetsImagesGen images = $AssetsImagesGen();
  static const $AssetsSpritesGen sprites = $AssetsSpritesGen();
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
