import 'package:flutter/material.dart';

abstract class AppColors {
  AppColors._();

  /// The single value that drives the whole app's theme via
  /// `ColorScheme.fromSeed`. Rebranding a generated project for a new client
  /// is: change this line (or regenerate with a different `seed_color`).
  static const Color seed = Color(0xFF{{seed_color_hex}});

  /// Status colors intentionally don't derive from [seed] -- like Material's
  /// own error color, they need to stay recognizable regardless of brand
  /// color (a green "success" shouldn't shift hue because a client's brand
  /// happens to be green).
  static const Color success = Color(0xFF2E7D32);
  static const Color warning = Color(0xFFED6C02);
  static const Color info = Color(0xFF0288D1);
}
