import 'package:flutter/material.dart';

/// Neutral, grey and warning ramps used for text, borders and status colours.
///
/// Generated defaults. `scripts/create_app.dart` can regenerate this file from
/// your own `color.xml` (only the `warning*`, `neutral*` and `grey*` entries
/// are read; anything it doesn't define keeps the value below). The theme
/// reads `neutral50`, `neutral200`, `neutral300`, `neutral500`, `neutral600`
/// and `neutral900`, so those must always exist.
abstract class AppPalette {
  AppPalette._();

  // neutral
  static const Color neutral25 = Color(0xFFF9F9F9);
  static const Color neutral40 = Color(0xFF939BA6);
  static const Color neutral50 = Color(0xFFF3F5F7);
  static const Color neutral60 = Color(0xFF515C6D);
  static const Color neutral70 = Color(0xFF64748B);
  static const Color neutral100 = Color(0xFFEFF0F2);
  static const Color neutral200 = Color(0xFFE7E8EA);
  static const Color neutral300 = Color(0xFFCFD1D6);
  static const Color neutral400 = Color(0xFF9FA4AC);
  static const Color neutral500 = Color(0xFF888D98);
  static const Color neutral600 = Color(0xFF707683);
  static const Color neutral700 = Color(0xFF404959);
  static const Color neutral800 = Color(0xFF283245);
  static const Color neutral900 = Color(0xFF101B30);

  // grey
  static const Color grey200 = Color(0xFFE9EAEB);
  static const Color grey700 = Color(0xFF414651);

  // warning
  static const Color warning100 = Color(0xFFFEECD7);
  static const Color warning200 = Color(0xFFFDD9AF);
  static const Color warning500 = Color(0xFFF99F36);
  static const Color warning700 = Color(0xFFB54708);
  static const Color warning900 = Color(0xFF4B3010);
}
