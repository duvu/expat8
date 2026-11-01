import 'package:flutter/painting.dart';

/// The corner-radius scale (BRAND.md, "Surface language"). Use these instead
/// of literal radii so every screen rounds the same way.
abstract final class AppRadius {
  /// Chips, thin bars, small badges.
  static const small = BorderRadius.all(Radius.circular(8));

  /// Buttons, inputs, list tiles and compact tiles.
  static const control = BorderRadius.all(Radius.circular(12));

  /// Cards and panels.
  static const card = BorderRadius.all(Radius.circular(20));

  /// Main surfaces and sheets.
  static const surface = BorderRadius.all(Radius.circular(24));
}
